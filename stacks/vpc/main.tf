module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "testkube-poc"
  cidr = "10.0.0.0/16"

  # EKS wants subnets in two AZs. No NAT gateway: ministack's k3s doesn't run in the VPC.
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}
