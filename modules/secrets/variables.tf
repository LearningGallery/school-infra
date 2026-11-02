variable "name" {
  description = "Environment name; secrets are stored under school/<name>/..."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "kms_key_arn" {
  description = "Key used to encrypt the application secret and decrypted by External Secrets."
  type        = string
}

variable "extra_secret_arns" {
  description = "Other secrets External Secrets may read, for example the RDS-managed master secret."
  type        = list(string)
  default     = []
}

variable "extra_kms_key_arns" {
  description = "Keys protecting extra_secret_arns."
  type        = list(string)
  default     = []
}

variable "eso_namespace" {
  type    = string
  default = "external-secrets"
}

variable "eso_service_account" {
  type    = string
  default = "external-secrets"
}

variable "tags" {
  type    = map(string)
  default = {}
}
