# production: NAT per AZ, Multi-AZ database, deletion protection, private API endpoint.
# A private endpoint means Terraform/Helm run from a runner inside the VPC or over VPN/Direct Connect.
account_id             = "333333333333" # placeholder: replace
azs                    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
single_nat_gateway     = false
endpoint_public_access = false
node_capacity_type     = "ON_DEMAND"
node_instance_types    = ["m6i.large"]
node_min_size          = 3
node_desired_size      = 3
node_max_size          = 9

rds_instance_class        = "db.m6g.large"
rds_multi_az              = true
rds_backup_retention_days = 14
rds_deletion_protection   = true
rds_skip_final_snapshot   = false

# Keeps ECR, STS, Secrets Manager and Logs traffic on the AWS network (about 7 USD per endpoint per AZ per month).
interface_endpoints = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs"]

# Illustrative budget: set it from your own cost expectations. Needs at least one alert_emails entry to take effect.
monthly_budget_usd = 1500
