# Layer 5: keep existing application/network/WAF rules unchanged.
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  trail_name = "${local.name}-audit"
  trail_arn  = "arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/${local.trail_name}"
  alarm_name = "${local.name}-blocked-requests"
  alarm_arn  = "arn:aws:cloudwatch:${var.region}:${local.account_id}:alarm:${local.alarm_name}"
}

variable "alert_email" {
  type        = string
  sensitive   = true
  description = "SNS recipient supplied privately through TF_VAR_alert_email; confirm subscription by email."
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "Supply a valid email address."
  }
}

# Short-lived lab archive. Destroying this bucket also deletes its logs.
# Export the evidence needed for the report before teardown.
resource "aws_s3_bucket" "audit" {
  bucket_prefix = "dvwa-audit-"
  force_destroy = true
  tags          = { Stage = "layer5" }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    id     = "lab-log-retention"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.audit.arn
        Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
      },
      {
        Sid       = "CloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit.arn}/cloudtrail/AWSLogs/${local.account_id}/*"
        Condition = { StringEquals = {
          "aws:SourceArn" = local.trail_arn
          "s3:x-amz-acl"  = "bucket-owner-full-control"
        } }
      },
      {
        Sid       = "FlowLogsAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.audit.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike      = { "aws:SourceArn" = "arn:aws:logs:${var.region}:${local.account_id}:*" }
        }
      },
      {
        Sid       = "FlowLogsWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit.arn}/flowlogs/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
          ArnLike = { "aws:SourceArn" = "arn:aws:logs:${var.region}:${local.account_id}:*" }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.audit]
}

resource "aws_cloudtrail" "audit" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.audit.id
  s3_key_prefix                 = "cloudtrail"
  enable_logging                = true
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = false # Regional lab scope, not account-wide coverage.
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
  tags = { Stage = "layer5" }
  depends_on = [
    aws_s3_bucket_policy.audit,
    aws_s3_bucket_server_side_encryption_configuration.audit,
    aws_s3_bucket_ownership_controls.audit,
  ]
}

resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "${aws_s3_bucket.audit.arn}/flowlogs/"
  max_aggregation_interval = 60
  tags                     = { Name = "${local.name}-flow-logs", Stage = "layer5" }
  depends_on = [
    aws_s3_bucket_policy.audit,
    aws_s3_bucket_server_side_encryption_configuration.audit,
    aws_s3_bucket_ownership_controls.audit,
  ]
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name}"
  retention_in_days = 7
  tags              = { Stage = "layer5" }
}

# AWS configures the CloudWatch log-delivery resource policy when enabling logging.
# The caller must have logs:CreateLogDelivery and logs:PutResourcePolicy permission.
resource "aws_wafv2_web_acl_logging_configuration" "dvwa" {
  resource_arn            = aws_wafv2_web_acl.dvwa.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  redacted_fields {
    single_header { name = "cookie" }
  }
  redacted_fields {
    single_header { name = "authorization" }
  }
  redacted_fields {
    query_string {}
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-security-alerts"
  tags = { Stage = "layer5" }
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowThisCloudWatchAlarm"
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alerts.arn
      Condition = { StringEquals = {
        "aws:SourceAccount" = local.account_id
        "aws:SourceArn"     = local.alarm_arn
      } }
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "blocked" {
  alarm_name          = local.alarm_name
  alarm_description   = "At least one WAF-blocked request in a one-minute period (lab threshold)."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    WebACL = aws_wafv2_web_acl.dvwa.visibility_config[0].metric_name
    Rule   = "ALL"
    Region = var.region
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = { Stage = "layer5" }
  depends_on    = [aws_sns_topic_policy.alerts]
}

output "audit_bucket_name" {
  value = aws_s3_bucket.audit.id
}
output "trail_arn" {
  value = aws_cloudtrail.audit.arn
}
output "flow_log_id" {
  value = aws_flow_log.vpc.id
}
output "waf_log_group_name" {
  value = aws_cloudwatch_log_group.waf.name
}
output "alert_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
output "blocked_alarm_name" {
  value = aws_cloudwatch_metric_alarm.blocked.alarm_name
}
