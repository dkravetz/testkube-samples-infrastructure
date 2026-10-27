# Tradeoffs

This is a proof of concept that runs on one laptop. Each item says what was done, why, and what
you would do on real AWS.

## The app registry is hard-coded

**What.** The platform knows about one app, `testkube-samples`, in two places:

- `terrakube/app-bootstrap/main.tf`, `local.apps`: Terrakube creates the app's workspaces from it.
- `gitops/addons/apps/`: the ApplicationSet names the repo URL, and the AppProject names the
  repo and the namespaces `testkube-samples-dev`, `testkube-samples-prd` and `testkube`.

Adding an app means editing both.

**Why.** One app. A generator or a shared registry file would be more code than the app list.

**For real.** One registry that both tools read, for example a file per app in this repo, or
Argo CD's SCM provider generator over a GitHub topic. An AppProject per app.

## No integration between Terrakube and GitHub, everything polls

**What.** Terrakube only clones from GitHub. It gets no webhooks, runs no plans on pull
requests and posts no plan output or status back to GitHub. Argo CD gets no webhooks either.

- Argo CD polls git every 2 to 3 minutes (the chart's default, 120 s plus up to 60 s jitter).
- Terrakube runs every workspace on a schedule, every 5 minutes (`0 0/5 * ? * *`):
  `app-bootstrap` and each app workspace plan and apply, even when nothing changed.

**Why.** Time, and the platform runs in a VM on a laptop that nothing on the internet can
reach. A few minutes of delay is fine for a demo.

**For real.** GitHub webhooks, scoped to the files each tool reads:

- the app's Terrakube workspace runs when `app.yaml` or `infrastructure/` changes;
- Argo CD syncs when `app.yaml` or `chart/` changes.

Pull requests get speculative plans, with the plan posted to the PR as a check.

## No dedicated orchestration repo

**What.** Each app's interface (`app.yaml`) lives in the app repo, and what each env runs is
`envs.<env>.revision` in that same file (prd: the latest release tag). Promotion shows up as a
release, not as a commit you can point at.

**Why.** One app, and it keeps everything about the app in one place.

**For real, with more apps.** A dedicated repo for app orchestration that holds only the YAML
interface: per app, its `app.yaml` and per-env overrides, plus one file per env that holds
only the version to run. Argo CD and Terrakube read that repo, so adding an app is adding a
directory, which also replaces the hard-coded registry above. Promotion (Kargo or similar) only
ever writes the version files, so promotion commits are one line in one file, by a bot, and
easy to tell apart from human config changes. One decision to make: config there applies
on merge, not at promotion, unless the promotion tool tracks that repo too.

## Every workspace applies without approval

**What.** All workspaces use the one `plan-apply` template: plan, then apply. That includes
`testkube-samples-prd`.

**Why.** No one is around to click "approve" every 5 minutes.

**For real.** A plan-approve-apply template for prd, policy checks on plans, and required
reviewers on the app's `infrastructure/`.

## Local CA instead of real TLS

**What.** `modules/eks-cluster/tls.tf` makes a self-signed CA and one certificate for
`*.platform.localhost`, `*.dev.localhost` and `*.prd.localhost`. It goes to Secrets Manager,
and External Secrets copies it to the Gateway. HTTP and HTTPS both serve every route, with no
redirect, because pods call the same hostnames over plain HTTP and don't trust the CA.
Browsers warn unless you run `task trust-ca`.

**Why.** `.localhost` names can't get a public certificate.

**For real.** A real domain, cert-manager with ACME (or ACM on a load balancer), and HTTP
redirected to HTTPS.

## ministack, and its workarounds

**What.** ministack emulates AWS, including EKS (it starts a real k3s), RDS (real Postgres
containers) and ElastiCache (real Valkey). It runs with `AUTH=true`, so IAM policies are
enforced. It was picked because it is closer to real AWS, but it needed workarounds that
weren't expected. Each one is commented in the code:

- **STS tokens for kubectl.** With `AUTH=true`, ministack only accepts EKS tokens signed for
  `sts.us-east-1.amazonaws.com`. A profile with a local endpoint would sign them for
  `localhost`. So `task kubeconfig` and `stacks/eks/providers.tf` set
  `AWS_ENDPOINT_URL_STS=https://sts.us-east-1.amazonaws.com`. `aws eks get-token` only signs
  locally, so nothing goes to AWS. Because of this, the Kubernetes and Helm providers can't
  assume the `tofu` role, so the root key gets its own cluster-admin access entry.
- **IRSA.** k3s signs service account tokens with its own issuer, not the one ministack
  advertises for the cluster. So `enable_irsa` stays off, and `modules/eks-cluster/irsa.tf`
  registers k3s's issuer (`https://kubernetes.default.svc.cluster.local`) as the OIDC
  provider. ministack doesn't check token signatures. The role trust uses
  `ForAnyValue:StringEquals` on `aud`, because ministack only matches the list form.
- **DNS in pods.** `stacks/eks/coredns.tf` adds a CoreDNS entry for `ministack` (its IP on the
  Docker network, from `.local/ministack.yaml`), and rewrites `*.localhost` and `*.internal` to
  the Gateway's Service. CoreDNS doesn't reload imported files, so a checksum annotation on
  its Deployment restarts it when the entries change.
- **No load balancers.** k3s here has no LoadBalancer support. The Gateway's Service is a
  NodePort (30080/30443), and the `socat` container forwards the Mac's :80/:443 to it.
- **AWS endpoints everywhere.** External Secrets gets `AWS_SECRETSMANAGER_ENDPOINT`,
  `AWS_SSM_ENDPOINT` and `AWS_STS_ENDPOINT`. Terrakube workspaces get `AWS_ENDPOINT_URL`. Every
  stack lists its endpoints inline.
- **Terrakube's bucket region.** Terrakube 2.33 signs calls to a custom S3 endpoint for the
  region `auto`, and doesn't follow S3's redirect. So its bucket is created in `auto`, and the
  AWS provider in `stacks/eks` skips region validation.
- **Static keys for S3.** Terrakube and Testkube only accept a custom S3 endpoint with static
  keys. Each gets an IAM user scoped to its bucket, instead of an IRSA role.
- **No TLS to Valkey.** ministack would serve its own self-signed certificate, which
  Terrakube doesn't trust. Transit encryption is off.
- **Security group rules by CIDR.** ministack returns a rule's referenced group as
  `<account>/sg-...`, which shows as a diff on every plan. Rules allow the VPC's CIDR instead.
- **Hosts in Secrets.** Database and cache hosts are container IPs that change on every
  rebuild, so they go in Secrets Manager with the rest of the config, not in Helm values.
- **One account, root key.** Everything runs as account `000000000000`. The laptop uses the
  root key and assumes the `tofu` role, which has `AdministratorAccess`.

**For real.** Real AWS, with none of the above: `enable_irsa = true` (or EKS Pod Identity),
IRSA roles instead of IAM users, TLS on the cache, an AWS Load Balancer Controller, and
security group rules that name groups.

## The GitHub App key is shared by hand

**What.** The GitHub App's private key is shared outside git, and each operator puts it at
`.local/github-app.pem` (gitignored). OpenTofu reads it from there and copies it into the
cluster and Secrets Manager.

**Why.** It keeps the key out of git. Encrypting it in the repo, with something like `sops`,
was out of scope.

**For real.** The key lives in a secret store (Secrets Manager, Vault) and nothing reads it
from a laptop, or it is committed encrypted with `sops` and a KMS key.

## Terrakube needs a PKCS#8 key

**What.** GitHub hands out PKCS#1 private keys, and Terrakube only reads PKCS#8. `task
github-app-key` converts `.local/github-app.pem` with `openssl` before `stacks/terrakube` runs.

**For real.** Store the converted key in a secret store and read it from there.

## Images in GHCR, not ECR

**What.** Images go to `ghcr.io/dkravetz/testkube-samples-api` and `-web`. The chart sets no
pull secret, so the cluster pulls them anonymously.

**Why.** ministack's ECR lives on the laptop, and GitHub's runners can't reach it. GHCR is
reachable from both sides.

**For real.** ECR, pushed from Actions through GitHub OIDC and an IAM role, with immutable tags
and scanning.

## dev and prd share one cluster

**What.** Both envs are namespaces in the same k3s cluster, and Testkube runs only in dev.

**For real.** Separate clusters, usually separate AWS accounts, and a Testkube agent per cluster
so prd can run smoke tests too.

## Broad secret access

**What.** External Secrets' IAM role can read every Secrets Manager secret in the account, and
the `aws` ClusterSecretStore is open to every namespace. dev could read prd's database
password. Terrakube workspaces share one IAM user with `rds:*` and every secret under `apps/`.

**For real.** A role per app and env, scoped to `apps/<app>/<env>/*`, and Terrakube dynamic
credentials (OIDC) instead of static keys.

## Admin-only logins

**What.** Argo CD has only its `admin` user (Dex is off). Terrakube has one static Dex user in
the `TERRAKUBE_ADMIN` group, and an admin API token that OpenTofu mints and that never expires.
Testkube's API has no auth; the release Job calls it directly.

**For real.** SSO through a real identity provider, with groups mapped to roles, and short-lived
tokens.

## No workspace of workspaces: platform stacks are applied from the laptop

**What.** `task bootstrap` applies `bootstrap/tofu-state` and every stack under `stacks/` from
the laptop, and every later change to them is a `tofu apply` from the laptop too.
`bootstrap/tofu-state` keeps its state on disk; the other stacks keep theirs in ministack's
S3, so `task down` deletes all of it. Terrakube only runs the app workspaces and
`app-bootstrap`.

**Why.** Time.

**For real.** A manual bootstrap only for the very first pieces (state bucket, role, Terrakube
itself). After that, a workspace of workspaces in Terrakube creates one workspace per stack,
so every platform change goes through OpenTofu CI/CD: plan on the PR, apply on merge.

## No CI/CD or tests in the infra repo

**What.** This repo has no GitHub Actions. The only checks are the pre-commit hooks (`tofu
fmt`, `tofu validate`, provider lock files), which run only where someone installed them and
catch little. Nothing lints or renders the add-on charts, runs `tofu test`, or checks that a
bootstrap from nothing still works.

**Why.** Time.

**For real.** CI on every PR: the same hooks, `helm template` and a schema check of each
add-on, `tofu test` for the modules, and a scheduled end-to-end bootstrap on a runner.

## Removing an app leaves its resources

**What.** Removing an app from `local.apps` deletes its Terrakube workspaces on the next run,
but not the databases they created.

**For real.** A destroy run before the workspace is deleted.

## Promotion is a test Job and a git tag, not Kargo

**What.** Promotion from dev to prd is home-made. After each dev sync, a PostSync Job runs the
TestWorkflows one by one. If they pass, it asks GitHub to cut a release, and prd follows the
latest release tag. `release.yaml` only ever bumps the patch number (`v0.1.0`, `v0.1.1`, ...).
This testing is too simple: a failed test fails the dev sync and stops there, with no retry,
no rollback and no record of what was verified. The app's infrastructure is promoted
separately, by Terrakube moving the prd workspace to the new tag on its next run. Nothing
orders the two: the tests and the release don't wait for dev's Terrakube apply, so a commit can
be released before its infrastructure change was applied in dev, or even if that apply failed.

**Why.** Time. It was enough to show the path from merge to prd working end to end.

**For real.** Something like Kargo: freight that ties the image and the git commit together,
stages for dev and prd, verification steps for the tests, and promotion that converges on
its own (eventual consistency), with history and manual gates where needed.

## The app itself is barely tested

**What.** In the app repo, pull requests only run the chart checks (`chart.yaml`). The app's
unit tests and linting are not in CI. The tests that run in dev are one Hurl file for the API
and one Cypress spec for the web app.

**Why.** Time, and the focus was the infrastructure: how to get the app deployed and running,
not the app's own quality.

**For real.** Unit tests and lint on every PR, and a real Hurl and Cypress suite covering the
API and the main user flows.
