package regulated_test

import data.regulated
import rego.v1

base := {"variables": {"region": {"value": "eu-west-1"}, "approved_regions": {"value": ["eu-west-1", "eu-central-1"]}}}

test_unapproved_region_denied if {
	input_bad := {"variables": {"region": {"value": "us-east-1"}, "approved_regions": {"value": ["eu-west-1"]}}, "resource_changes": []}
	some msg in regulated.deny with input as input_bad
	contains(msg, "not in approved_regions")
}

test_public_eks_denied if {
	r := {"address": "aws_eks_cluster.x", "type": "aws_eks_cluster", "change": {"after": {"vpc_config": [{"endpoint_public_access": true}]}}}
	some msg in regulated.deny with input as object.union(base, {"resource_changes": [r]})
	contains(msg, "public API endpoint")
}

test_single_az_db_denied if {
	r := {"address": "aws_db_instance.x", "type": "aws_db_instance", "change": {"after": {"multi_az": false, "deletion_protection": true, "backup_retention_period": 35, "kms_key_id": "k"}}}
	some msg in regulated.deny with input as object.union(base, {"resource_changes": [r]})
	contains(msg, "Multi-AZ")
}
