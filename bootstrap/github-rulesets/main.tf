# Branch protection as code (module 03). Applying needs a GitHub token with repository administration
# rights: treat it as a high-privilege credential and run it from a protected workflow or a laptop SSO session.
terraform {
  required_version = ">= 1.10"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

variable "owner" {
  description = "GitHub organisation or user."
  type        = string
  default     = "example-org" # placeholder
}

# Review strictness. The defaults suit a single-maintainer repository, where nobody else can approve
# (a PR author cannot approve their own PR, so 1 required approval would block every merge). With two or
# more maintainers, turn these on: approvals = 1, code owner review, last-push approval and signatures.
variable "required_approvals" {
  type    = number
  default = 0
}

variable "require_code_owner_review" {
  type    = bool
  default = false
}

variable "require_last_push_approval" {
  type    = bool
  default = false
}

variable "require_signatures" {
  description = "Require signed commits (every contributor needs commit signing set up)."
  type        = bool
  default     = false
}

variable "repositories" {
  description = "Repositories to protect, with the status check names their CI reports. GitHub reports a job's name, not workflow / job: each repository's CI ends in a job named gate."
  type        = map(list(string))
  default = {
    "school-app"    = ["gate"]
    "school-gitops" = ["gate"]
    "school-infra"  = ["gate"]
  }
}

provider "github" {
  owner = var.owner # token from the GITHUB_TOKEN environment variable
}

resource "github_repository_ruleset" "main" {
  for_each    = var.repositories
  name        = "protect-main"
  repository  = each.key
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # No bypass actors: emergencies use the documented break-glass process, not a quiet override.
  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true
    required_signatures     = var.require_signatures

    pull_request {
      required_approving_review_count   = var.required_approvals
      require_code_owner_review         = var.require_code_owner_review
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = var.require_last_push_approval
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true
      dynamic "required_check" {
        for_each = each.value
        content {
          context = required_check.value
        }
      }
    }
  }
}
