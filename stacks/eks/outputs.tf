output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (on ministack: https://localhost:<port>, a new port for every new cluster)."
  value       = module.eks.cluster_endpoint
}
