# staging: root module with its own state. Everything reusable lives in ../../modules.
# Backend settings are supplied at init time so the same code works per account:
#   terraform init -backend-config=backend.hcl        (see backend.hcl.example)
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

module "platform" {
  source = "../../modules/platform"

  env                       = "staging"
  region                    = var.region
  account_id                = var.account_id
  azs                       = var.azs
  single_nat_gateway        = var.single_nat_gateway
  endpoint_public_access    = var.endpoint_public_access
  public_access_cidrs       = var.public_access_cidrs
  admin_role_arns           = var.admin_role_arns
  node_capacity_type        = var.node_capacity_type
  node_instance_types       = var.node_instance_types
  node_min_size             = var.node_min_size
  node_desired_size         = var.node_desired_size
  node_max_size             = var.node_max_size
  rds_instance_class        = var.rds_instance_class
  rds_multi_az              = var.rds_multi_az
  rds_backup_retention_days = var.rds_backup_retention_days
  rds_deletion_protection   = var.rds_deletion_protection
  rds_skip_final_snapshot   = var.rds_skip_final_snapshot
  alert_emails              = var.alert_emails
  monthly_budget_usd        = var.monthly_budget_usd
  interface_endpoints       = var.interface_endpoints
}

# The Helm provider needs the cluster, so it is configured from the platform module's outputs.
# A private endpoint (production) means this step must run from inside the network (module 04, 35).
provider "helm" {
  kubernetes = {
    host                   = module.platform.cluster_endpoint
    cluster_ca_certificate = base64decode(module.platform.cluster_ca_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.platform.cluster_name, "--region", var.region]
    }
  }
}

module "bootstrap" {
  source = "../../modules/argocd-bootstrap"

  name         = "staging"
  cluster_name = module.platform.cluster_name
  region       = var.region
  vpc_id       = module.platform.vpc_id
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "rds_address" {
  value = module.platform.rds_address
}

output "app_secret_name" {
  value = module.platform.app_secret_name
}
