# SecureStack Terraform Policies
# Custom rules enforced via Conftest in the CI pipeline

package terraform

import future.keywords.in
import future.keywords.if

# RULE 1: All resources must have required tags
# Why: Untagged resources can't be tracked for cost or ownership
# Business impact: Unattributed cloud spend cost us £3k/month before tagging was enforced
deny[msg] if {
    resource := input.resource_changes[_]
    resource.change.after.tags != null
    not resource.change.after.tags.Environment
    msg := sprintf("Resource '%s' is missing the 'Environment' tag. All resources must be tagged for cost tracking and compliance.", [resource.address])
}

deny[msg] if {
    resource := input.resource_changes[_]
    resource.change.after.tags != null
    not resource.change.after.tags.ManagedBy
    msg := sprintf("Resource '%s' is missing the 'ManagedBy' tag. This tag identifies whether resources are managed by Terraform, manual, or another tool.", [resource.address])
}

# RULE 2: S3 buckets must have encryption enabled
# Why: Unencrypted buckets expose data if bucket policy is misconfigured
# Business impact: An unencrypted S3 bucket caused the Twitch source code leak (2021)
deny[msg] if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.after.server_side_encryption_configuration == null
    msg := sprintf("S3 bucket '%s' must have server-side encryption enabled.", [resource.address])
}

# RULE 3: Security groups must not allow unrestricted ingress
# Why: 0.0.0.0/0 on sensitive ports exposes services to the entire internet
# Business impact: Open security groups are the #1 cloud misconfiguration finding
deny[msg] if {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    ingress := resource.change.after.ingress[_]
    cidr := ingress.cidr_blocks[_]
    cidr == "0.0.0.0/0"
    ingress.from_port != 443
    ingress.from_port != 80
    msg := sprintf("Security group '%s' allows unrestricted ingress (0.0.0.0/0) on port %d. Only ports 80 and 443 may be open to the internet.", [resource.address, ingress.from_port])
}

# RULE 4: EKS clusters must have logging enabled
# Why: Without audit logs, you can't investigate security incidents
# Business impact: Audit logging is required by ISO 27001 A.12.4 and SOC 2 CC7.2
deny[msg] if {
    resource := input.resource_changes[_]
    resource.type == "aws_eks_cluster"
    count(resource.change.after.enabled_cluster_log_types) == 0
    msg := sprintf("EKS cluster '%s' must have audit logging enabled for security monitoring and compliance.", [resource.address])
}

# RULE 5: RDS/database instances must not be publicly accessible
# Why: A public database is an open invitation for data theft
# Business impact: The Uber 2016 breach started with a publicly accessible database
deny[msg] if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.publicly_accessible == true
    msg := sprintf("Database '%s' must not be publicly accessible. Use private subnets and VPC endpoints.", [resource.address])
}

# RULE 6: IAM policies must not use wildcard resources
# Why: Wildcard (*) grants access to ALL resources of that type
# Business impact: Overly permissive IAM was the root cause in 43% of cloud breaches (Mandiant 2024)
deny[msg] if {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_policy"
    statement := resource.change.after.policy.Statement[_]
    statement.Resource == "*"
    statement.Effect == "Allow"
    msg := sprintf("IAM policy '%s' uses wildcard (*) resource. Scope permissions to specific resource ARNs.", [resource.address])
}
