# Regulated-industry overlay. Same modules as production, with the settings regulated customers require
# fixed in code instead of left to tfvars. VALIDATE ONLY in this repository: never applied without a decision.
#   terraform init -backend=false && terraform validate        (what CI runs)
#   see policies/ for the plan-time checks that fail the pipeline on violations
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

  env        = "regulated"
  region     = var.region
  account_id = var.account_id
  azs        = var.azs

  # Fixed, not variables: a regulated environment must not be one tfvars typo away from public.
  endpoint_public_access = false # API server reachable only over private connectivity
  single_nat_gateway     = false # no shared failure domain; egress still goes through the controlled path
  node_capacity_type     = "ON_DEMAND"
  node_instance_types    = ["m6i.large"]
  node_min_size          = 3
  node_desired_size      = 3
  node_max_size          = 9

  # Private connectivity to AWS APIs: nothing needs the internet to talk to AWS.
  interface_endpoints = [
    "ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs",
    "ec2", "eks", "elasticloadbalancing", "autoscaling", "kms", "monitoring",
  ]

  rds_instance_class        = "db.m6g.large"
  rds_multi_az              = true
  rds_backup_retention_days = 35
  rds_deletion_protection   = true
  rds_skip_final_snapshot   = false

  admin_role_arns = var.admin_role_arns
  alert_emails    = var.alert_emails
  tags = {
    DataClassification = "student-personal-data"
    DataResidency      = join(",", var.approved_regions)
  }
}

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

  name         = "regulated"
  cluster_name = module.platform.cluster_name
  region       = var.region
  vpc_id       = module.platform.vpc_id
}

output "cluster_name" {
  value = module.platform.cluster_name
}
