variable "name" {
  description = "Name of every resource (database, bucket, IAM user)."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the database; its CIDR may reach it."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets of the database (two AZs or more)."
  type        = list(string)
}
