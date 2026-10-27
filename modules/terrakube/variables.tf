variable "name" {
  description = "Name of every resource (database, cache, bucket, IAM user)."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the database and cache; its CIDR may reach them."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets of the database and cache (two AZs or more)."
  type        = list(string)
}

variable "s3_endpoint" {
  description = "S3 endpoint as Terrakube's pods see it; empty for AWS's own."
  type        = string
  default     = ""
}
