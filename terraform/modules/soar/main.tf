# =============================================================================
# SecureStack SOAR module
# GuardDuty finding (severity >= var.min_severity)
#   -> EventBridge rule -> SOAR Lambda -> disable key / isolate EC2 / notify SNS
# =============================================================================

data "archive_file" "soar" {
  type        = "zip"
  source_file = var.lambda_source_file
  output_path = "${path.module}/build/soar-auto-response.zip"
}

resource "aws_sns_topic" "soar_alerts" {
  name              = "${var.name_prefix}-soar-alerts"
  kms_master_key_id = "alias/aws/sns" # encrypt messages at rest (CKV_AWS_26)
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.soar_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_security_group" "isolation" {
  name        = "${var.name_prefix}-isolation"
  description = "SOAR isolation SG - no ingress/egress, cuts a compromised instance off the network"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-isolation" })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "soar" {
  name               = "${var.name_prefix}-soar-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "soar" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  # checkov:skip=CKV_AWS_109:Incident response cannot know the compromised principal in advance; scoped to the single action iam:UpdateAccessKey.
  # checkov:skip=CKV_AWS_107:No credential-exposure actions granted; only key deactivation.
  # checkov:skip=CKV_AWS_356:SOAR must act on any compromised key/instance; the * is on resource, actions are minimised to two.
  # checkov:skip=CKV_AWS_111:Write access is limited to disabling keys and isolating instances during an active incident.
  statement {
    sid       = "DisableCompromisedKeys"
    effect    = "Allow"
    actions   = ["iam:UpdateAccessKey"]
    resources = ["*"]
  }
  statement {
    sid       = "IsolateInstances"
    effect    = "Allow"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]
  }
  statement {
    sid       = "Notify"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.soar_alerts.arn]
  }
}

resource "aws_iam_role_policy" "soar" {
  name   = "${var.name_prefix}-soar-permissions"
  role   = aws_iam_role.soar.id
  policy = data.aws_iam_policy_document.soar.json
}

# checkov:skip=CKV_AWS_117:SOAR calls IAM/EC2/SNS APIs; running in-VPC would need NAT/endpoints, disproportionate for this lab.
# checkov:skip=CKV_AWS_116:No DLQ — SOAR failures surface via CloudWatch logs + are re-triggerable by GuardDuty; DLQ is over-engineering here.
# checkov:skip=CKV_AWS_272:Code-signing requires a Signer profile; disproportionate for a single internal response function.
# checkov:skip=CKV_AWS_173:Env vars hold only an SNS ARN and SG ID (non-secret identifiers), not sensitive data.
resource "aws_lambda_function" "soar" {
  function_name                  = "${var.name_prefix}-soar-auto-response"
  role                           = aws_iam_role.soar.arn
  runtime                        = "python3.12"
  handler                        = "soar-auto-response.handler"
  filename                       = data.archive_file.soar.output_path
  source_code_hash               = data.archive_file.soar.output_base64sha256
  timeout                        = 30
  reserved_concurrent_executions = 5 # cap parallel invocations (CKV_AWS_115)

  tracing_config {
    mode = "Active" # X-Ray tracing for observability (CKV_AWS_50)
  }

  environment {
    variables = {
      SNS_TOPIC_ARN   = aws_sns_topic.soar_alerts.arn
      ISOLATION_SG_ID = aws_security_group.isolation.id
    }
  }
  tags = var.tags
}

# checkov:skip=CKV_AWS_158:SOAR execution logs are operational (not secrets); a dedicated CMK is disproportionate for this lab module. Production would pass a CMK in.
# checkov:skip=CKV_AWS_338:7-day retention is a deliberate lab cost decision; production would extend per compliance requirements.
resource "aws_cloudwatch_log_group" "soar" {
  name              = "/aws/lambda/${aws_lambda_function.soar.function_name}"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${var.name_prefix}-guardduty-to-soar"
  description = "Route GuardDuty findings (severity >= ${var.min_severity}) to the SOAR Lambda"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.min_severity] }]
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "soar" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "soar-lambda"
  arn       = aws_lambda_function.soar.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty.arn
}
