# testkube-samples-infrastructure

Platform infrastructure (OpenTofu) for the testkube-samples PoC on ministack.

## Tools

To bring the platform up on a Mac:

- [Colima](https://github.com/abiosoft/colima) and the Docker CLI: the container runtime for
  ministack, the socat container and the k3s cluster ministack starts
- [Task](https://taskfile.dev) (`task`): `task bootstrap`, `task kubeconfig`, `task urls`,
  `task trust-ca` / `task untrust-ca` (optional), `task down`
- [OpenTofu](https://opentofu.org/docs/intro/install/) (`tofu`): the stacks under `stacks/`
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  (`aws`): the `ministack` profile and `aws eks get-token` for kubectl and the providers
- [kubectl](https://kubernetes.io/docs/tasks/tools/): the cluster
- [Helm](https://helm.sh/docs/intro/install/) (`helm`): only to update `Chart.lock` of the
  wrapper charts under `gitops/addons/` (`helm dependency update`); Argo CD pulls the charts
  itself

```bash
brew install colima docker go-task opentofu awscli kubectl helm
colima start --vm-type vz --cpu 4 --memory 16 --disk 100
```

The GitHub App's private key goes in `.local/github-app.pem` (gitignored).

`stacks/eks` writes the local CA's certificate to `.local/ca.crt`: `curl --cacert .local/ca.crt
https://argocd.platform.localhost`. Browsers show a warning you can click through, or run
`task trust-ca` to trust it in the macOS login keychain; `task down` removes it again. Plain HTTP
works without it.

## Pre-commit checks

Every commit runs `tofu fmt`, `tofu validate` and a provider lock check through
[pre-commit](https://pre-commit.com), configured in `.pre-commit-config.yaml`. The lock
check makes sure each `.terraform.lock.hcl` has provider checksums for macOS (Apple
Silicon and Intel) and Linux (x86_64 and ARM64).

### Prerequisites

- [pre-commit](https://pre-commit.com/#install)
- [OpenTofu](https://opentofu.org/docs/intro/install/) (`tofu`)
- [jq](https://jqlang.org/download/), used by the validate hook to recover from a stale
  `.terraform/` directory

On macOS:

```bash
brew install pre-commit opentofu jq
```

### Usage

Install the git hook once per clone:

```bash
pre-commit install
```

Run the checks on every file:

```bash
pre-commit run --all-files
```

The lock check only downloads providers when a lock file is missing checksums for one of
the four platforms; that can take a few minutes for the AWS provider.
