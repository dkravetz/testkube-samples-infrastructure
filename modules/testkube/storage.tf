# Execution logs and artifacts.
module "bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.17"

  bucket = var.name
  # A rebuild deletes everything; logs and artifacts are disposable.
  force_destroy = true
}

# Testkube's S3 client takes static keys only (storage.accessKeyId / secretAccessKey), so it
# gets an IAM user scoped to the bucket. Real AWS: an IRSA role with the same policy.
data "aws_iam_policy_document" "bucket" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration"]
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
