# The app repo: testkube-samples

[dkravetz/testkube-samples](https://github.com/dkravetz/testkube-samples) is a 3-tier app: a
Vite web app (`apps/web`), a Node API (`apps/api`) and Postgres. This page covers what was
added so it runs on the platform. Everything here is on its `main` branch.

| Path | What it is | Read by |
| --- | --- | --- |
| `app.yaml` | How the app runs on the platform. The one file the team edits. | Argo CD (ApplicationSet and chart values), Terrakube (`app-bootstrap`), the app's OpenTofu, `chart.yaml` workflow |
| `chart/` | The Helm chart that turns `app.yaml` into Kubernetes objects | Argo CD, `chart.yaml` workflow |
| `infrastructure/` | OpenTofu for the app's AWS resources | Terrakube workspaces `testkube-samples-dev` and `-prd` |
| `.github/workflows/` | `chart.yaml`, `build.yaml`, `release.yaml` | GitHub Actions |
| `apps/*/Dockerfile` | The images | `build.yaml` |
| `apps/api/tests/`, `apps/web/cypress/` | Hurl and Cypress tests | Testkube |

There is no `envs/` directory: per-env settings live in `app.yaml` under `envs`.

## app.yaml

The entry point. Each top-level key has its own reader.

### `infrastructure`

```yaml
infrastructure:
  path: infrastructure
  vars: {}
```

- `path`: where the app's OpenTofu lives. Terrakube's `app-bootstrap` workspace (platform repo,
  `terrakube/app-bootstrap`) sets it as the folder of the app's workspaces.
- `vars`: variables for that OpenTofu, for every env. Each env can override them under
  `envs.<env>.infrastructure.vars`. See [infrastructure/](#infrastructure).

The chart ignores both. Its schema only checks that `vars` holds plain values.

### `components`

One entry per container. Here: `api` and `web`. Fields (the schema is
`chart/values.schema.json`; it rejects unknown fields):

| Field | What it does |
| --- | --- |
| `image.repository` | Image without tag. Required. |
| `image.tag` | Optional. By default every component uses `global.image.tag`. |
| `port` | Container port. Required. |
| `healthPath` | HTTP path for readiness and liveness probes. Without it, a TCP check. |
| `route.path` | Serve this component through the Gateway at this path prefix. The prefix is stripped before it reaches the container (`/api/hello` becomes `/hello`). |
| `database` | Name of a database the app's OpenTofu created. Adds `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` and `DB_PASSWORD` from Secrets Manager `apps/<app>/<env>/db/<name>`. |
| `tests` | List of `{name, type, path}`. `type` is `hurl` or `cypress`. One TestWorkflow each. |
| `replicas`, `resources`, `env` | Replica count (default 1), resources (default 50m CPU, 128Mi request, 256Mi limit), plain env vars. |
| `pdb`, `hpa` | Optional PodDisruptionBudget and HorizontalPodAutoscaler. The HPA needs metrics-server, which this cluster doesn't run. |

### `envs`

```yaml
envs:
  dev: {}
  prd:
    revision: ">=0.1.0"
    tests: false
    infrastructure:
      vars:
        db_instance_class: db.t4g.small
        db_allocated_storage: 50
    components:
      api: { replicas: 2, pdb: { enabled: true } }
      web: { replicas: 2, pdb: { enabled: true } }
```

One key per env (`dev`, `prd`). Each can set:

- `revision`: the git ref this env runs, default `main`. prd uses `>=0.1.0`, so it follows the
  highest release tag.
- `tests`: `false` renders no TestWorkflows and no release Job. Default `true`.
- `infrastructure.vars`: merged over the top-level `infrastructure.vars` for this env. dev sets
  none and gets the defaults; prd asks for a bigger database.
- `components`: merged over the top-level `components` for this env.

Two readers use `envs`, at different revisions:

- Argo CD's `testkube-samples` ApplicationSet (platform repo, `gitops/addons/apps`) reads
  `app.yaml` from `main` to get the list of envs and each `revision`. It creates one Application
  per env.
- Each Application then renders `chart/` at its own revision, with the `app.yaml` from that
  revision. So a change to prd's `components` reaches prd only with the next release. A change
  to `revision`, or adding an env, takes effect from `main`.

## chart/

One chart, `base-app`, in the app repo. Argo CD renders it straight from git at the revision
it deploys, so the chart and the code always move together.

The templates loop over the components. For each one they render:

- a Deployment and a ClusterIP Service (there is no Service type field: outside traffic comes
  through the shared Gateway);
- an HTTPRoute on the `edge` Gateway when `route` is set, for two hostnames:
  `<app>.<env>.localhost` (browsers) and `<app>.<env>.internal` (tests in the cluster);
- an ExternalSecret `<component>-db` when `database` is set;
- a TestWorkflow per test, in the `testkube` namespace, using the platform's `hurl` or
  `cypress` TestWorkflowTemplate. It checks out the app repo at the deployed commit and calls
  the component's `.internal` route;
- a PodDisruptionBudget and an HPA when enabled.

When the env has tests, it also renders the release objects (`templates/release.yaml`):

- an ExternalSecret that copies the platform's GitHub App (`platform/github-app`);
- a `GithubAccessToken` generator and an ExternalSecret that mint a token for this repo every
  30 minutes, with `contents: write`;
- a PostSync Job. It runs each TestWorkflow in turn with the Testkube CLI, then POSTs a
  `tests-passed` `repository_dispatch` with the deployed commit. A failed test fails the Job.

ExternalSecrets, HTTPRoutes and TestWorkflows are in sync wave `-1`, so they apply before the
Deployments.

Tests for the chart itself are in `chart/tests/` (helm-unittest).

### Which value wins

Argo CD passes values like this (`gitops/addons/apps/applicationset.yaml`), lowest first:

1. `chart/values.yaml`: defaults, placeholders for `global`.
2. `app.yaml`, as a values file (`valueFiles: [../app.yaml]`).
3. Parameters set by the ApplicationSet. These always win:
   - `global.app`: `testkube-samples`
   - `global.env`: `dev` or `prd`
   - `global.domain`: `<env>.localhost`
   - `global.repository`: the app repo's URL
   - `global.revision`: the commit the revision resolved to
   - `global.image.tag`: `sha-<short commit>`

Then, inside the chart, `envs.<env>.components` is merged over `components`. The env's value
wins. A component's own `image.tag` wins over `global.image.tag`.

The `chart.yaml` workflow renders it the same way: `-f app.yaml` plus `--set` for the same
`global` values, for dev and prd.

## infrastructure/

An OpenTofu root that Terrakube runs once per env. The workspace sets two variables: `app`
(`testkube-samples`) and `env` (`dev` or `prd`). Terrakube adds the state backend, and the AWS
endpoint, region and keys as environment variables.

It calls one local module, `infrastructure/modules/postgres`, which creates:

- a security group that allows Postgres from the platform VPC (found by its `Name` tag,
  `testkube-poc`);
- an RDS Postgres 18 instance, `testkube-samples-<env>`, in the VPC's private subnets;
- a Secrets Manager secret `apps/testkube-samples/<env>/db/main` with `host`, `port`, `dbname`,
  `username` and `password`. The chart's ExternalSecret reads this path.

The dev workspace runs `main`. The prd workspace runs the latest GitHub release tag. Both plan
and apply every 5 minutes.

### Per-env variables from app.yaml

The root reads `../app.yaml` itself (`yamldecode(file(...))`). Terrakube clones the whole repo
at the workspace's ref, so the code and the `app.yaml` always come from the same commit. Terrakube
and `app-bootstrap` know nothing about these variables. The workspaces still only get `app` and
`env`.

Which value wins, lowest first:

1. The module's defaults (`infrastructure/modules/postgres/variables.tf`).
2. `infrastructure.vars` in `app.yaml`.
3. `envs.<env>.infrastructure.vars` in `app.yaml`.

| Key | Module input | Default (dev) | prd |
| --- | --- | --- | --- |
| `db_instance_class` | `instance_class` | `db.t4g.micro` | `db.t4g.small` |
| `db_allocated_storage` | `allocated_storage` | `20` (GiB) | `50` |

`infrastructure/main.tf` lists the known keys. Any other key fails the plan, so a typo can't
pass silently. To add a setting: add a variable to the module, pass it in `main.tf` with
`lookup(local.infrastructure_vars, "<key>", null)` (null means the module's default), and add
the key to `known_vars`.

Like the chart's values, prd's settings ship with a release: the prd workspace reads
`app.yaml` at the release tag. Outputs `db_instance_class` and `db_allocated_storage` show what
each env runs.

## Workflows

| Workflow | Trigger | Does |
| --- | --- | --- |
| `chart.yaml` | PR touching `app.yaml`, `chart/**` or itself | `helm lint --strict` and `helm template` for dev and prd, then helm-unittest. All in the `helmunittest/helm-unittest` image. |
| `build.yaml` | Push to `main` | Builds `api` and `web` for amd64 and arm64, pushes `ghcr.io/dkravetz/testkube-samples-<component>:sha-<7-char sha>`. |
| `release.yaml` | `repository_dispatch` `tests-passed` | If the commit is on `main` and has no `v*` tag: next patch version, version tag added to both images, GitHub release on that commit. One at a time. |

The app's unit tests (`npm run test`) and the Cypress tests are not run on PRs. Cypress runs
in the cluster, in dev, after each sync.

See the [README](../README.md#how-the-apps-workflows-work) for the whole path from merge to
prd.
