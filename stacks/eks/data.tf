# The VPC from stacks/vpc: its ID and the private subnets the cluster uses.
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
