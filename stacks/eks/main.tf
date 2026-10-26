# The EKS cluster. On ministack, CreateCluster starts a real single-node k3s.

locals {
  # These are needed for ArgoCD's Github access
  github_app = {
    url_prefix      = "https://github.com/dkravetz"
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    private_key     = file("${path.module}/../../.local/github-app.pem")
  }
}

module "cluster" {
  source = "../../modules/eks-cluster"

  name               = "testkube-poc"
  kubernetes_version = "1.36" # k3s image set in bootstrap/ministack/Taskfile.yml

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets


  # Cluster admin for the root key that kubectl and the kubernetes/helm providers sign their
  # tokens with (see providers.tf); the tofu role (the creator) gets it from the module.
  access_entries = {
    root = {
      principal_arn = "arn:aws:iam::000000000000:root"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  gitops_repo_url = "https://github.com/dkravetz/testkube-samples-infrastructure"
  github_app      = local.github_app
}
