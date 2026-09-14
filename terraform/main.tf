# SecureStack Platform — Terraform Root
# The platform owns only shared identity infrastructure (the GitHub OIDC
# provider + platform role). Application infrastructure (VPC/EKS/etc.) lives
# in each app repo, which references the shared OIDC provider defined here.
# See github-oidc.tf for the actual resources.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "securestack-tfstate-761584754677"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "securestack-tflock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "securestack-platform"
      ManagedBy = "terraform"
    }
  }
}
