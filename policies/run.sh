#!/usr/bin/env bash
# Plan-time policy check, no AWS account needed.
#   policies/run.sh regulated     # baseline + regulated rules
#   policies/run.sh dev           # baseline rules
# It copies the code to a temp dir, adds a test-only override.tf (mock credentials, local backend), runs
# `terraform plan` (nothing can be created: there are no valid credentials) and feeds the plan JSON to Conftest.
set -euo pipefail

ENV="${1:?usage: policies/run.sh <dev|staging|regulated>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CONFTEST="openpolicyagent/conftest@sha256:0e77cdf7c1fcde035f3c579e4aaa6664ee2a8be5777eaa9af9f520cdd02280c0"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rsync -a --exclude '.terraform' --exclude '.tflint.d' --exclude 'override.tf' "$HERE/" "$WORK/"
cat > "$WORK/live/$ENV/override.tf" <<'TF'
# test-only: plan without an AWS account
provider "aws" {
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

terraform {
  backend "local" {}
}
TF

cd "$WORK/live/$ENV"
terraform init -input=false >/dev/null
AWS_EC2_METADATA_DISABLED=true terraform plan -refresh=false -input=false -lock=false -out=tfplan >/dev/null
terraform show -json tfplan > "$WORK/plan.json"

NS=(--namespace main)
[ "$ENV" = regulated ] && NS+=(--namespace regulated)

docker run --rm -v "$WORK:/work" -v "$HERE/policies/conftest:/policy:ro" -w /work "$CONFTEST" \
  test plan.json --policy /policy "${NS[@]}"
