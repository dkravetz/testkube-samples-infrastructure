# ministack's root key, assuming the tofu role from bootstrap/tofu-state.
provider "aws" {
  region     = "us-east-1"
  access_key = "000000000000"
  secret_key = "test"

  assume_role {
    role_arn = "arn:aws:iam::000000000000:role/tofu"
  }

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    ec2 = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}
