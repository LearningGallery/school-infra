# Extra rules for the regulated overlay (run with: conftest test --namespace main --namespace regulated).
package regulated

import rego.v1

live contains r if {
	some r in input.resource_changes
	r.change.after != null
}

# Data residency: the region and every region-qualified service name must be approved.
deny contains msg if {
	not input.variables.region.value in input.variables.approved_regions.value
	msg := sprintf("region %q is not in approved_regions %v", [input.variables.region.value, input.variables.approved_regions.value])
}

deny contains msg if {
	some r in live
	r.type == "aws_vpc_endpoint"
	region := input.variables.region.value
	not startswith(r.change.after.service_name, sprintf("com.amazonaws.%s.", [region]))
	msg := sprintf("%s: endpoint service %q is outside region %q", [r.address, r.change.after.service_name, region])
}

# Private-only connectivity: no public Kubernetes API endpoint.
deny contains msg if {
	some r in live
	r.type == "aws_eks_cluster"
	some v in r.change.after.vpc_config
	v.endpoint_public_access
	msg := sprintf("%s: public API endpoint is not allowed in the regulated variant", [r.address])
}

# Resilience and evidence retention.
deny contains msg if {
	some r in live
	r.type == "aws_db_instance"
	not r.change.after.multi_az
	msg := sprintf("%s: Multi-AZ is required", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_db_instance"
	not r.change.after.deletion_protection
	msg := sprintf("%s: deletion protection is required", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_db_instance"
	r.change.after.backup_retention_period < 35
	msg := sprintf("%s: backup retention must be at least 35 days", [r.address])
}

# Customer-managed keys everywhere: the database must name a key (known now or after apply).
deny contains msg if {
	some r in live
	r.type == "aws_db_instance"
	not has_key(r)
	msg := sprintf("%s: a customer-managed KMS key is required", [r.address])
}

has_key(r) if r.change.after.kms_key_id != null

has_key(r) if r.change.after_unknown.kms_key_id == true

# Network visibility.
deny contains msg if {
	count([r | some r in live; r.type == "aws_flow_log"]) == 0
	msg := "VPC flow logs are required"
}

deny contains msg if {
	count([r | some r in live; r.type == "aws_vpc_endpoint"; r.change.after.vpc_endpoint_type == "Interface"]) < 5
	msg := "interface VPC endpoints for AWS APIs are required (private connectivity)"
}
