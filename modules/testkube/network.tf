data "aws_vpc" "this" {
  id = var.vpc_id
}

# By CIDR: ministack returns a rule's referenced group as "<account>/sg-...", so a rule naming
# the cluster's security groups never stops showing a diff.
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = var.name
  description = "Testkube's Postgres, reachable from the VPC"
  vpc_id      = var.vpc_id

  ingress_rules = {
    postgres = {
      from_port = 5432
      to_port   = 5432
      cidr_ipv4 = data.aws_vpc.this.cidr_block
    }
  }
}
