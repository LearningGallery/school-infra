# Region-deny service control policy. Applied in the organisation management account, attached to the
# workload OU, so even an administrator in the workload account cannot create resources elsewhere.
# Global services are exempted because they have no regional endpoint.
data "aws_iam_policy_document" "region_deny" {
  statement {
    sid    = "DenyOutsideApprovedRegions"
    effect = "Deny"
    not_actions = [
      "a4b:*", "budgets:*", "ce:*", "chime:*", "cloudfront:*", "cur:*", "globalaccelerator:*",
      "health:*", "iam:*", "organizations:*", "route53:*", "route53domains:*", "shield:*",
      "sts:*", "support:*", "trustedadvisor:*", "waf:*", "wafv2:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.approved_regions
    }
  }
}

resource "aws_organizations_policy" "region_deny" {
  count       = var.manage_scp ? 1 : 0
  name        = "deny-outside-approved-regions"
  description = "Data residency: block API calls outside the approved regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.region_deny.json
}

resource "aws_organizations_policy_attachment" "region_deny" {
  count     = var.manage_scp ? 1 : 0
  policy_id = aws_organizations_policy.region_deny[0].id
  target_id = var.scp_target_id
}
