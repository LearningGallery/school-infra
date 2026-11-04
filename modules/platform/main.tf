# One environment's AWS infrastructure: network, cluster, database, secrets, alerting.
# The Helm-installed platform controllers are a separate step (modules/argocd-bootstrap) because the
# Helm provider can only be configured once the cluster exists.
locals {
  tags = merge(var.tags, {
    Environment = var.env
    Project     = "devops-zero-to-hero"
    ManagedBy   = "terraform"
  })
}

module "vpc" {
  source = "../vpc"

  name                = var.env
  account_id          = var.account_id
  cidr                = var.vpc_cidr
  azs                 = var.azs
  region              = var.region
  single_nat_gateway  = var.single_nat_gateway
  interface_endpoints = var.interface_endpoints
  tags                = local.tags
}

module "eks" {
  source = "../eks"

  name                   = "school-${var.env}"
  region                 = var.region
  account_id             = var.account_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  admin_role_arns        = var.admin_role_arns
  viewer_role_arns       = var.viewer_role_arns
  node_instance_types    = var.node_instance_types
  node_capacity_type     = var.node_capacity_type
  node_min_size          = var.node_min_size
  node_desired_size      = var.node_desired_size
  node_max_size          = var.node_max_size
  tags                   = local.tags
}

module "rds" {
  source = "../rds"

  name                       = var.env
  account_id                 = var.account_id
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.data_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  instance_class             = var.rds_instance_class
  multi_az                   = var.rds_multi_az
  backup_retention_days      = var.rds_backup_retention_days
  deletion_protection        = var.rds_deletion_protection
  skip_final_snapshot        = var.rds_skip_final_snapshot
  tags                       = local.tags
}

module "secrets" {
  source = "../secrets"

  name              = var.env
  cluster_name      = module.eks.cluster_name
  kms_key_arn       = module.rds.kms_key_arn
  extra_secret_arns = [module.rds.master_user_secret_arn]
  tags              = local.tags
}

module "observability" {
  source = "../observability"

  name           = var.env
  region         = var.region
  account_id     = var.account_id
  rds_identifier = module.rds.identifier
  alert_emails   = var.alert_emails
  tags           = local.tags
}

module "governance" {
  source = "../governance"

  name                = var.env
  monthly_budget_usd  = var.monthly_budget_usd
  alert_emails        = var.alert_emails
  anomaly_monitor_arn = var.anomaly_monitor_arn
  tags                = local.tags
}
