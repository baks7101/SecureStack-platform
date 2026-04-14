
output "kms_key_arn" {
  description = "ARN of the KMS key used for EKS secret encryption"
  value       = aws_kms_key.eks.arn
}
