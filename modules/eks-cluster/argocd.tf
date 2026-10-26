# The admin password is OpenTofu's, so it is an output (Argo CD stores only the bcrypt hash).
resource "random_password" "argocd_admin" {
  length  = 24
  special = false
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  values = [yamlencode({
    configs = {
      # TLS ends at the Envoy Gateway (BRIEF D5); in-cluster traffic is plain HTTP.
      params = { "server.insecure" = true }
    }
    # Admin login is enough for the PoC.
    dex = { enabled = false }
  })]

  # The admin password hash, and repository credentials for every repo under the owner: one
  # GitHub App credential template.
  set_sensitive = concat([
    { name = "configs.secret.argocdServerAdminPassword", value = random_password.argocd_admin.bcrypt_hash },
    ], var.github_app == null ? [] : [
    { name = "configs.credentialTemplates.github-app.url", value = var.github_app.url_prefix },
    { name = "configs.credentialTemplates.github-app.githubAppID", value = var.github_app.id, type = "string" },
    { name = "configs.credentialTemplates.github-app.githubAppInstallationID", value = var.github_app.installation_id, type = "string" },
    { name = "configs.credentialTemplates.github-app.githubAppPrivateKey", value = var.github_app.private_key },
  ])

  depends_on = [module.eks]
}

resource "helm_release" "addons" {
  name       = "addons"
  namespace  = helm_release.argocd.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [yamlencode({
    applicationsets = {
      addons = {
        namespace         = helm_release.argocd.namespace
        goTemplate        = true
        goTemplateOptions = ["missingkey=error"]
        generators = [{
          git = {
            repoURL     = var.gitops_repo_url
            revision    = var.gitops_revision
            directories = [{ path = "${var.gitops_addons_path}/*" }]
          }
        }]
        template = {
          metadata = { name = "{{ .path.basename }}" }
          spec = {
            project = "default"
            source = {
              repoURL        = var.gitops_repo_url
              targetRevision = var.gitops_revision
              path           = "{{ .path.path }}"
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "{{ .path.basename }}"
            }
            syncPolicy = {
              automated = { prune = true, selfHeal = true }
              # An add-on may need another one's CRDs (e.g. Gateway API from Envoy Gateway):
              # skip the dry run for unknown kinds and retry until they exist.
              syncOptions = ["CreateNamespace=true", "ServerSideApply=true", "SkipDryRunOnMissingResource=true"]
              retry = {
                limit   = 10
                backoff = { duration = "10s", factor = 2, maxDuration = "3m" }
              }
            }
          }
        }
      }
    }
  })]
}
