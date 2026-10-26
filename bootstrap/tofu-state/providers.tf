# ministack's root caller: a 12-digit access key is that account's root, any secret works.
provider "aws" {
  region     = "us-east-1"
  access_key = "000000000000"
  secret_key = "test"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    iam = "http://localhost:4566"
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}
