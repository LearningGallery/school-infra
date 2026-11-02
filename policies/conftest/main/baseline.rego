# Plan-time guardrails for EVERY environment. Input: `terraform show -json tfplan`.
# A deny fails the pipeline before anything is applied (infra CI, module 34).
package main

import rego.v1

# Resources that will exist after apply (ignores pure deletes).
live contains r if {
	some r in input.resource_changes
	r.change.after != null
}

required_tags := {"Environment", "Project"}

taggable := {"aws_db_instance", "aws_eks_cluster", "aws_vpc", "aws_kms_key", "aws_ecr_repository"}

deny contains msg if {
	some r in live
	r.type == "aws_db_instance"
	not r.change.after.storage_encrypted
	msg := sprintf("%s: storage must be encrypted at rest", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_db_instance"
	r.change.after.publicly_accessible
	msg := sprintf("%s: database must not be publicly accessible", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_launch_template"
	some m in r.change.after.metadata_options
	m.http_tokens != "required"
	msg := sprintf("%s: IMDSv2 is mandatory (http_tokens = required)", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_launch_template"
	some b in r.change.after.block_device_mappings
	some e in b.ebs
	not e.encrypted
	msg := sprintf("%s: EBS volumes must be encrypted", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_ecr_repository"
	r.change.after.image_tag_mutability != "IMMUTABLE"
	msg := sprintf("%s: ECR tags must be immutable", [r.address])
}

deny contains msg if {
	some r in live
	r.type == "aws_kms_key"
	not r.change.after.enable_key_rotation
	msg := sprintf("%s: KMS key rotation must be enabled", [r.address])
}

deny contains msg if {
	some r in live
	r.type in taggable
	some tag in required_tags
	not r.change.after.tags[tag]
	msg := sprintf("%s: missing required tag %q", [r.address, tag])
}

deny contains msg if {
	some r in live
	r.type == "aws_s3_bucket_public_access_block"
	some setting in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	not r.change.after[setting]
	msg := sprintf("%s: %s must be true (no public buckets)", [r.address, setting])
}
