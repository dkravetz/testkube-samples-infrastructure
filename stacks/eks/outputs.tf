output "cluster_name" {
  description = "EKS cluster name."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (on ministack: https://localhost:<port>, a new port for every new cluster)."
  value       = module.cluster.cluster_endpoint
}

output "external_secrets_role_arn" {
  description = "IAM role of External Secrets Operator (the add-on's service account annotation)."
  value       = module.cluster.external_secrets_role_arn
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

output "ca_cert_file" {
  description = "Local CA certificate (PEM) the edge certificate is signed with."
  value       = abspath(local_file.ca_cert.filename)
}

output "terrakube_admin_token" {
  description = "Terrakube admin API token (PAT)."
  value       = module.cluster.terrakube_admin_token
  sensitive   = true
}

output "terrakube_admin_email" {
  description = "Login of Terrakube's admin user."
  value       = module.cluster.terrakube_admin_email
}

output "terrakube_admin_password" {
  description = "Password of Terrakube's admin user."
  value       = module.cluster.terrakube_admin_password
  sensitive   = true
}
