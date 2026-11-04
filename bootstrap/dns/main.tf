# DNS and TLS for the School app, shared by every environment in the account.
#
# One Route 53 zone for ONE subdomain (for example school.example.com) is delegated from the registrar, so the apex
# domain and everything else on it stays where it is. An ACM certificate for that subdomain and a wildcard under it
# is validated through DNS records this stack creates in the zone, which makes validation automatic once the
# registrar points the subdomain at the four name servers in the output.
#
#   dev.school.example.com   staging.school.example.com   school.example.com (production)
#
# The real name is a variable value kept outside Git (a tfvars file you do not commit). Applied once per account with
# LOCAL state, like the other bootstrap stacks; it creates no billable compute (a hosted zone costs about 0.50 USD a
# month, the certificate is free).
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "Region of the load balancers: an ACM certificate is regional, so it must live where the ALB lives."
  type        = string
  default     = "eu-west-1"
}

variable "zone_name" {
  description = "The delegated subdomain, for example school.example.com. Never an apex you want to keep at the registrar."
  type        = string

  validation {
    condition     = length(split(".", var.zone_name)) >= 3 && !startswith(var.zone_name, "*") && lower(var.zone_name) == var.zone_name
    error_message = "zone_name must be a lower-case subdomain such as school.example.com (at least three labels, no wildcard)."
  }
}

locals {
  tags = { project = "devops-zero-to-hero", purpose = "dns-and-tls" }
}

resource "aws_route53_zone" "this" {
  #checkov:skip=CKV2_AWS_38:DNSSEC needs the registrar to publish a DS record for a delegated subdomain; out of scope for the learning stack
  #checkov:skip=CKV2_AWS_39:Query logging needs a log group in us-east-1; out of scope for the learning stack
  name    = var.zone_name
  comment = "School app: delegated subdomain, managed by Terraform"
  tags    = local.tags
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.zone_name
  subject_alternative_names = ["*.${var.zone_name}"]
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# One record per name on the certificate, keyed by the domain (known at plan time). The apex of the zone and its
# wildcard resolve to the SAME validation record, so allow_overwrite lets the second write be a no-op.
resource "aws_route53_record" "validation" {
  for_each = {
    for o in aws_acm_certificate.this.domain_validation_options : o.domain_name => {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 300
  allow_overwrite = true
}

output "name_servers" {
  description = "Create NS records for the subdomain at the registrar pointing at these four servers."
  value       = aws_route53_zone.this.name_servers
}

output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "certificate_arn" {
  description = "Use as the ALB certificate annotation once the certificate status is ISSUED."
  value       = aws_acm_certificate.this.arn
}
