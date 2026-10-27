# All set on the app-bootstrap workspace by stacks/terrakube.

variable "organization_id" {
  description = "Terrakube organization of the app workspaces."
  type        = string
}

variable "vcs_id" {
  description = "VCS connection (the GitHub App) the app workspaces clone with."
  type        = string
}

variable "plan_apply_template_id" {
  description = "Template of the app workspaces: plan, then apply."
  type        = string
}

variable "tofu_version" {
  description = "OpenTofu version of the app workspaces."
  type        = string
}

variable "schedule" {
  description = "Quartz cron expression the app workspaces run on."
  type        = string
}

variable "github_app_id" {
  description = "GitHub App the app.yaml files are read with."
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation of the GitHub App on the dkravetz account."
  type        = string
}

variable "github_app_pem" {
  description = "Private key (PEM) of the GitHub App."
  type        = string
  sensitive   = true
}
