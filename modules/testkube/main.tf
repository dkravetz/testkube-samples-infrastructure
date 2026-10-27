# Testkube's database and storage (RDS Postgres for its metadata, S3 for logs and artifacts).
# Everything the add-on (gitops/addons/testkube) needs goes to Secrets Manager, one secret per
# Kubernetes Secret.

locals {
  db_name     = "testkube"
  db_username = "testkube"
}
