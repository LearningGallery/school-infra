# dev: cheapest. Single NAT, Spot nodes, single-AZ database, public API endpoint limited to your IP.
account_id             = "111111111111" # placeholder: replace
azs                    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
single_nat_gateway     = true
endpoint_public_access = true
public_access_cidrs    = ["203.0.113.10/32"] # documentation range: replace with your egress IP
node_capacity_type     = "SPOT"
node_instance_types    = ["t3.medium", "t3a.medium"]
node_min_size          = 2
node_desired_size      = 2
node_max_size          = 3

rds_instance_class        = "db.t4g.micro"
rds_multi_az              = false
rds_backup_retention_days = 1
rds_deletion_protection   = false
rds_skip_final_snapshot   = true
