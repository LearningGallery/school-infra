# Read-only role for the "plan" workflow (pull requests). Assumable only from the plan-<env> GitHub
# Environments of ONE repository. It can read AWS to plan and use the state bucket for the lock file; it
# cannot create, change or delete infrastructure. Applied once per account with LOCAL state.
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

variable "github_subject_prefix" {
  description = "Exact sub prefix GitHub sends for the infrastructure repository, e.g. repo:OWNER@OWNER_ID/REPO@REPO_ID (read it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub)."
  type        = string

  validation {
    condition     = startswith(var.github_subject_prefix, "repo:") && !strcontains(var.github_subject_prefix, "*") && !strcontains(var.github_subject_prefix, "?")
    error_message = "github_subject_prefix must start with repo: and contain no wildcards."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the account's GitHub OIDC provider (one per account)."
  type        = string
}

variable "environments" {
  description = "GitHub Environments allowed to assume the role."
  type        = list(string)
  default     = ["plan-dev", "plan-staging", "plan-production"]
}

variable "state_bucket" {
  description = "Terraform state bucket created by bootstrap/state."
  type        = string
}

variable "state_kms_key_arn" {
  description = "KMS key that encrypts the state bucket."
  type        = string
}

variable "role_name" {
  type    = string
  default = "school-infra-plan"
}

locals {
  oidc_host = "token.actions.githubusercontent.com"
  tags      = { project = "devops-zero-to-hero", purpose = "terraform-plan" }
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
    # Repository AND environment. Another repository, a branch job without an environment, or a fork is refused.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [for e in var.environments : "${var.github_subject_prefix}:environment:${e}"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
  tags                 = local.tags
}

# Read access to AWS so `terraform plan` can refresh resources. AWS-managed and read-only by construction.
resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/*"]
  }
  # use_lockfile: a plan takes the lock by writing <key>.tflock, and releases it by deleting it.
  statement {
    sid       = "TakeAndReleaseLockFile"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/*.tflock"]
  }
  statement {
    sid       = "UseStateKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "state" {
  name   = "state-read-and-lock"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state.json
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}
