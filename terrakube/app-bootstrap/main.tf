# Two workspaces per app, both planning and applying every 5 minutes: dev runs the app's main
# branch, prd its latest GitHub release (from the first release on; a new release moves prd to
# its tag on this workspace's next run). Each runs the OpenTofu in the directory the app's
# app.yaml names, read at the same ref, with the variables app and env. Removing an app here
# deletes its workspaces on the next run, but not the resources they created.

locals {
  # Every app repository on the platform, by app name.
  apps = {
    # TEMPORARY: the #10 test branch; set back to "main" before merging.
    testkube-samples = { repository = "testkube-samples", branch = "10-terrakube-config" }
  }
}

# Through the GitHub App. A repository without releases answers 404 here instead of failing
# the run, as the github_release data source would.
data "github_rest_api" "latest_release" {
  for_each = local.apps

  endpoint = "repos/dkravetz/${each.value.repository}/releases/latest"
}

locals {
  workspaces = merge(
    { for app, spec in local.apps : "${app}-dev" => {
      app        = app
      env        = "dev"
      repository = spec.repository
      ref        = spec.branch
    } },
    { for app, spec in local.apps : "${app}-prd" => {
      app        = app
      env        = "prd"
      repository = spec.repository
      ref        = jsondecode(data.github_rest_api.latest_release[app].body).tag_name
    } if data.github_rest_api.latest_release[app].code == 200 },
  )
}

data "github_repository_file" "app" {
  for_each = local.workspaces

  repository = each.value.repository
  # Sent to GitHub as the ref, so a tag works too.
  branch = each.value.ref
  file   = "app.yaml"
}

resource "terrakube_workspace_vcs" "app" {
  for_each = local.workspaces

  organization_id = var.organization_id
  name            = each.key
  description     = "${each.value.app} infrastructure, ${each.value.env}"
  repository      = "https://github.com/dkravetz/${each.value.repository}"
  # A branch or a tag.
  branch      = each.value.ref
  folder      = "/${yamldecode(data.github_repository_file.app[each.key].content).infrastructure.path}"
  vcs_id      = var.vcs_id
  template_id = var.plan_apply_template_id
  iac_type    = "tofu"
  iac_version = var.tofu_version
}

locals {
  workspace_variables = merge([
    for name, workspace in local.workspaces : {
      for key in ["app", "env"] : "${name}/${key}" => {
        workspace = name
        key       = key
        value     = workspace[key]
      }
    }
  ]...)
}

resource "terrakube_workspace_variable" "app" {
  for_each = local.workspace_variables

  organization_id = var.organization_id
  workspace_id    = terrakube_workspace_vcs.app[each.value.workspace].id
  key             = each.value.key
  value           = each.value.value
  description     = "Set by the app-bootstrap workspace"
  category        = "TERRAFORM"
  sensitive       = false
  hcl             = false
}

resource "terrakube_workspace_schedule" "app" {
  for_each = local.workspaces

  workspace_id = terrakube_workspace_vcs.app[each.key].id
  template_id  = var.plan_apply_template_id
  schedule     = var.schedule
}
