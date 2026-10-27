output "bucket" {
  description = "Bucket of Testkube's logs and artifacts."
  value       = module.bucket.s3_bucket_id
}
