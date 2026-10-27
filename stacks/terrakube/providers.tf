locals {
  tofu_role_arn = "arn:aws:iam::000000000000:role/tofu"

  # From the Mac, through socat and the edge Gateway.
  terrakube_endpoint = "http://terrakube-api.platform.localhost"
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
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

provider "terrakube" {
  endpoint = local.terrakube_endpoint
  token    = data.terraform_remote_state.eks.outputs.terrakube_admin_token
}
