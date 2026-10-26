# This is a workaround for Ministack's EKS in order to have IRSA without the eks module's enable_irsa:
# k3s signs service account tokens with its own issuer, not the one ministack advertises for the cluster
# (and enable_irsa would need that one on https), so IAM trusts the issuer the tokens actually carry.
# ministack's STS reads the token's claims without checking its signature.
# Real AWS: enable_irsa = true and module.eks.oidc_provider_arn.
resource "aws_iam_openid_connect_provider" "service_accounts" {
  url            = "https://kubernetes.default.svc.cluster.local"
  client_id_list = ["sts.amazonaws.com"]
}
