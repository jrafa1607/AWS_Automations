#!/usr/bin/env bash
# Purpose:  Finds EC2 instances that do not require IMDSv2 (session tokens), which helps protect
#           instance credentials against SSRF attacks.
# Type:     Read-only
# IAM:      ec2:DescribeInstances (included in SecurityAudit)
# Usage:    ./security/check_ec2_imdsv2.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file ec2_imdsv2)"
csv_row account region instance_id name state http_tokens http_endpoint finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "EC2 IMDSv2: $account / $region"
    aws ec2 describe-instances --profile "$account" --region "$region" --output text \
      --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`]|[0].Value || `"None"`, State.Name, MetadataOptions.HttpTokens, MetadataOptions.HttpEndpoint]' |
    while IFS=$'\t' read -r id name state tokens endpoint; do
      [[ -n "$id" ]] || continue
      finding="OK"
      if [[ "$endpoint" == "disabled" ]]; then
        finding="OK (metadata endpoint disabled)"
      elif [[ "$tokens" != "required" ]]; then
        finding="IMDSV2 NOT REQUIRED"
      fi
      csv_row "$account" "$region" "$id" "$name" "$state" "$tokens" "$endpoint" "$finding"
    done >> "$out"
  done
done

log "Report: $out"
