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
#
# Terraform language: https://developer.hashicorp.com/terraform/language
# State and why it is shared and locked: https://developer.hashicorp.com/terraform/language/state/locking

# Terraform and provider versions; "~> 3.0" means 3.x, never 4.0.
# https://developer.hashicorp.com/terraform/language/providers/requirements
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

# Inputs. https://developer.hashicorp.com/terraform/language/values/variables
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

# The Kubernetes provider reads the kind kubeconfig file - a lab shortcut; the kind and
# Hetzner modules configure it from the cluster resource instead.
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# A fixed name: a second copy with its own state tries to create it again and fails.
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1
resource "kubernetes_config_map_v1" "migration_db" {
  metadata {
    name      = "lab-migration-db"
    namespace = "lab"
  }

  data = {
    server_type = var.db_size
  }
}

# generate_name: the API server adds a random suffix, so there is no fixed name to collide on -
# a second copy with its own state quietly creates a second, distinct worker.
# https://kubernetes.io/docs/reference/using-api/api-concepts/#generated-values
resource "kubernetes_config_map_v1" "worker" {
  metadata {
    generate_name = "lab-worker-"
    namespace     = "lab"
  }

  data = {
    role = "worker"
  }
}
