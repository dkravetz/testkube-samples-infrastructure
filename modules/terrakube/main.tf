# Terrakube's database, cache and storage (RDS Postgres, ElastiCache Valkey, S3), its signing
# secrets, the admin login, and an admin API token (PAT) minted here so nothing needs a click.
# Everything the add-on (gitops/addons/terrakube) needs goes to Secrets Manager, one secret per
# Kubernetes Secret, keyed by the environment variables Terrakube's pods read.

locals {
  # Must match gitops/addons/terrakube/values.yaml.
  db_name        = "terrakube"
  db_username    = "terrakube"
  dex_client_id  = "terrakube"
  admin_email    = "admin@platform.localhost"
  admin_group    = "TERRAKUBE_ADMIN"
  admin_hash_env = "TERRAKUBE_ADMIN_PASSWORD_HASH"
}
