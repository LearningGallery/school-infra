package main_test

import data.main
import rego.v1

good_db := {"address": "aws_db_instance.ok", "type": "aws_db_instance", "change": {"after": {"storage_encrypted": true, "publicly_accessible": false, "tags": {"Environment": "x", "Project": "y"}}}}

bad_db := {"address": "aws_db_instance.bad", "type": "aws_db_instance", "change": {"after": {"storage_encrypted": false, "publicly_accessible": true, "tags": {}}}}

test_good_db_passes if {
	count(main.deny) == 0 with input as {"resource_changes": [good_db]}
}

test_unencrypted_public_untagged_db_denied if {
	denied := main.deny with input as {"resource_changes": [bad_db]}
	count(denied) == 4 # encrypted, public, tag Environment, tag Project
}

test_mutable_ecr_denied if {
	r := {"address": "aws_ecr_repository.x", "type": "aws_ecr_repository", "change": {"after": {"image_tag_mutability": "MUTABLE", "tags": {"Environment": "x", "Project": "y"}}}}
	count(main.deny) == 1 with input as {"resource_changes": [r]}
}

test_imdsv1_denied if {
	r := {"address": "aws_launch_template.x", "type": "aws_launch_template", "change": {"after": {"metadata_options": [{"http_tokens": "optional"}], "block_device_mappings": []}}}
	count(main.deny) == 1 with input as {"resource_changes": [r]}
}
