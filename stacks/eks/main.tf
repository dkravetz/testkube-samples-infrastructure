# The EKS cluster. On ministack, CreateCluster starts a real single-node k3s (BRIEF D3).

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "testkube-poc-tofu-state"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"

    access_key = "000000000000"
    secret_key = "test"
    assume_role = {
      role_arn = local.tofu_role_arn
    }

    endpoints = {
      iam = "http://localhost:4566"
      s3  = "http://localhost:4566"
      sts = "http://localhost:4566"
    }
    use_path_style              = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = "testkube-poc"
  kubernetes_version = "1.31"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets

  endpoint_public_access = true

  # ministack's OIDC issuer is plain http://localhost:4566/oidc/...; the module's tls_certificate
  # lookup only accepts https. Real AWS: true (or pod identity).
  enable_irsa = false

  # Cluster admin for the tofu role (the creator) and for the root key that kubectl and the
  # kubernetes/helm providers sign their tokens with (see providers.tf).
  enable_cluster_creator_admin_permissions = true
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
}
