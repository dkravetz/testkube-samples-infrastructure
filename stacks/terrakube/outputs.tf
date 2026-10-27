output "organization" {
  description = "Terrakube organization of the platform's workspaces."
  value       = terrakube_organization.platform.name
}

output "app_bootstrap_workspace_id" {
  description = "ID of the app-bootstrap workspace."
  value       = terrakube_workspace_vcs.app_bootstrap.id
}
