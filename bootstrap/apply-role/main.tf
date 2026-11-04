# Write role for the "apply" workflow. Assumable only from the GitHub Environments listed below of ONE repository,
# so an approval on the Environment gates every use. It is deliberately NOT AdministratorAccess:
#   - service actions are limited to the services the stack manages;
#   - IAM is limited to roles named dev-* / school-dev-* (var.managed_role_patterns), may attach only a short list of
#     AWS-managed policies, and may pass roles only to the services that need them;
#   - it cannot touch the CI roles (release, pull, plan, apply itself), create users or access keys, or leave the account.
# Applied once per account with LOCAL state. Review the policy whenever a module starts using a new AWS service.
terraform {
  required_version = ">= 1.10"
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
  type    = string
  default = "eu-west-1"
}

variable "account_id" {
  type = string
}

variable "github_subject_prefix" {
  description = "Exact sub prefix GitHub sends for the infrastructure repository, e.g. repo:OWNER@OWNER_ID/REPO@REPO_ID."
  type        = string

  validation {
    condition     = startswith(var.github_subject_prefix, "repo:") && !strcontains(var.github_subject_prefix, "*") && !strcontains(var.github_subject_prefix, "?")
    error_message = "github_subject_prefix must start with repo: and contain no wildcards."
  }
}

variable "oidc_provider_arn" {
  type = string
}

variable "environments" {
  description = "GitHub Environments allowed to assume the role. Approvals on these Environments are the gate."
  type        = list(string)
  default     = ["dev"]
}

variable "managed_role_patterns" {
  description = "Name patterns of the IAM roles this stack's Terraform may create and manage."
  type        = list(string)
  default     = ["dev-*", "school-dev-*"]
}

variable "state_bucket" {
  type = string
}

variable "state_key_prefix" {
  description = "State objects this role may write, e.g. dev for dev/terraform.tfstate."
  type        = string
  default     = "dev"
}

variable "state_kms_key_arn" {
  type = string
}

variable "role_name" {
  type    = string
  default = "school-infra-apply"
}

variable "dns_zone_id" {
  description = "Hosted zone of the environment's subdomain. Set it to let the destroy workflow remove the DNS records ExternalDNS wrote; empty grants no Route 53 access."
  type        = string
  default     = ""
}

variable "dns_record_names" {
  description = "Record names (lower case, no trailing dot) this role may change in the zone: the environment's host and its ExternalDNS ownership records."
  type        = list(string)
  default     = []
}

locals {
  oidc_host = "token.actions.githubusercontent.com"
  tags      = { project = "devops-zero-to-hero", purpose = "terraform-apply" }
  role_arns = [for p in var.managed_role_patterns : "arn:aws:iam::${var.account_id}:role/${p}"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [for e in var.environments : "${var.github_subject_prefix}:environment:${e}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 7200 # an EKS plus RDS apply takes a long time
  tags                 = local.tags
}

data "aws_iam_policy_document" "apply" {
  #checkov:skip=CKV_AWS_111:Write access on the managed services is the purpose of this role; IAM, state and identity actions are scoped below
  #checkov:skip=CKV_AWS_107:IAM actions are limited to named roles and managed policies
  #checkov:skip=CKV_AWS_108:Not applicable: no data-exfiltration actions are granted
  #checkov:skip=CKV_AWS_109:Constrained to named roles; no policy or permission-boundary changes outside dev-* and school-dev-*
  #checkov:skip=CKV_AWS_110:Privilege escalation is prevented by the role-name scope, the PolicyARN allow-list and the PassRole service condition
  #checkov:skip=CKV_AWS_356:Create-style actions on these services cannot be scoped to a resource that does not exist yet
  #checkov:skip=CKV_AWS_49:Wildcards are limited to the listed services
  #checkov:skip=CKV2_AWS_40:Full IAM is not granted; see the scoped IAM statements
  statement {
    sid = "ManagedServices"
    actions = [
      "ec2:*", "eks:*", "rds:*", "kms:*", "secretsmanager:*", "logs:*", "sns:*", "budgets:*", "ce:*",
      "cloudwatch:*", "elasticloadbalancing:*", "autoscaling:*", "tag:*", "ssm:GetParameter", "ssm:GetParameters",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageNamedRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
    ]
    resources = local.role_arns
  }

  statement {
    sid       = "AttachOnlyAllowedManagedPolicies"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = local.role_arns
    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::aws:policy/AmazonEKS*",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
    }
  }

  statement {
    sid       = "PassRolesOnlyToTheirServices"
    actions   = ["iam:PassRole"]
    resources = local.role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "eks.amazonaws.com", "ec2.amazonaws.com", "rds.amazonaws.com", "monitoring.rds.amazonaws.com",
        "vpc-flow-logs.amazonaws.com", "pods.eks.amazonaws.com",
      ]
    }
  }

  statement {
    sid = "ClusterOidcProviders"
    actions = [
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider", "iam:RemoveClientIDFromOpenIDConnectProvider",
    ]
    # EKS issuers only. The GitHub Actions provider is not in this list, so this role cannot alter it.
    resources = ["arn:aws:iam::${var.account_id}:oidc-provider/oidc.eks.*"]
  }

  statement {
    sid       = "ReadServiceLinkedRoles"
    actions   = ["iam:GetRole", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies"]
    resources = ["arn:aws:iam::${var.account_id}:role/aws-service-role/*"]
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com", "eks-nodegroup.amazonaws.com", "rds.amazonaws.com", "autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com", "spot.amazonaws.com", "ec2scheduled.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "ReadIdentityAndPolicies"
    actions   = ["iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicies", "iam:ListOpenIDConnectProviders", "sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # Only the destroy workflow needs this: ExternalDNS creates and updates records but never deletes them.
  dynamic "statement" {
    for_each = var.dns_zone_id == "" ? [] : [1]
    content {
      sid       = "EnvironmentDnsRecords"
      actions   = ["route53:ListResourceRecordSets", "route53:ChangeResourceRecordSets"]
      resources = ["arn:aws:route53:::hostedzone/${var.dns_zone_id}"]
      condition {
        test     = "ForAllValues:StringEquals"
        variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
        values   = var.dns_record_names
      }
    }
  }

  statement {
    sid       = "StateBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }
  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/${var.state_key_prefix}/*"]
  }
  statement {
    sid       = "StateKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [var.state_kms_key_arn]
  }

  statement {
    sid       = "DenyOrganisationAccountAndUserCreation"
    effect    = "Deny"
    actions   = ["organizations:*", "account:*", "iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "apply" {
  name   = "apply-dev-stack"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}
