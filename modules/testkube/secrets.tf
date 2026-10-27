# Secrets Manager, picked up by the add-on's ExternalSecrets.

locals {
  secrets = {
    # Secret testkube-postgres: the API's DSN (testkube-api.postgresql.secretName). The host is
    # the container's IP on ministack, new on every rebuild.
    postgres = {
      dsn = "postgres://${local.db_username}:${random_password.db.result}@${module.db.db_instance_address}:${module.db.db_instance_port}/${local.db_name}?sslmode=disable"
    }
    # Secret testkube-storage: the bucket's keys (testkube-api.storage.secretName*).
    storage = {
      accessKeyId     = module.storage_user.access_key_id
      secretAccessKey = module.storage_user.access_key_secret
    }
  }
}

# for_each takes the keys only: the values are sensitive, which for_each refuses.
module "secrets" {
  source   = "terraform-aws-modules/secrets-manager/aws"
  version  = "~> 2.2"
  for_each = toset(["postgres", "storage"])

  name        = "platform/testkube/${each.key}"
  description = "Testkube ${each.key} (gitops/addons/testkube)"
  # Deleted at once, so a destroy and apply can reuse the name.
  recovery_window_in_days = 0

  secret_string = jsonencode(local.secrets[each.key])
}
