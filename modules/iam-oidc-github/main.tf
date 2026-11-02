locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_provider_arn
  repo         = "${var.github_org}/${var.github_repo}"
  oidc_host    = "token.actions.githubusercontent.com"
}

# One per AWS account. AWS validates the token signature against GitHub's published keys.
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

# ---- release role: assumable only by the release workflow on the release branch ----
data "aws_iam_policy_document" "release_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Repo AND branch claim. A fork, another repo or a feature branch gets AccessDenied.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${local.repo}:ref:refs/heads/${var.release_branch}"]
    }
  }
}

resource "aws_iam_role" "release" {
  name                 = "${var.name_prefix}-release"
  assume_role_policy   = data.aws_iam_policy_document.release_trust.json
  max_session_duration = 3600
  tags                 = var.tags
}

data "aws_iam_policy_document" "release_permissions" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level scoping
  }
  statement {
    sid = "PushToSchoolRepositoriesOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "release" {
  name   = "ecr-push"
  role   = aws_iam_role.release.id
  policy = data.aws_iam_policy_document.release_permissions.json
}

# ---- pull role: read-only, bound to GitHub Environments so approvals gate it ----
data "aws_iam_policy_document" "pull_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [for e in var.pull_environments : "repo:${local.repo}:environment:${e}"]
    }
  }
}

resource "aws_iam_role" "pull" {
  name                 = "${var.name_prefix}-pull"
  assume_role_policy   = data.aws_iam_policy_document.pull_trust.json
  max_session_duration = 3600
  tags                 = var.tags
}

data "aws_iam_policy_document" "pull_permissions" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "ReadSchoolRepositoriesOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "pull" {
  name   = "ecr-read"
  role   = aws_iam_role.pull.id
  policy = data.aws_iam_policy_document.pull_permissions.json
}
