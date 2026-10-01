# Values printed after apply (terraform output). kubeconfig is sensitive: plan, apply and a plain
# terraform output print (sensitive value), but asking for it by name (terraform output kubeconfig,
# -raw kubeconfig) or for JSON (terraform output -json) shows the whole kubeconfig.
# https://developer.hashicorp.com/terraform/language/values/outputs
output "kubeconfig" {
  description = "Kubeconfig for the created cluster (YAML), context hetzner-<cluster_name>-control-plane."
  value       = local.kubeconfig_named
  sensitive   = true
}

output "kubeconfig_export" {
  description = "Run this command to set your KUBECONFIG."
  value       = "export KUBECONFIG=$(pwd)/kubeconfig.yaml"
}
