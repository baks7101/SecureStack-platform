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
