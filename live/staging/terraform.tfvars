# staging: production-like shape at lower scale. On-demand nodes, single-AZ database.
account_id             = "222222222222" # placeholder: replace
azs                    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
single_nat_gateway     = true
endpoint_public_access = true
public_access_cidrs    = ["203.0.113.10/32"]
node_capacity_type     = "ON_DEMAND"
node_instance_types    = ["t3.large"]
node_min_size          = 2
node_desired_size      = 2
node_max_size          = 4

rds_instance_class        = "db.t4g.small"
rds_multi_az              = false
rds_backup_retention_days = 7
rds_deletion_protection   = false
rds_skip_final_snapshot   = true
