# Wires ECR and the GitHub OIDC roles together. Validate-only in the learning repo:
# nothing here is applied without an explicit decision (see docs, module 07 cost note).
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Remote state (S3 with locking) is introduced in module 30; this example uses local state.
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "github_org" {
  type    = string
  default = "example-org" # placeholder: replace with your organisation
}

variable "github_repo" {
  type    = string
  default = "school-app"
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["school-backend", "school-frontend"]
  tags             = { project = "devops-zero-to-hero" }
}

module "github_oidc" {
  source              = "../../modules/iam-oidc-github"
  github_org          = var.github_org
  github_repo         = var.github_repo
  ecr_repository_arns = values(module.ecr.repository_arns)
  tags                = { project = "devops-zero-to-hero" }
}

output "release_role_arn" {
  value = module.github_oidc.release_role_arn
}

output "pull_role_arn" {
  value = module.github_oidc.pull_role_arn
}

output "repository_urls" {
  value = module.ecr.repository_urls
}
