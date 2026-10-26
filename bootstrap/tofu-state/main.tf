# What every stack needs before it can run: an S3 bucket for its state and the role it
# assumes. This root keeps its own state locally (ministack can't hold it before it exists).

data "aws_caller_identity" "current" {}

module "state_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.17"

  bucket = "testkube-poc-tofu-state"

  versioning = {
    enabled = true
  }
}

# Anyone in the account may assume the role; with AUTH=true that is the root key only.
data "aws_iam_policy_document" "tofu_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

module "tofu_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.8"

  name            = "tofu"
  use_name_prefix = false
  description     = "Assumed by OpenTofu for every stack"

  source_trust_policy_documents = [data.aws_iam_policy_document.tofu_trust.json]

  policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}
