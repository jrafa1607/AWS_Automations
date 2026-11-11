#!/usr/bin/env bash
# Purpose:  Lists CloudFormation stacks stuck in failed states (rollback or delete failures).
# Type:     Read-only
# IAM:      cloudformation:ListStacks (included in ReadOnlyAccess)
# Usage:    ./inventory/list_stacks_failed_states.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

FAILED_STATES="UPDATE_ROLLBACK_FAILED ROLLBACK_FAILED DELETE_FAILED"
out="$(report_file stacks_failed_states)"
csv_row account region stack_name status last_updated status_reason > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "CloudFormation: $account / $region"
    # shellcheck disable=SC2086  # FAILED_STATES must be split into separate arguments
    aws cloudformation list-stacks --profile "$account" --region "$region" --output text \
      --stack-status-filter $FAILED_STATES \
      --query 'StackSummaries[].[StackName, StackStatus, LastUpdatedTime || CreationTime, StackStatusReason]' |
    while IFS=$'\t' read -r name status updated reason; do
      [[ -n "$name" ]] || continue
      csv_row "$account" "$region" "$name" "$status" "$updated" "$reason"
    done >> "$out"
  done
done

log "Report: $out"
