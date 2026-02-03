output "kubeconfig" {
  description = "Kubeconfig for the created cluster (YAML). Write it to a file with: terraform output --raw kubeconfig > kubeconfig.yaml"
  value       = module.kube_hetzner.kubeconfig
  sensitive   = true
}

