output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA bundle of the Kubernetes API."
  value       = module.eks.cluster_certificate_authority_data
}

output "external_secrets_role_arn" {
  description = "IAM role of External Secrets Operator (the add-on's service account annotation)."
  value       = module.external_secrets_role.arn
}

output "argocd_namespace" {
  description = "Namespace Argo CD runs in."
  value       = helm_release.argocd.namespace
}

output "argocd_admin_password" {
  description = "Password of Argo CD's admin user."
  value       = random_password.argocd_admin.result
  sensitive   = true
}
