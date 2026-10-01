# Where Terraform keeps the state of the Hetzner cluster - its memory of what it created.
# The state is not on a laptop but in a Cloudflare R2 bucket, so every engineer and the CI
# pipeline read and write the same one (Chapter 02). R2 speaks the S3 API, so the "s3"
# backend is used with an R2 endpoint.
#   s3 backend:     https://developer.hashicorp.com/terraform/language/backend/s3
#   state, locking: https://developer.hashicorp.com/terraform/language/state/locking
#   R2 S3 API:      https://developers.cloudflare.com/r2/api/s3/api/
# The R2 keys come from the environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY), never from this file.
terraform {
  backend "s3" {
    bucket = "sre"
    key    = "tfstate/hcloud/cluster.tfstate"
    region = "auto"

    # Cloudflare R2 S3-compatible endpoint (account-specific).
    endpoints = {
      s3 = "https://99c9887cccb1cb265d748f267999af47.r2.cloudflarestorage.com"
    }

    # Required for non-AWS S3 backends: R2 has no AWS account, region or STS to check.
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true

    # Use S3-native locking (no DynamoDB): a lock object next to the state, written with a
    # conditional write - a second plan or apply waits or fails instead of overwriting.
    use_lockfile = true
  }
}
