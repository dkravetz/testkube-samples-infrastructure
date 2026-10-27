# The GitHub App again, for the apps: their charts' ExternalSecrets copy it into their namespace
# and External Secrets Operator mints installation tokens from it (GithubAccessToken), e.g. for
# the release dispatch after dev's tests pass.
module "github_app_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 2.2"

  name        = "platform/github-app"
  description = "GitHub App the apps mint installation tokens with"
  # Deleted at once, so a destroy and apply can reuse the name.
  recovery_window_in_days = 0

  secret_string = jsonencode({
    appId          = var.github_app.id
    installationId = var.github_app.installation_id
    privateKey     = var.github_app.private_key
  })
}
