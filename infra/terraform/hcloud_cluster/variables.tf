variable "hcloud_token" {
  description = "Hetzner Cloud API token (HCLOUD_TOKEN)."
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Cluster name (used for resources and kubeconfig context)."
  type        = string
  default     = "sre"
}

variable "location" {
  description = "Hetzner location for servers and load balancer (e.g. nbg1, fsn1, hel1)."
  type        = string
  default     = "nbg1"
}

variable "k3s_version" {
  description = "K3s version to install. Leave unset to use module default."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key for cluster nodes (ed25519)."
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key for cluster nodes (ed25519). Used by the module to bootstrap nodes."
  type        = string
  sensitive   = true
}

variable "control_plane_server_type" {
  description = "Hetzner server type for the control plane."
  type        = string
  default     = "cx23"
}

variable "agent_server_type" {
  description = "Hetzner server type for worker nodes."
  type        = string
  default     = "cx23"
}

variable "load_balancer_type" {
  description = "Hetzner load balancer type (e.g. lb11)."
  type        = string
  default     = "lb11"
}

variable "flux_operator_version" {
  description = "Flux Operator Helm chart version."
  type        = string
  default     = "0.30.0"
}

variable "flux_version" {
  description = "Flux version to install (e.g., '2.x', '2.4.x', 'v2.4.0')."
  type        = string
  default     = "2.x"
}

variable "flux_git_repository_url" {
  description = "Git repository URL Flux should sync (e.g. https://github.com/<owner>/<repo>.git)."
  type        = string
}

variable "flux_git_repository_branch" {
  description = "Git branch Flux should track."
  type        = string
  default     = "main"
}

variable "flux_kustomization_path" {
  description = "Path within the Git repository to reconcile (relative to repository root)."
  type        = string
  default     = "./flux/bootstrap/flux-system"
}

variable "flux_git_token" {
  description = "Optional token for private repo sync. For GitHub, a fine-grained token with Contents:Read (or classic token with repo scope). Leave empty for public repos."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ghcr_username" {
  description = "Optional GHCR username for pulling private images."
  type        = string
  default     = ""
}

variable "enable_ghcr" {
  description = "Whether to create GHCR imagePullSecrets (must be true when ghcr_token is set)."
  type        = bool
  default     = false
}

variable "ghcr_token" {
  description = "Optional GHCR token for pulling private images (read:packages). Leave empty if images are public."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sops_age_key" {
  description = "Optional age private key (contents of age.agekey) for SOPS decryption in Flux. Leave empty to skip creation of the sops-age secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "backup_s3_access_key_id" {
  description = "Optional S3/R2 access key for CNPG backups. Set together with backup_s3_secret_access_key and backup_s3_bucket."
  type        = string
  default     = ""
  sensitive   = true
}

variable "backup_s3_secret_access_key" {
  description = "Optional S3/R2 secret key for CNPG backups. Set together with backup_s3_access_key_id and backup_s3_bucket."
  type        = string
  default     = ""
  sensitive   = true
}

variable "backup_s3_bucket" {
  description = "Optional S3/R2 bucket name for CNPG backups. Set together with backup_s3_access_key_id and backup_s3_secret_access_key."
  type        = string
  default     = ""
}

variable "backup_s3_endpoint" {
  description = "Optional S3/R2 endpoint (for example https://<accountid>.r2.cloudflarestorage.com)."
  type        = string
  default     = ""
}

variable "backup_s3_region" {
  description = "Optional S3 region (for AWS-compatible APIs)."
  type        = string
  default     = ""
}
