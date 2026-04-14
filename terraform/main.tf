# SecureStack Platform — Terraform Root Module
# Orchestrates VPC, EKS, and Security modules

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Remote state in S3 (uncomment when ready to apply)
  # backend "s3" {
  #   bucket         = "securestack-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "eu-west-2"
  #   encrypt        = true
  #   dynamodb_table = "securestack-terraform-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# --- VPC Module ---
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
}

# --- EKS Module ---
module "eks" {
  source = "./modules/eks"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_version      = var.cluster_version
  node_instance_types  = var.node_instance_types
  node_desired_size    = var.node_desired_size
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
}

# --- Security Module ---
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  kms_key_arn  = module.eks.kms_key_arn
}
