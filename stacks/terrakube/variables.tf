variable "github_app_id" {
  description = "GitHub App ID (dkravetz-ministack-poc). Terrakube finds the installation from each repository's owner."
  type        = string
  default     = "5461078"
}

variable "github_app_installation_id" {
  description = "Installation ID of the GitHub App on the dkravetz account, for reading each app's app.yaml."
  type        = string
  default     = "174972604"
}

variable "app_bootstrap_repository" {
  description = "Repository of the app-bootstrap workspace's code (terrakube/app-bootstrap)."
  type        = string
  default     = "https://github.com/dkravetz/testkube-samples-infrastructure"
}

variable "app_bootstrap_branch" {
  description = "Branch the app-bootstrap workspace runs."
  type        = string
  default     = "main"
}

variable "tofu_version" {
  description = "OpenTofu version the executor downloads for every workspace."
  type        = string
  default     = "1.13.2"
}
