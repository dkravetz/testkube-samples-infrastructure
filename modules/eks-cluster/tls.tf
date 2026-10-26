# A local CA and the one certificate the Envoy Gateway serves on :443. The certificate goes to
# Secrets Manager, where External Secrets Operator picks it up for the Gateway
# (gitops/addons/envoy-gateway-system); the CA's certificate is an output for clients to trust.

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.name} local CA"
    organization = var.name
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]
}

resource "tls_private_key" "edge" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "edge" {
  private_key_pem = tls_private_key.edge.private_key_pem

  subject {
    common_name  = var.edge_tls_hostnames[0]
    organization = var.name
  }

  dns_names = var.edge_tls_hostnames
}

resource "tls_locally_signed_cert" "edge" {
  cert_request_pem   = tls_cert_request.edge.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  # macOS rejects server certificates valid for more than 825 days, even from a CA the user
  # trusts. A plan within 30 days of expiry replaces it.
  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

module "edge_tls_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 2.2"

  name        = "platform/tls/edge"
  description = "TLS certificate of the Envoy Gateway edge"
  # Deleted at once, so a destroy and apply can reuse the name.
  recovery_window_in_days = 0

  # The keys of a kubernetes.io/tls Secret.
  secret_string = jsonencode({
    "tls.crt" = tls_locally_signed_cert.edge.cert_pem
    "tls.key" = tls_private_key.edge.private_key_pem
  })
}
