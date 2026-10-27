locals {
  tofu_role_arn = "arn:aws:iam::000000000000:role/tofu"
}

# ministack's root key, assuming the tofu role from bootstrap/tofu-state.
provider "aws" {
  region     = "us-east-1"
  access_key = "000000000000"
  secret_key = "test"

  assume_role {
    role_arn = local.tofu_role_arn
  }

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    ec2            = "http://localhost:4566"
    eks            = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kms            = "http://localhost:4566"
    logs           = "http://localhost:4566"
    rds            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
  s3_use_path_style = true
}

locals {
  # `aws eks get-token` with ministack's root key. ministack (AUTH=true) only accepts tokens
  # signed for the real STS host; get-token signs locally, nothing reaches AWS. It can't assume
  # the tofu role first: that AssumeRole call would go to the same (real) STS host.
  exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name, "--output", "json"]
    env = {
      AWS_REGION            = "us-east-1"
      AWS_ACCESS_KEY_ID     = "000000000000"
      AWS_SECRET_ACCESS_KEY = "test"
      AWS_ENDPOINT_URL_STS  = "https://sts.us-east-1.amazonaws.com"
    }
  }
}

provider "kubernetes" {
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)

  exec {
    api_version = local.exec.api_version
    command     = local.exec.command
    args        = local.exec.args
    env         = local.exec.env
  }
}

# Installs Argo CD and the addons ApplicationSet (modules/eks-cluster).
provider "helm" {
  kubernetes = {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)
    exec                   = local.exec
  }
}
