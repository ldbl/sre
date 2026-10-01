# Terraform and provider versions. A provider is a plugin that talks to one API;
# "~> 3.3" means 3.3 or newer, but below 4.0, so a minor update never breaks the module.
# The exact versions picked are pinned in .terraform.lock.hcl.
# https://developer.hashicorp.com/terraform/language/providers/requirements
#   hcloud      Hetzner Cloud - used by the kube-hetzner module for servers, network, load balancer
#               https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs
#   helm, kubernetes  what Terraform puts inside the cluster before Flux takes over
#   local       writes kubeconfig.yaml next to the module
#   null        runs kubectl for the Flux Operator and the pre-destroy hook
#   random      generates the production database password
terraform {
  required_version = ">= 1.11.0" # write-only attributes (data_wo) need 1.11; ephemeral variables 1.10

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.69"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
