output "admin_email" {
  description = "Login of Terrakube's admin user."
  value       = local.admin_email
}

output "admin_password" {
  description = "Password of Terrakube's admin user."
  value       = random_password.admin.result
  sensitive   = true
}

output "admin_token" {
  description = "Terrakube admin API token (PAT, group TERRAKUBE_ADMIN)."
  value       = jwt_hashed_token.admin.token
  sensitive   = true
}
