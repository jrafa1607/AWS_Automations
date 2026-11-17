#!/usr/bin/env bash
# Purpose:  Finds VPCs without an active VPC-level flow log.
# Type:     Read-only
# IAM:      ec2:DescribeVpcs, ec2:DescribeFlowLogs (included in SecurityAudit)
# Usage:    ./security/check_vpc_flow_logs.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR
# Note:     Flow logs created only on subnets or network interfaces are not counted as VPC coverage.

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
    if ! flow_logs="$(aws_try ec2 describe-flow-logs --profile "$account" --region "$region" --output text \
          --query 'FlowLogs[?FlowLogStatus==`ACTIVE`].ResourceId')" ||
       ! vpcs="$(aws_try ec2 describe-vpcs --profile "$account" --region "$region" --output text \
          --query 'Vpcs[].[VpcId, Tags[?Key==`Name`]|[0].Value || `"None"`, IsDefault]')"; then
      csv_row "$account" "$region" "" "" "" "" "ERROR: $(last_error)" >> "$out"
      continue
    fi
    with_logs=" $(printf '%s' "$flow_logs" | tr '\t\n' '  ') "
    while IFS=$'\t' read -r vpc name default; do
      [[ -n "$vpc" ]] || continue
      if [[ "$with_logs" == *" $vpc "* ]]; then
        csv_row "$account" "$region" "$vpc" "$name" "$default" "True" "OK"
      else
        csv_row "$account" "$region" "$vpc" "$name" "$default" "False" "NO ACTIVE FLOW LOG"
      fi
    done <<< "$vpcs" >> "$out"
  done
done

log "Report: $out"
