terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "kind" {}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

locals {
  kubeconfig_path = pathexpand("${path.module}/kubeconfig.yaml")
}

resource "kind_cluster" "sre" {
  name            = "sre-control-plane"
  wait_for_ready  = true
  kubeconfig_path = local.kubeconfig_path

  kind_config {
    api_version = "kind.x-k8s.io/v1alpha4"
    kind        = "Cluster"

    networking {
      api_server_address = "127.0.0.1"
      api_server_port    = 6443
      kube_proxy_mode    = "iptables"
    }

    containerd_config_patches = [
      <<-EOT
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
          endpoint = ["http://kind-registry:5000"]
      EOT
    ]

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        <<-EOT
          kind: InitConfiguration
          nodeRegistration:
            kubeletExtraArgs:
              node-labels: "ingress-ready=true"
              authorization-mode: "Webhook"
        EOT
      ]

      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 30443
        host_port      = 8443
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }

    node {
      role = "worker"
    }
  }
}

resource "null_resource" "merge_kubeconfig" {
  depends_on = [kind_cluster.sre]

  provisioner "local-exec" {
    when    = create
    command = "${path.module}/scripts/merge-kubeconfig.sh \"${local.kubeconfig_path}\""
    interpreter = ["/bin/bash", "-c"]
  }
}

output "kubeconfig" {
  description = "Path to the generated kubeconfig for the kind cluster"
  value       = local.kubeconfig_path
}

resource "helm_release" "flux_operator" {
  depends_on = [null_resource.merge_kubeconfig]

  name             = "flux-operator"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  version          = var.flux_operator_version
  namespace        = "flux-system"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "null_resource" "flux_instance" {
  depends_on = [
    helm_release.flux_operator,
    kubernetes_secret.flux_github_app
  ]

  triggers = {
    kubeconfig_path = local.kubeconfig_path
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOC
      cat <<EOF | kubectl --kubeconfig="${local.kubeconfig_path}" apply -f -
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
spec:
  distribution:
    version: "${var.flux_version}"
    registry: ghcr.io/fluxcd
  components:
    - source-controller
    - kustomize-controller
    - helm-controller
    - notification-controller
    - image-reflector-controller
    - image-automation-controller
  cluster:
    type: kubernetes
  sync:
    kind: GitRepository
    provider: github
    url: "${var.flux_git_repository_url}"
    ref: "refs/heads/${var.flux_git_repository_branch}"
    path: "${var.flux_kustomization_path}"
    pullSecret: "flux-system"
EOF
    EOC
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --kubeconfig=\"${self.triggers.kubeconfig_path}\" delete fluxinstance flux -n flux-system --ignore-not-found=true"
    interpreter = ["/bin/bash", "-c"]
  }
}

# Create GitHub App secret for Flux authentication
resource "kubernetes_secret" "flux_github_app" {
  count      = var.github_app_id != "" ? 1 : 0
  depends_on = [helm_release.flux_operator]

  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }

  data = {
    "githubAppID"              = var.github_app_id
    "githubAppInstallationID"  = var.github_app_installation_id
    "githubAppPrivateKey"      = file(var.github_app_private_key_file)
  }

  type = "Opaque"
}

# Create imagePullSecret for GHCR in each namespace
resource "kubernetes_secret" "ghcr_credentials" {
  for_each   = toset(["flux-system", "develop", "staging", "production"])
  depends_on = [null_resource.flux_instance]

  metadata {
    name      = "ghcr-credentials-docker"
    namespace = each.key
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = "ldbl"
          password = var.ghcr_token
          auth     = base64encode("ldbl:${var.ghcr_token}")
        }
      }
    })
  }
}

output "flux_operator_installed" {
  description = "Indicates that Flux Operator has been installed"
  value       = helm_release.flux_operator.status == "deployed"
}

output "flux_instance_created" {
  description = "Indicates that FluxInstance has been created"
  value       = "flux"
  depends_on  = [null_resource.flux_instance]
}
