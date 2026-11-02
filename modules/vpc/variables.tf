variable "name" {
  description = "Name prefix, usually the environment (dev, staging, production)."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR. /16 leaves room for three tiers across three AZs."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Exactly three availability zone names."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 3
    error_message = "Use exactly three availability zones."
  }
}

variable "account_id" {
  description = "AWS account ID, used in the flow-log key policy."
  type        = string
}

variable "region" {
  description = "Region, used to name VPC endpoint services."
  type        = string
}

variable "single_nat_gateway" {
  description = "One NAT gateway for all AZs (cheap, a single point of failure) or one per AZ."
  type        = bool
  default     = true
}

variable "interface_endpoints" {
  description = "AWS services reached privately through interface endpoints. Keeps ECR, STS and Secrets Manager traffic off the NAT gateway and off the internet."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs"]
}

variable "flow_logs_retention_days" {
  description = "Retention for VPC flow logs."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
