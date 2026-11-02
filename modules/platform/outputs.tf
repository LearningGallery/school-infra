output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  value = module.eks.cluster_ca_data
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "rds_address" {
  value = module.rds.address
}

output "app_secret_name" {
  value = module.secrets.app_secret_name
}

output "alert_topic_arn" {
  value = module.observability.alert_topic_arn
}
