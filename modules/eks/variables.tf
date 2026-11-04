variable "name" {
  description = "Cluster name."
  type        = string
}

variable "region" {
  description = "Region, used to name the CloudWatch Logs service principal in the key policy."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used in the KMS key policy."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets for the control plane ENIs and the nodes."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. Check the versions EKS currently supports before applying."
  type        = string
  default     = "1.33"
}

variable "endpoint_public_access" {
  description = "Expose the API server publicly (restricted by public_access_cidrs). Regulated environments set false and use private connectivity."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach a public API endpoint."
  type        = list(string)
  default     = []
}

variable "admin_role_arns" {
  description = "IAM roles granted cluster-admin through EKS access entries (humans via SSO, break-glass)."
  type        = list(string)
  default     = []
}

variable "viewer_role_arns" {
  description = "IAM principals granted read-only access to every Kubernetes resource (AmazonEKSAdminViewPolicy), for example people who only need the console view. For an SSO role use the FULL ARN including the aws-reserved/sso.amazonaws.com/<region>/ path (EKS access entries reject the path-less form). Note this includes reading Secrets."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND for baseline nodes, SPOT for non-production."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
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

variable "kms_key_arn" {
  description = "Customer-managed key for Kubernetes secrets and node volumes. null creates one."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "One year satisfies common log-retention expectations; lower it in disposable labs."
  type        = number
  default     = 365
}

variable "tags" {
  type    = map(string)
  default = {}
}
