#!/usr/bin/env bash
# Purpose:  Finds VPCs without VPC Flow Logs.
# Type:     Read-only
# IAM:      ec2:DescribeVpcs, ec2:DescribeFlowLogs (included in SecurityAudit)
# Usage:    ./security/check_vpc_flow_logs.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file vpc_flow_logs)"
csv_row account region vpc_id name is_default flow_log finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "VPC Flow Logs: $account / $region"
    with_logs=" $(aws ec2 describe-flow-logs --profile "$account" --region "$region" --output text \
      --query 'FlowLogs[?FlowLogStatus==`ACTIVE`].ResourceId' | tr '\t\n' '  ') "
    aws ec2 describe-vpcs --profile "$account" --region "$region" --output text \
      --query 'Vpcs[].[VpcId, Tags[?Key==`Name`]|[0].Value || `"None"`, IsDefault]' |
    while IFS=$'\t' read -r vpc name default; do
      [[ -n "$vpc" ]] || continue
      if [[ "$with_logs" == *" $vpc "* ]]; then
        csv_row "$account" "$region" "$vpc" "$name" "$default" "True" "OK"
      else
        csv_row "$account" "$region" "$vpc" "$name" "$default" "False" "NO ACTIVE FLOW LOG"
      fi
    done >> "$out"
  done
done

log "Report: $out"
