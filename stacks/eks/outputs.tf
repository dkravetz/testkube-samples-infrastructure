output "cluster_name" {
  description = "EKS cluster name."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (on ministack: https://localhost:<port>, a new port for every new cluster)."
  value       = module.cluster.cluster_endpoint
}

output "argocd_namespace" {
  description = "Namespace Argo CD runs in."
  value       = module.cluster.argocd_namespace
}

output "argocd_admin_password" {
  description = "Password of Argo CD's admin user."
  value       = module.cluster.argocd_admin_password
  sensitive   = true
}
