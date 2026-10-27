# Secrets Manager, picked up by the add-on's ExternalSecrets.

locals {
  secrets = {
    # Secret terrakube-api-secrets. The chart's ConfigMap can't hold the hosts (container IPs on
    # ministack, new on every rebuild), a custom S3 endpoint or the bucket's region (storage.tf);
    # Secrets come after ConfigMaps in the pods' envFrom, so these values win.
    api = {
      PatSecret              = local.pat_secret
      InternalSecret         = local.internal_secret
      DexClientId            = local.dex_client_id
      DatasourceHostname     = module.db.db_instance_address
      DatasourcePassword     = random_password.db.result
      TerrakubeRedisHostname = module.valkey.replication_group_primary_endpoint_address
      AwsEndpoint            = var.s3_endpoint
      AwsStorageRegion       = aws_s3_bucket.this.bucket_region
      AwsStorageAccessKey    = module.storage_user.access_key_id
      AwsStorageSecretKey    = module.storage_user.access_key_secret
    }
    # Secret terrakube-executor-secrets.
    executor = {
      InternalSecret              = local.internal_secret
      TerrakubeRedisHostname      = module.valkey.replication_group_primary_endpoint_address
      AwsEndpoint                 = var.s3_endpoint
      AwsTerraformStateRegion     = aws_s3_bucket.this.bucket_region
      AwsTerraformOutputRegion    = aws_s3_bucket.this.bucket_region
      AwsTerraformStateAccessKey  = module.storage_user.access_key_id
      AwsTerraformStateSecretKey  = module.storage_user.access_key_secret
      AwsTerraformOutputAccessKey = module.storage_user.access_key_id
      AwsTerraformOutputSecretKey = module.storage_user.access_key_secret
    }
    # Secret terrakube-registry-secrets.
    registry = {
      PatSecret           = local.pat_secret
      InternalSecret      = local.internal_secret
      AppClientId         = local.dex_client_id
      AwsEndpoint         = var.s3_endpoint
      AwsStorageRegion    = aws_s3_bucket.this.bucket_region
      AwsStorageAccessKey = module.storage_user.access_key_id
      AwsStorageSecretKey = module.storage_user.access_key_secret
    }
    # Secret terrakube-dex-env: Dex reads the admin's hash from this variable (hashFromEnv).
    dex = {
      (local.admin_hash_env) = random_password.admin.bcrypt_hash
    }
  }
}

# for_each takes the keys only: the values are sensitive, which for_each refuses.
module "secrets" {
  source   = "terraform-aws-modules/secrets-manager/aws"
  version  = "~> 2.2"
  for_each = toset(["api", "executor", "registry", "dex"])

  name        = "platform/terrakube/${each.key}"
  description = "Terrakube ${each.key} environment (gitops/addons/terrakube)"
  # Deleted at once, so a destroy and apply can reuse the name.
  recovery_window_in_days = 0

  secret_string = jsonencode(local.secrets[each.key])
}
