variable "approved_regions" {
  description = "Regions where this workload and its data may run. Enforced here by validation and in AWS by the region-deny SCP (scp.tf)."
  type        = list(string)
  default     = ["eu-west-1", "eu-central-1"]
}

variable "region" {
  description = "Primary region. Data residency: no data store, backup or replica may leave var.approved_regions."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = contains(var.approved_regions, var.region)
    error_message = "region must be one of approved_regions (data residency)."
  }
}

variable "account_id" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "admin_role_arns" {
  description = "SSO-backed roles only. Break-glass access is a separate, approved, session-recorded role (module 35)."
  type        = list(string)
  default     = []
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

variable "github_config_url" {
  description = "GitHub organisation or repository URL the ephemeral runners register to."
  type        = string
  default     = "https://github.com/<YOUR_ORG>/school-app"
}

variable "runner_secret_name" {
  description = "Kubernetes Secret (created out of band, never in Terraform) holding the GitHub App credentials."
  type        = string
  default     = "github-runner-app"
}

variable "manage_scp" {
  description = "Create the region-deny SCP. Run from the organisation management account only."
  type        = bool
  default     = false
}

variable "scp_target_id" {
  description = "Organisational unit or account the SCP attaches to."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for this environment in USD (0 disables). Budgets alert, they do not stop spend."
  type        = number
  default     = 0
}
