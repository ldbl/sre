variable "flux_git_repository_url" {
  description = "Git repository URL to sync with Flux. Leave empty to skip GitOps bootstrap."
  type        = string
  default     = ""
}

variable "flux_git_repository_branch" {
  description = "Git branch Flux should track."
  type        = string
  default     = "main"
}

variable "flux_kustomization_path" {
  description = "Path within the Git repository to reconcile (relative to repository root)."
  type        = string
  default     = "./infra/kubernetes/clusters/sre"
}

variable "flux_sync_interval" {
  description = "Interval at which Flux reconciles sources and kustomizations."
  type        = string
  default     = "1m"
}

variable "flux_kustomization_name" {
  description = "Name for the primary Flux Kustomization resource."
  type        = string
  default     = "cluster-sync"
}

variable "flux_operator_version" {
  description = "Version of the Flux Operator Helm chart to install."
  type        = string
  default     = "0.30.0"
}

variable "flux_version" {
  description = "Version of Flux to install (e.g., '2.x', '2.4.x', 'v2.4.0'). Using '2.x' will install the latest 2.x version."
  type        = string
  default     = "2.x"
}

variable "github_app_id" {
  description = "GitHub App ID for Flux authentication. Leave empty to skip GitHub App secret creation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID for Flux authentication."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_private_key_file" {
  description = "Path to GitHub App private key PEM file."
  type        = string
  default     = ""
}
