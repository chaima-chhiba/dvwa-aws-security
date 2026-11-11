# Layer 3: filter requests at the ALB, after client TLS termination.
# This mitigates selected requests; DVWA itself remains deliberately vulnerable.
resource "aws_wafv2_web_acl" "dvwa" {
  name        = "${local.name}-waf"
  description = "Layer 3 regional managed-rule protection for the DVWA training lab"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {} # Retain the managed rules' actions; do not override to Count.
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "dvwa-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "dvwa-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "dvwa-web-acl"
    sampled_requests_enabled   = true
  }

  tags = { Stage = "layer3" }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.dvwa.arn
}

output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.dvwa.arn
  description = "Regional web ACL associated with the existing ALB."
}

output "alb_arn" {
  value = aws_lb.main.arn
}
