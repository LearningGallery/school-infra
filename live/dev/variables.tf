variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "account_id" {
  description = "AWS account ID for this environment."
  type        = string
}

variable "azs" {
  type = list(string)
}

variable "single_nat_gateway" {
  type = bool
}

variable "endpoint_public_access" {
  type = bool
}

variable "public_access_cidrs" {
  type    = list(string)
  default = []
}

variable "viewer_role_arns" {
  description = "Principals with read-only access to the cluster's Kubernetes resources, e.g. an SSO role for the console view."
  type        = list(string)
  default     = []
}

variable "admin_role_arns" {
  type    = list(string)
  default = []
}

variable "node_capacity_type" {
  type = string
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "rds_instance_class" {
  type = string
}

variable "rds_multi_az" {
  type = bool
}

variable "rds_backup_retention_days" {
  type = number
}

variable "rds_deletion_protection" {
  type = bool
}

variable "rds_skip_final_snapshot" {
  type = bool
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

variable "interface_endpoints" {
  description = "Private interface endpoints for AWS APIs. Each costs about 7 USD/month per AZ, so labs leave this empty and rely on NAT."
  type        = list(string)
  default     = []
}

variable "anomaly_monitor_arn" {
  description = "Existing account-level anomaly monitor to reuse (AWS allows one per account). Empty creates one."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for this environment in USD (0 disables). Budgets alert, they do not stop spend."
  type        = number
  default     = 0
}
