variable "repository_names" {
  description = "ECR repositories to create."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for image encryption. null uses AWS-owned AES256."
  type        = string
  default     = null
}

variable "keep_images" {
  description = "How many images to keep per repository."
  type        = number
  default     = 30
}

variable "untagged_expiry_days" {
  description = "Days before untagged images are expired."
  type        = number
  default     = 7
}

variable "enhanced_scanning" {
  description = "Enable registry-wide Amazon Inspector continuous scanning (extra cost)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every repository."
  type        = map(string)
  default     = {}
}
