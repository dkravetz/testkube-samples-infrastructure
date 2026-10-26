# Add-ons

Argo CD's `addons` ApplicationSet (created by `stacks/eks`, `modules/eks-cluster`) turns every
directory here into one Application:

- name and namespace = the directory name (the namespace is created on sync);
- source = this repo, branch `main`, that directory: plain manifests, a `kustomization.yaml`,
  or a Helm chart (`Chart.yaml` with the upstream chart as a dependency and a `values.yaml`);
- automated sync with prune and self-heal; retries for up to ~10 minutes, so an add-on that
  needs another add-on's CRDs converges once they exist.

Add an add-on = add a directory and merge to `main`.
