output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_api_url" {
  description = "ECR URL for API images"
  value       = module.security.ecr_api_url
}

output "ecr_frontend_url" {
  description = "ECR URL for Frontend images"
  value       = module.security.ecr_frontend_url
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}
