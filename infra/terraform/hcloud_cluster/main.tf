provider "hcloud" {
  token = var.hcloud_token
}

module "kube_hetzner" {
  source  = "kube-hetzner/kube-hetzner/hcloud"
  version = "2.19.0"

  # Core
  cluster_name = var.cluster_name
  ssh_public_key  = var.ssh_public_key
  ssh_private_key = var.ssh_private_key

  # We want a stable, provider-backed ingress controller (matches our Ingress manifests).
  ingress_controller = "nginx"

  # Non-HA control plane: keep OS upgrades off by default to avoid surprise reboots.
  automatically_upgrade_os = false

  # Minimal cluster size for this course: 1x control plane, 1x worker.
  control_plane_nodepools = [
    {
      name        = "cp"
      server_type = var.control_plane_server_type
      location    = var.location
      labels      = []
      taints      = []
      count       = 1
    },
  ]

  agent_nodepools = [
    {
      name        = "agent"
      server_type = var.agent_server_type
      location    = var.location
      labels      = []
      taints      = []
      count       = 1
    },
  ]

  # Expose the cluster via Hetzner Load Balancer.
  load_balancer_type     = var.load_balancer_type
  load_balancer_location = var.location

  # Pin if you want, otherwise module default.
  k3s_version = var.k3s_version
}

locals {
  kubeconfig_path = pathexpand("${path.module}/kubeconfig.yaml")

  # Render pullSecret only when a token is provided.
  flux_pull_secret_yaml = var.flux_git_token != "" ? "    pullSecret: flux-system\n" : ""

  flux_git_secret_enabled = var.flux_git_token != ""
  sops_age_secret_enabled = var.sops_age_key != ""
}

resource "local_sensitive_file" "kubeconfig" {
  content         = module.kube_hetzner.kubeconfig
  filename        = local.kubeconfig_path
  file_permission = "0600"
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

resource "kubernetes_namespace" "bootstrap" {
  for_each = toset([
    "flux-system",
    "develop",
    "staging",
    "production",
    "observability",
  ])

  metadata {
    name = each.value
    labels = {
      "managed-by" = "terraform"
    }
  }

  depends_on = [local_sensitive_file.kubeconfig]
}

# Optional: credentials for syncing a private Git repository over HTTPS.
resource "kubernetes_secret" "flux_git_credentials" {
  count = local.flux_git_secret_enabled ? 1 : 0

  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }

  type = "Opaque"

  data = {
    username = "git"
    password = var.flux_git_token
  }

  depends_on = [kubernetes_namespace.bootstrap]
}

resource "null_resource" "flux_operator_install" {
  depends_on = [kubernetes_namespace.bootstrap]

  triggers = {
    kubeconfig_path = local.kubeconfig_path
  }

  provisioner "local-exec" {
    when        = create
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl --kubeconfig=\"${local.kubeconfig_path}\" apply -f https://github.com/controlplaneio-fluxcd/flux-operator/releases/latest/download/install.yaml"
  }
}

resource "null_resource" "flux_instance" {
  depends_on = [
    null_resource.flux_operator_install,
    kubernetes_secret.flux_git_credentials,
  ]

  triggers = {
    kubeconfig_path = local.kubeconfig_path
    repo_url        = var.flux_git_repository_url
    repo_branch     = var.flux_git_repository_branch
    repo_path       = var.flux_kustomization_path
    flux_version    = var.flux_version
    provider        = "github"
  }

  provisioner "local-exec" {
    when        = create
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOC
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
    url: "${var.flux_git_repository_url}"
    ref: "refs/heads/${var.flux_git_repository_branch}"
    provider: github
    path: "${var.flux_kustomization_path}"
${local.flux_pull_secret_yaml}
EOF
    EOC
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl --kubeconfig=\"${self.triggers.kubeconfig_path}\" delete fluxinstance flux -n flux-system --ignore-not-found=true"
  }
}

# Optional: GHCR imagePullSecret in every namespace used by workloads.
resource "kubernetes_secret" "ghcr_credentials" {
  for_each = var.enable_ghcr ? toset(["flux-system", "develop", "staging", "production"]) : toset([])

  metadata {
    name      = "ghcr-credentials-docker"
    namespace = each.key
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = var.ghcr_username
          password = var.ghcr_token
          auth     = base64encode("${var.ghcr_username}:${var.ghcr_token}")
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.bootstrap]
}

# Optional: age private key for Flux SOPS decryption.
resource "kubernetes_secret" "sops_age" {
  count = local.sops_age_secret_enabled ? 1 : 0

  metadata {
    name      = "sops-age"
    namespace = "flux-system"
  }

  data = {
    "age.agekey" = var.sops_age_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.bootstrap]
}
