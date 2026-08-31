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
  name = "${var.name_prefix}-soar-alerts"
  tags = var.tags
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

resource "aws_lambda_function" "soar" {
  function_name    = "${var.name_prefix}-soar-auto-response"
  role             = aws_iam_role.soar.arn
  runtime          = "python3.12"
  handler          = "soar-auto-response.handler"
  filename         = data.archive_file.soar.output_path
  source_code_hash = data.archive_file.soar.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      SNS_TOPIC_ARN   = aws_sns_topic.soar_alerts.arn
      ISOLATION_SG_ID = aws_security_group.isolation.id
    }
  }
  tags = var.tags
}

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
