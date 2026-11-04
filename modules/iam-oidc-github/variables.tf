variable "github_org" {
  description = "GitHub organisation or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository whose workflows may assume the roles."
  type        = string
}

variable "github_subject_prefix" {
  description = "Exact `sub` prefix GitHub sends for this repository, for repositories with immutable subjects, for example repo:OWNER@OWNER_ID/REPO@REPO_ID. Empty uses repo:github_org/github_repo. Read it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub"
  type        = string
  default     = ""

  validation {
    condition     = var.github_subject_prefix == "" || (startswith(var.github_subject_prefix, "repo:") && !strcontains(var.github_subject_prefix, "*") && !strcontains(var.github_subject_prefix, "?"))
    error_message = "github_subject_prefix must start with repo: and contain no wildcards."
  }
}

variable "release_branch" {
  description = "Branch the release workflow runs on. The release role trusts only this ref."
  type        = string
  default     = "main"
}

variable "pull_environments" {
  description = "GitHub Environments allowed to assume the read-only pull role."
  type        = list(string)
  default     = ["dev", "staging"]
}

variable "ecr_repository_arns" {
  description = "ECR repositories the roles may use. Never use a wildcard."
  type        = list(string)

  validation {
    condition     = length(var.ecr_repository_arns) > 0 && alltrue([for a in var.ecr_repository_arns : !strcontains(a, "*")])
    error_message = "List specific repository ARNs; wildcards defeat least privilege."
  }
}

variable "create_oidc_provider" {
  description = "Create the account's GitHub OIDC provider. Set false if it already exists."
  type        = bool
  default     = true
}

variable "existing_provider_arn" {
  description = "ARN of an existing GitHub OIDC provider when create_oidc_provider is false."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Prefix for role names."
  type        = string
  default     = "school"
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
