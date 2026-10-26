# GitHub App Argo CD reads every dkravetz repository with (BRIEF D14). Its private key is the
# operator's, at .local/github-app.pem (gitignored).
variable "github_app_id" {
  description = "GitHub App ID (dkravetz-ministack-poc)."
  type        = string
  default     = "5461078"
}

variable "github_app_installation_id" {
  description = "Installation ID of the GitHub App on the dkravetz account."
  type        = string
  default     = "174972604"
}
