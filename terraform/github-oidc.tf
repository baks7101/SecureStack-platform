# =============================================================================
# GitHub Actions OIDC — keyless CI-to-AWS authentication
# -----------------------------------------------------------------------------
# Lets the SecureStack pipeline assume a scoped, read-only AWS role using a
# short-lived OIDC token from GitHub — NO long-lived access keys stored anywhere.
# The role can ONLY be assumed by workflows in this specific repo.
# =============================================================================

# 1. Register GitHub's OIDC token issuer as trusted in this AWS account.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub's OIDC thumbprint (AWS now validates via its own trust store, but
  # the field is still required; this is GitHub's well-known value).
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "github-actions-oidc"
    Environment = var.environment
  }
}

# 2. The role the pipeline assumes. Trust policy scopes it to THIS repo only.
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Token must come from GitHub's OIDC issuer.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Token must be for THIS repo (any branch). Tighten to a branch later if wanted.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:baks7101/SecureStack-platform:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-securestack"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = {
    Name        = "github-actions-securestack"
    Environment = var.environment
  }
}

# 3. Permissions: read-only is enough for `terraform plan` (plan only READS AWS).
#    No write/create access — least privilege for a policy-check pipeline.
resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "github_actions_role_arn" {
  description = "ARN of the role the GitHub Actions pipeline assumes"
  value       = aws_iam_role.github_actions.arn
}
