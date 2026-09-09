# ─────────────────────────────────────────────
# App secrets in Secrets Manager (source of truth; ESO syncs them into k8s)
# ─────────────────────────────────────────────

# Customer-managed KMS key for encrypting Secrets Manager secrets (CKV_AWS_149).
# We own this key: control the policy, enable rotation, can revoke in an incident.
resource "aws_kms_key" "secrets" {
  description         = "${var.project_name} Secrets Manager encryption key"
  enable_key_rotation = true

  tags = {
    Name        = "${var.project_name}-secrets-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Guard token and JWT secret: Terraform generates these (no human types them).
resource "random_password" "llm_guard_token" {
  length  = 32
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

# One Secrets Manager entry holding all three app secrets as JSON.
resource "aws_secretsmanager_secret" "app" {
  name        = "${var.project_name}/app/secrets"
  description = "MediTriage app secrets: openai key, guard token, jwt secret"
  kms_key_id  = aws_kms_key.secrets.arn # customer-managed CMK (CKV_AWS_149)
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    "openai-api-key"  = "PLACEHOLDER_SET_MANUALLY"
    "llm-guard-token" = random_password.llm_guard_token.result
    "jwt-secret"      = random_password.jwt_secret.result
  })

  # The OpenAI key is set by hand after apply (only OpenAI can mint it), so
  # ignore drift on the secret_string — otherwise Terraform would overwrite
  # your real key with the placeholder on every apply.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

output "app_secret_arn" {
  description = "ARN of the app secrets bundle in Secrets Manager"
  value       = aws_secretsmanager_secret.app.arn
}
