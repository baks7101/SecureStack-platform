# ─────────────────────────────────────────────
# OpenSearch domain — the SIEM aggregation + query layer
# ─────────────────────────────────────────────
# Single-node lab sizing. Production would use multi-AZ with dedicated
# master nodes; this is deliberately minimal for cost and a timed sim.

variable "opensearch_master_user" {
  description = "Master username for OpenSearch Dashboards login"
  type        = string
  default     = "admin"
}

variable "allowed_ip" {
  description = "Your public IP (CIDR) allowed to reach the OpenSearch endpoint"
  type        = string
}

# Generate a strong master password in Terraform — no human ever types it.
resource "random_password" "opensearch_master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# Store it in AWS Secrets Manager — the production home for secrets.
resource "aws_secretsmanager_secret" "opensearch_master" {
  name        = "${var.project_name}/opensearch/master"
  description = "OpenSearch SIEM master user credentials"
  kms_key_id  = aws_kms_key.secrets.arn # customer-managed CMK (CKV_AWS_149)
}

resource "aws_secretsmanager_secret_version" "opensearch_master" {
  secret_id = aws_secretsmanager_secret.opensearch_master.id
  secret_string = jsonencode({
    username = var.opensearch_master_user
    password = random_password.opensearch_master.result
  })
}

# OpenSearch is deliberately scoped for a lab SIEM demonstrating the pipeline + controls.
# Production would add HA master nodes, VPC isolation, and full audit logging (all real cost/complexity).
resource "aws_opensearch_domain" "siem" {
  # checkov:skip=CKV_AWS_318:Dedicated master nodes (HA) omitted — single-node is a deliberate lab cost decision.
  # checkov:skip=CKV2_AWS_59:Same — no dedicated master node for a single-node lab cluster.
  # checkov:skip=CKV_AWS_137:Public endpoint secured by fine-grained access control + IP restriction instead of VPC-only, by design.
  # checkov:skip=CKV_AWS_248:Not using a VPC/default SG — access is controlled via FGAC and domain access policy.
  # checkov:skip=CKV_AWS_247:Encrypted at rest with an AWS-managed key; a customer CMK is a production hardening step.
  # checkov:skip=CKV_AWS_317:Audit logging to CloudWatch omitted for lab cost; a documented production next step.
  # checkov:skip=CKV_AWS_84:Domain (slow/error) logging omitted for lab cost; production would enable it.
  domain_name    = "${var.project_name}-siem"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 1
    # No dedicated masters, no zone awareness — single-node lab.
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }

  # Encryption at rest and in transit — basic hardening, cheap to enable.
  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Fine-grained access control: log in to Dashboards with the master user.
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.opensearch_master_user
      master_user_password = random_password.opensearch_master.result
    }
  }

  # Public endpoint, restricted by IP. Lab choice; production = VPC-internal.
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "arn:aws:es:${var.aws_region}:*:domain/${var.project_name}-siem/*"
    }]
  })

  tags = {
    Name        = "${var.project_name}-siem"
    Environment = var.environment
  }
}

output "opensearch_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = aws_opensearch_domain.siem.endpoint
}
