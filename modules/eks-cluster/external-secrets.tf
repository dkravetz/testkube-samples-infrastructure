# The IAM role External Secrets Operator (gitops/addons/external-secrets) reads Secrets Manager
# with, through IRSA (irsa.tf). The add-on's service account names it by ARN, so its name is fixed.
module "external_secrets_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8"

  name            = "${var.name}-external-secrets"
  policy_name     = "${var.name}-external-secrets"
  use_name_prefix = false

  oidc_providers = {
    cluster = {
      provider_arn               = aws_iam_openid_connect_provider.service_accounts.arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
  # Kubernetes puts "aud" in a list, and ministack only matches a list with ForAnyValue (the sub
  # condition still holds). Real AWS: the default, StringEquals.
  trust_condition_test = "ForAnyValue:StringEquals"

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:*"]
}
