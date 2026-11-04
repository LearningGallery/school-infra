variable "env" {
  description = "Environment name: dev, staging, production, regulated."
  type        = string
}

variable "region" {
  type = string
}

variable "account_id" {
  description = "AWS account ID of this environment (one account per environment in real customers)."
  type        = string
}

variable "azs" {
  description = "Three availability zones in var.region."
  type        = list(string)
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "endpoint_public_access" {
  type    = bool
  default = false
}

variable "public_access_cidrs" {
  type    = list(string)
  default = []
}

variable "viewer_role_arns" {
  description = "Principals with read-only access to the cluster's Kubernetes resources (EKS AdminView policy)."
  type        = list(string)
  default     = []
}

variable "admin_role_arns" {
  description = "IAM roles with cluster-admin (SSO permission set role, break-glass role)."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "rds_backup_retention_days" {
  type    = number
  default = 7
}

variable "rds_deletion_protection" {
  type    = bool
  default = false
}

variable "rds_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "interface_endpoints" {
  description = "Interface endpoints to create. Each is billed per AZ per hour; empty relies on NAT."
  type        = list(string)
  default     = []
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "anomaly_monitor_arn" {
  description = "Existing account-level anomaly monitor to reuse (AWS allows one per account). Empty creates one."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for this environment in USD. 0 disables budget alerts."
  type        = number
  default     = 0
}
