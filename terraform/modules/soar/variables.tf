variable "name_prefix" {
  description = "Prefix for all SOAR resource names (e.g. securestack)"
  type        = string
  default     = "securestack"
}

variable "lambda_source_file" {
  description = "Absolute or root-relative path to soar-auto-response.py"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the isolation security group is created in (use the module.vpc output)"
  type        = string
}

variable "min_severity" {
  description = "Minimum GuardDuty finding severity that triggers SOAR (matches the script's >= 4)"
  type        = number
  default     = 4
}

variable "alert_email" {
  description = "Optional email to receive SOAR SNS alerts during the demo. Empty = no subscription."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all SOAR resources"
  type        = map(string)
  default     = {}
}
