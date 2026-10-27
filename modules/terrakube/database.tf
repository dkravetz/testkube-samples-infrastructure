resource "random_password" "db" {
  length  = 32
  special = false
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.2"

  identifier = var.name

  engine               = "postgres"
  engine_version       = "18"
  family               = "postgres18"
  major_engine_version = "18"
  instance_class       = "db.t4g.micro"
  allocated_storage    = 20

  db_name  = local.db_name
  username = local.db_username
  port     = 5432

  # Our own password, so the same secret works on ministack and AWS; never in the plan.
  manage_master_user_password = false
  password_wo                 = random_password.db.result
  password_wo_version         = 1

  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids
  vpc_security_group_ids = [module.security_group.id]

  create_db_option_group    = false
  create_db_parameter_group = false

  skip_final_snapshot = true
  deletion_protection = false
}
