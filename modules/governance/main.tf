# Cost guardrails (module 29). Budgets tell you before the bill does; anomaly detection catches the surprise
# a fixed budget misses (a NAT gateway left running, a runaway log group).
locals {
  enabled = var.monthly_budget_usd > 0 && length(var.alert_emails) > 0
}

resource "aws_budgets_budget" "monthly" {
  count        = local.enabled ? 1 : 0
  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Only this environment's spend: resources carry the Environment tag (enforced by policy).
  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Environment$${var.name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }
}

resource "aws_ce_anomaly_monitor" "services" {
  count             = local.enabled && var.anomaly_monitor_arn == "" ? 1 : 0
  name              = "${var.name}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags              = var.tags
}

resource "aws_ce_anomaly_subscription" "daily" {
  count            = local.enabled ? 1 : 0
  name             = "${var.name}-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [var.anomaly_monitor_arn != "" ? var.anomaly_monitor_arn : aws_ce_anomaly_monitor.services[0].arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_emails[0]
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["50"]
    }
  }
  tags = var.tags
}
