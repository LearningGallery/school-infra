variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "rds_identifier" {
  description = "RDS instance to alarm on."
  type        = string
}

variable "alert_emails" {
  description = "Addresses subscribed to the alert topic (each must confirm the subscription)."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "tags" {
  type    = map(string)
  default = {}
}
