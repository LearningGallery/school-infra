variable "name" {
  description = "Environment name, used in resource names."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD for this environment. 0 disables the budget."
  type        = number
  default     = 0
}

variable "alert_emails" {
  description = "Addresses notified when spend is forecast to exceed, or exceeds, the budget."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
