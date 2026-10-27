# Terrakube's configuration: one organization with the GitHub App as its VCS connection, the
# admin team, the templates workspaces run, and the app-bootstrap workspace. Every 5 minutes
# app-bootstrap reads each app's app.yaml and creates its dev and prd workspaces.

locals {
  # Nothing can call into the laptop, so no webhooks: every workspace runs every 5 minutes
  # (Quartz cron).
  schedule = "0 0/5 * ? * *"
  # Dex's group of the admin user.
  admin_team = "TERRAKUBE_ADMIN"
}

# Argo CD installs Terrakube after stacks/eks returns. The http data source can't wait for it:
# until its route exists the Gateway answers 404, which it doesn't retry.
resource "terraform_data" "wait_for_api" {
  triggers_replace = [local.terrakube_endpoint]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "curl -fsS -o /dev/null --retry 60 --retry-delay 10 --retry-all-errors -H \"Authorization: Bearer $TOKEN\" ${local.terrakube_endpoint}/api/v1/organization"
    environment = {
      TOKEN = data.terraform_remote_state.eks.outputs.terrakube_admin_token
    }
  }
}

resource "terrakube_organization" "platform" {
  name           = "testkube-poc"
  description    = "Per-app infrastructure"
  execution_mode = "remote"

  depends_on = [terraform_data.wait_for_api]
}

# Even an admin token may only create an organization's VCS connections, templates and
# workspaces through a team of that organization (403 otherwise), so those wait for this one.
resource "terrakube_team" "admins" {
  organization_id = terrakube_organization.platform.id
  name            = local.admin_team
  role            = "admin"
}

resource "terrakube_vcs" "github" {
  depends_on = [terrakube_team.admins]

  organization_id = terrakube_organization.platform.id
  name            = "github"
  description     = "GitHub App"
  vcs_type        = "GITHUB"
  connection_type = "STANDALONE"
  client_id       = var.github_app_id
  private_key     = file("${path.module}/../../.local/github-app.pkcs8.pem")
  endpoint        = "https://github.com"
  api_url         = "https://api.github.com"
}

resource "terrakube_organization_template" "plan_apply" {
  depends_on = [terrakube_team.admins]

  organization_id = terrakube_organization.platform.id
  name            = "plan-apply"
  description     = "Plan, then apply"
  content         = <<-EOT
    flow:
      - type: "terraformPlan"
        name: "Plan"
        step: 100
      - type: "terraformApply"
        name: "Apply"
        step: 200
  EOT
}

# Every workspace reaches ministack with the workspaces' IAM user (iam.tf). AWS_ENDPOINT_URL
# keeps endpoints out of the workspaces' code. Real AWS: Terrakube's dynamic credentials (OIDC)
# instead of keys, and no endpoint.
locals {
  aws_variables = {
    AWS_ENDPOINT_URL      = { value = "http://ministack:4566", sensitive = false }
    AWS_REGION            = { value = data.aws_region.current.region, sensitive = false }
    AWS_ACCESS_KEY_ID     = { value = module.workspaces_user.access_key_id, sensitive = false }
    AWS_SECRET_ACCESS_KEY = { value = module.workspaces_user.access_key_secret, sensitive = true }
  }
}

resource "terrakube_organization_variable" "aws" {
  for_each = nonsensitive(toset(keys(local.aws_variables)))

  organization_id = terrakube_organization.platform.id
  key             = each.key
  value           = local.aws_variables[each.key].value
  sensitive       = local.aws_variables[each.key].sensitive
  description     = "ministack for every workspace"
  category        = "ENV"
  hcl             = false
}

resource "terrakube_workspace_vcs" "app_bootstrap" {
  organization_id = terrakube_organization.platform.id
  name            = "app-bootstrap"
  description     = "Creates every app's dev and prd workspaces"
  repository      = var.app_bootstrap_repository
  branch          = var.app_bootstrap_branch
  folder          = "/terrakube/app-bootstrap"
  vcs_id          = terrakube_vcs.github.id
  template_id     = terrakube_organization_template.plan_apply.id
  iac_type        = "tofu"
  iac_version     = var.tofu_version
}

resource "terrakube_workspace_schedule" "app_bootstrap" {
  workspace_id = terrakube_workspace_vcs.app_bootstrap.id
  template_id  = terrakube_organization_template.plan_apply.id
  schedule     = local.schedule
}

# What terrakube/app-bootstrap needs: the API as pods see it (the CoreDNS rewrite to the
# Gateway, plain HTTP) and the admin token; the GitHub App, to read each app's app.yaml; and the
# IDs it wires into the app workspaces.
locals {
  app_bootstrap_variables = {
    TERRAKUBE_ENDPOINT = { value = local.terrakube_endpoint, category = "ENV", sensitive = false }
    TERRAKUBE_TOKEN    = { value = data.terraform_remote_state.eks.outputs.terrakube_admin_token, category = "ENV", sensitive = true }

    organization_id            = { value = terrakube_organization.platform.id, category = "TERRAFORM", sensitive = false }
    vcs_id                     = { value = terrakube_vcs.github.id, category = "TERRAFORM", sensitive = false }
    plan_apply_template_id     = { value = terrakube_organization_template.plan_apply.id, category = "TERRAFORM", sensitive = false }
    tofu_version               = { value = var.tofu_version, category = "TERRAFORM", sensitive = false }
    schedule                   = { value = local.schedule, category = "TERRAFORM", sensitive = false }
    github_app_id              = { value = var.github_app_id, category = "TERRAFORM", sensitive = false }
    github_app_installation_id = { value = var.github_app_installation_id, category = "TERRAFORM", sensitive = false }
    github_app_pem             = { value = file("${path.module}/../../.local/github-app.pem"), category = "TERRAFORM", sensitive = true }
  }
}

resource "terrakube_workspace_variable" "app_bootstrap" {
  for_each = nonsensitive(toset(keys(local.app_bootstrap_variables)))

  organization_id = terrakube_organization.platform.id
  workspace_id    = terrakube_workspace_vcs.app_bootstrap.id
  key             = each.key
  value           = local.app_bootstrap_variables[each.key].value
  category        = local.app_bootstrap_variables[each.key].category
  sensitive       = local.app_bootstrap_variables[each.key].sensitive
  description     = "Set by stacks/terrakube"
  hcl             = false
}
