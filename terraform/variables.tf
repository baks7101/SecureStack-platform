variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "securestack"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "state_admin_principal_arns" {
  description = "IAM user or role ARNs allowed to read and write Terraform state, in addition to the account root. No default: pass at apply time."
  type        = list(string)

  validation {
    condition = length(var.state_admin_principal_arns) > 0 && alltrue([
      for arn in var.state_admin_principal_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/", arn))
    ])
    error_message = "List at least one IAM user or role ARN. An empty or malformed list would lock everyone except root out of Terraform state."
  }
}
