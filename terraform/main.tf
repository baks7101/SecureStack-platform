# SecureStack Platform — Terraform root module
# Modules will be added as we build M5 (AWS infrastructure)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for all resources"
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
