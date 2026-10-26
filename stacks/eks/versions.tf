terraform {
  required_version = "~> 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }

  # State in ministack's S3 (bucket and role from bootstrap/tofu-state).
  backend "s3" {
    bucket       = "testkube-poc-tofu-state"
    key          = "eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true

    access_key = "000000000000"
    secret_key = "test"
    assume_role = {
      role_arn = "arn:aws:iam::000000000000:role/tofu"
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
