# State lab: why Terraform's state belongs in a shared, locked backend.
#
# Two ConfigMaps in the "lab" namespace of the local kind cluster stand in for cloud resources:
#   - migration_db: a resource with a fixed, unique name (like a server called "migration-db") -
#                   creating it twice fails with "already exists"
#   - worker:       a resource whose name gets a generated suffix (like the kube-hetzner nodes,
#                   sre-workers-ezz) - creating it twice gives two of them, and nobody gets an error
#
# Copy this directory to a second place to play a second engineer ("laptop B"). With the default
# local state each copy has its own memory; with backend-minio.tf.example both share one state in
# MinIO, locked while anyone plans or applies. The lab steps are in the course.
#
# Terraform reaches the cluster through the kind module's kubeconfig (var.kubeconfig_path), never
# your current kubectl context. The lab copies this directory next to itself (state-lab-b), so the
# relative default works for both copies.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

variable "kubeconfig_path" {
  description = "kubeconfig of the kind cluster (written by infra/terraform/kind_cluster)"
  type        = string
  default     = "../kind_cluster/kubeconfig.yaml"
}

variable "db_size" {
  description = "A value to change, so that an apply has something to do"
  type        = string
  default     = "cx23"
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_config_map_v1" "migration_db" {
  metadata {
    name      = "lab-migration-db"
    namespace = "lab"
  }

  data = {
    server_type = var.db_size
  }
}

resource "kubernetes_config_map_v1" "worker" {
  metadata {
    generate_name = "lab-worker-"
    namespace     = "lab"
  }

  data = {
    role = "worker"
  }
}
