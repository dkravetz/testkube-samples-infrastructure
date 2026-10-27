# State files, outputs, logs and registry modules.
#
# Terrakube 2.33 signs every call to a custom S3 endpoint for the pseudo-region "auto"
# (Cloudflare R2's), and S3 redirects a call signed for another region than the bucket's, which
# Terrakube doesn't follow. So with an endpoint the bucket lives in "auto". From Terrakube 2.34
# on: the provider's region, and AwsEndpointRegion for the pods.
# Not terraform-aws-modules/s3-bucket: it looks the region up (data "aws_region"), which fails
# for "auto".
resource "aws_s3_bucket" "this" {
  bucket = var.name
  region = var.s3_endpoint != "" ? "auto" : null
  # A rebuild deletes everything; state history lives in the bucket.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id
  region = aws_s3_bucket.this.region

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Terrakube only takes a custom S3 endpoint together with static keys (its role/default-credentials
# mode ignores the endpoint), so it gets an IAM user scoped to the bucket. Real AWS: an IRSA role
# with the same policy and the chart's enableRoleAuthentication.
data "aws_iam_policy_document" "bucket" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
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
