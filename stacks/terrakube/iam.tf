# The workspaces' AWS identity: what an app's infrastructure creates (a Postgres database, its
# security group and its credentials under apps/). ministack runs with IAM enforced, so a missing
# permission fails here as it would on AWS.
data "aws_iam_policy_document" "workspaces" {
  statement {
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["rds:*"]
    resources = ["*"]
  }

  statement {
    actions   = ["secretsmanager:*"]
    resources = ["arn:aws:secretsmanager:*:*:secret:apps/*"]
  }
}

module "workspaces_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 6.8"

  name                 = "testkube-poc-terrakube-workspaces"
  create_login_profile = false
  create_access_key    = true

  create_inline_policy           = true
  source_inline_policy_documents = [data.aws_iam_policy_document.workspaces.json]
}
