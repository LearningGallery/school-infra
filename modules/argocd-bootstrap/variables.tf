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
    argo-cd                      = "10.11.6"
    argo-rollouts                = "2.43.8"
    kube-prometheus-stack        = "92.17.0"
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
