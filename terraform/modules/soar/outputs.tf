output "lambda_function_name" {
  description = "Name of the SOAR Lambda (use to tail logs: aws logs tail /aws/lambda/<name>)"
  value       = aws_lambda_function.soar.function_name
}

output "lambda_arn" {
  description = "ARN of the SOAR Lambda"
  value       = aws_lambda_function.soar.arn
}

output "sns_topic_arn" {
  description = "ARN of the SOAR alerts SNS topic"
  value       = aws_sns_topic.soar_alerts.arn
}

output "isolation_sg_id" {
  description = "ID of the isolation security group SOAR moves compromised instances into"
  value       = aws_security_group.isolation.id
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule routing GuardDuty findings to SOAR"
  value       = aws_cloudwatch_event_rule.guardduty.name
}
