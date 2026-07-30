# ─────────────────────────────────────────────
# IRSA: IAM role for External Secrets Operator
# ─────────────────────────────────────────────
# ESO runs in the cluster and syncs secrets FROM Secrets Manager INTO k8s.
# It needs read-only access to exactly the app secret — nothing else.
# Same least-privilege IRSA pattern as Fluent Bit.

resource "aws_iam_role" "eso" {
  name = "${var.project_name}-eso-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # Only the external-secrets service account in the
          # external-secrets namespace may assume this role.
          "${local.oidc_host}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-eso-irsa"
    Environment = var.environment
  }
}

# Read-only, and scoped to ONLY the two secrets we manage — not all secrets.
resource "aws_iam_role_policy" "eso_read_secrets" {
  name = "${var.project_name}-eso-read-secrets"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        aws_secretsmanager_secret.app.arn,
        aws_secretsmanager_secret.opensearch_master.arn
      ]
    }]
  })
}

output "eso_role_arn" {
  description = "IAM role ARN to annotate on the External Secrets service account"
  value       = aws_iam_role.eso.arn
}
