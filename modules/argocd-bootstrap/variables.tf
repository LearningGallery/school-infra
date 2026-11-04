variable "name" {
  description = "Environment name."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

# Chart versions are pinned. Bump deliberately, in a reviewed pull request.
variable "chart_versions" {
  description = "Pinned Helm chart versions for the bootstrap components."
  type        = map(string)
  default = {
    aws-load-balancer-controller = "3.6.2"
    external-secrets             = "2.14.0"
    external-dns                 = "1.23.0"
    argo-cd                      = "10.11.6"
    argo-rollouts                = "2.43.8"
    kube-prometheus-stack        = "92.17.0"
  }
}

variable "dns_zone_id" {
  description = "Route 53 hosted zone ExternalDNS may write to. Empty disables ExternalDNS (no role, no release)."
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "Domain ExternalDNS is allowed to manage, for example school.example.com. Required when dns_zone_id is set."
  type        = string
  default     = ""

  validation {
    condition     = var.dns_zone_id == "" || var.dns_zone_name != ""
    error_message = "dns_zone_name is required when dns_zone_id is set."
  }
}

variable "enable_prometheus_stack" {
  description = "Install kube-prometheus-stack (Prometheus, Alertmanager, Grafana). Costs node capacity."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
