module "valkey" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.11"

  # ElastiCache runs Valkey only as a replication group; one node, no auth token: Terrakube only
  # uses it as a job queue and cache.
  replication_group_id = var.name
  description          = "Terrakube job queue and cache"
  num_cache_clusters   = 1

  engine         = "valkey"
  engine_version = "9.1"
  node_type      = "cache.t4g.micro"

  # ministack would serve TLS with its own self-signed certificate, which Terrakube's client
  # doesn't trust. Real AWS: true, and TerrakubeRedisSSL=true for the pods.
  transit_encryption_enabled = false

  subnet_ids            = var.subnet_ids
  create_security_group = false
  security_group_ids    = [module.security_group.id]

  # No slow-log delivery to CloudWatch (the module's default).
  log_delivery_configuration = {}

  apply_immediately = true
}
