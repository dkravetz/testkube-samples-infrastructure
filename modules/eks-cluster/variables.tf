variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes <major>.<minor>."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the cluster security groups."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the cluster (two AZs or more)."
  type        = list(string)
}

variable "enable_irsa" {
  description = "Create the IRSA OIDC provider. Off: ministack's issuer is plain http, which the eks module's tls_certificate lookup rejects. Real AWS: true (or EKS Pod Identity)."
  type        = bool
  default     = false
}

variable "access_entries" {
  description = "Extra EKS access entries, in the terraform-aws-modules/eks format. The creator always gets cluster admin."
  type        = any
  default     = {}
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version."
  type        = string
  default     = "10.11.6"
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version (installs the ApplicationSet)."
  type        = string
  default     = "2.0.7"
}

variable "gitops_repo_url" {
  description = "Git repository Argo CD reads the add-ons from."
  type        = string
}

variable "gitops_revision" {
  description = "Branch, tag or commit of gitops_repo_url."
  type        = string
  default     = "main"
}

variable "gitops_addons_path" {
  description = "Directory in gitops_repo_url whose subdirectories become one Application each."
  type        = string
  default     = "gitops/addons"
}

variable "github_app" {
  description = "GitHub App Argo CD authenticates with to every repository under url_prefix. null = anonymous reads."
  type = object({
    url_prefix      = string
    id              = string
    installation_id = string
    private_key     = string
  })
  default   = null
  sensitive = true
}
