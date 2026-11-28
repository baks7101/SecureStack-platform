# ---------------------------------------------------------------------
# Terraform state bucket policy
# ---------------------------------------------------------------------
# The state bucket (created out-of-band) holds state for this repo and
# ai-vibecode-lab. Terraform writes everything it manages into state in
# plain text, including generated secrets (the OpenSearch master password).
# Before this policy the bucket had NO policy at all: protection relied
# entirely on every identity's own IAM permissions being right, and one
# CI role could read it through ReadOnlyAccess (fixed 28 Nov).
#
# This is the lock on the cabinet itself:
#   1. Deny every principal except the state admins and the account root
#      (break-glass), whatever their own IAM policies allow.
#   2. Deny any request not made over HTTPS.
#
# Manages ONLY the policy, not the bucket. Applied by hand: CI never
# changes who can access state.

data "aws_caller_identity" "state_policy" {}

locals {
  state_bucket = "securestack-tfstate-761584754677"

  # Root is always allowed so a lost or deleted admin can never make the
  # state permanently unreachable.
  state_allowed_principals = concat(
    var.state_admin_principal_arns,
    ["arn:aws:iam::${data.aws_caller_identity.state_policy.account_id}:root"],
  )

  state_bucket_resources = [
    "arn:aws:s3:::${local.state_bucket}",
    "arn:aws:s3:::${local.state_bucket}/*",
  ]
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = local.state_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllExceptStateAdminsAndRoot"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = local.state_bucket_resources
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = local.state_allowed_principals
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = local.state_bucket_resources
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
}
