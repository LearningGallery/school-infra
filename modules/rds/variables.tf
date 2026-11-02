variable "name" {
  type = string
}

variable "account_id" {
  description = "AWS account ID, used in the KMS key policy."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Data-tier subnets (no internet route)."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach PostgreSQL (the EKS node/cluster security group)."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL major version. Check RDS for currently supported minor versions."
  type        = string
  default     = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Synchronous standby in a second AZ. Production true; labs false to halve the cost."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "true only for disposable labs."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer-managed key. null creates one."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
