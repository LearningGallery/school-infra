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

variable "repositories" {
  description = "Repositories to protect, with the status check names their CI reports."
  type        = map(list(string))
  default = {
    "school-app"    = ["pr-checks / gate"]
    "school-gitops" = ["validate / kustomize"]
    "school-infra"  = ["plan / gate"]
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
    required_signatures     = true

    pull_request {
      required_approving_review_count   = 1
      require_code_owner_review         = true
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
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
