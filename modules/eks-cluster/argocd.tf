# Argo CD manages itself: OpenTofu only installs a first copy, and Argo CD's own Application
# (gitops/addons/argocd) takes over its configuration from git within a minute. The two secrets
# Argo CD needs are OpenTofu's, so nothing secret is in git.

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.eks]
}

# The admin password is OpenTofu's, so it is an output; Argo CD stores only the bcrypt hash.
resource "random_password" "argocd_admin" {
  length  = 24
  special = false
}

resource "time_static" "argocd_admin_password" {
  triggers = {
    hash = random_password.argocd_admin.bcrypt_hash
  }
}

# argocd-secret is OpenTofu's (the chart runs with configs.secret.createSecret = false). Argo CD
# adds its own keys at startup (server.secretkey, tls.crt, tls.key), so OpenTofu writes the data
# once and re-creates the Secret only when the password changes.
resource "kubernetes_secret_v1" "argocd" {
  metadata {
    name      = "argocd-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-secret"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "admin.password"      = random_password.argocd_admin.bcrypt_hash
    "admin.passwordMtime" = time_static.argocd_admin_password.rfc3339
  }

  lifecycle {
    ignore_changes       = [data]
    replace_triggered_by = [random_password.argocd_admin]
  }
}

# Repository credentials for every repository under the owner: the GitHub App.
resource "kubernetes_secret_v1" "argocd_repo_creds" {
  metadata {
    name      = "github-app-repo-creds"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }

  data = {
    type                    = "git"
    url                     = var.github_app.url_prefix
    githubAppID             = var.github_app.id
    githubAppInstallationID = var.github_app.installation_id
    githubAppPrivateKey     = var.github_app.private_key
  }
}

# The first install only. Its configuration lives in gitops/addons/argocd, which pins the chart
# version from then on; OpenTofu never upgrades or reconfigures this release.
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # Only what must hold from the start: the secret is OpenTofu's, and Dex is off (Argo CD would
  # not remove a Dex it didn't create). Everything else comes from gitops/addons/argocd.
  values = [yamlencode({
    configs = { secret = { createSecret = false } }
    dex     = { enabled = false }
  })]

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubernetes_secret_v1.argocd, kubernetes_secret_v1.argocd_repo_creds]
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
