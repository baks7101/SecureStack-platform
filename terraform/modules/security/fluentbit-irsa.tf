# ─────────────────────────────────────────────
# IRSA: IAM role for the Fluent Bit service account
# ─────────────────────────────────────────────
# IRSA (IAM Roles for Service Accounts) grants AWS permissions to a
# SPECIFIC Kubernetes service account, not to the whole node. Only pods
# using this service account get OpenSearch write access — least
# privilege at the pod level, so a compromised pod elsewhere on the node
# inherits nothing.

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (from the eks module) for the IRSA trust policy"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL (issuer) for the IRSA trust policy"
  type        = string
}

# Strip the https:// so it can be used as a condition key in the trust policy.
locals {
  oidc_host = replace(var.oidc_provider_url, "https://", "")
}

# The role Fluent Bit's service account assumes.
resource "aws_iam_role" "fluentbit" {
  name = "${var.project_name}-fluentbit-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # Only the fluent-bit service account in the logging namespace
          # may assume this role. This is the least-privilege binding.
          "${local.oidc_host}:sub" = "system:serviceaccount:logging:fluent-bit"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-fluentbit-irsa"
    Environment = var.environment
  }
}

# The only permission Fluent Bit needs: write documents into the SIEM domain.
resource "aws_iam_role_policy" "fluentbit_opensearch" {
  name = "${var.project_name}-fluentbit-opensearch"
  role = aws_iam_role.fluentbit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "es:ESHttpPost",
        "es:ESHttpPut"
      ]
      Resource = "${aws_opensearch_domain.siem.arn}/*"
    }]
  })
}

output "fluentbit_role_arn" {
  description = "IAM role ARN to annotate on the Fluent Bit service account"
  value       = aws_iam_role.fluentbit.arn
}
