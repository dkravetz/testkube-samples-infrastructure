output "state_bucket" {
  description = "S3 bucket holding every stack's state."
  value       = module.state_bucket.s3_bucket_id
}

output "tofu_role_arn" {
  description = "Role every stack assumes (backend and aws provider)."
  value       = module.tofu_role.arn
}
