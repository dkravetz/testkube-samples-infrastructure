# Signing keys, the admin's login and the minted admin token.

resource "random_password" "pat_key" {
  length  = 32
  special = false
}

resource "random_password" "internal_key" {
  length  = 32
  special = false
}

locals {
  # Terrakube decodes PatSecret and InternalSecret as base64url and uses the bytes as HMAC keys.
  pat_secret      = trimsuffix(replace(replace(base64encode(random_password.pat_key.result), "+", "-"), "/", "_"), "=")
  internal_secret = trimsuffix(replace(replace(base64encode(random_password.internal_key.result), "+", "-"), "/", "_"), "=")
}

# The admin's password for the UI. Dex only gets its bcrypt hash.
resource "random_password" "admin" {
  length  = 24
  special = false
}

resource "random_uuid" "admin_token" {}

resource "time_static" "admin_token" {
  triggers = {
    key = random_password.pat_key.result
  }
}

# A PAT is an HS256 JWT signed with the raw PAT key; Terrakube accepts one whose ID it has never
# stored, so it needs no API call. It doesn't expire.
resource "jwt_hashed_token" "admin" {
  algorithm = "HS256"
  secret    = random_password.pat_key.result
  claims_json = jsonencode({
    iss            = "Terrakube"
    aud            = "Terrakube"
    sub            = "${local.admin_email} (Token)"
    jti            = random_uuid.admin_token.result
    email          = local.admin_email
    email_verified = true
    name           = "Platform admin (Token)"
    groups         = [local.admin_group]
    iat            = time_static.admin_token.unix
  })
}
