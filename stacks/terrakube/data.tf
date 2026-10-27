# Terrakube's admin token, minted by stacks/eks. Read from that stack's state because the
# terrakube provider refuses a token that is unknown at plan time, as it is on a cold apply of
# the stack that mints it.
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "testkube-poc-tofu-state"
    key    = "eks/terraform.tfstate"
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

data "aws_region" "current" {}
