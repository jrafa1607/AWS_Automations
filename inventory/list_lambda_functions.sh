#!/usr/bin/env bash
# Purpose:  Inventory of Lambda functions with runtime and last change, to spot deprecated runtimes.
# Type:     Read-only
# IAM:      lambda:ListFunctions (included in ReadOnlyAccess)
# Usage:    ./inventory/list_lambda_functions.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file lambda_functions)"
csv_row account region function_name runtime last_modified function_arn > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "Lambda functions: $account / $region"
    aws lambda list-functions --profile "$account" --region "$region" --output text \
      --query 'Functions[].[FunctionName, Runtime, LastModified, FunctionArn]' |
    while IFS=$'\t' read -r name runtime modified arn; do
      [[ -n "$name" ]] || continue
      csv_row "$account" "$region" "$name" "$runtime" "$modified" "$arn"
    done >> "$out"
  done
done

log "Report: $out"
