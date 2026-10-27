# State files, outputs, logs and registry modules.
module "bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.17"

  bucket = var.name
  # A rebuild deletes everything; state history lives in the bucket.
  force_destroy = true
}

# Terrakube only takes a custom S3 endpoint together with static keys (its role/default-credentials
# mode ignores the endpoint), so it gets an IAM user scoped to the bucket. Real AWS: an IRSA role
# with the same policy and the chart's enableRoleAuthentication.
data "aws_iam_policy_document" "bucket" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [module.bucket.s3_bucket_arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.bucket.s3_bucket_arn}/*"]
  }
}

module "storage_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 6.8"

  name                 = "${var.name}-storage"
  create_login_profile = false
  create_access_key    = true

  create_inline_policy           = true
  source_inline_policy_documents = [data.aws_iam_policy_document.bucket.json]
}
