resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name = each.value

  # Tags are names, not proof. Immutability stops a tag being repointed at different content;
  # deployments still reference the digest.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = var.kms_key_arn == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.keep_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_images
        }
        action = { type = "expire" }
      },
    ]
  })
}

# Registry-wide (one per account and region). Enhanced scanning = Amazon Inspector continuous scanning.
resource "aws_inspector2_enabler" "ecr" {
  count          = var.enhanced_scanning ? 1 : 0
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR"]
}

resource "aws_ecr_registry_scanning_configuration" "this" {
  count     = var.enhanced_scanning ? 1 : 0
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "school-*"
      filter_type = "WILDCARD"
    }
  }

  depends_on = [aws_inspector2_enabler.ecr]
}

data "aws_caller_identity" "current" {}
