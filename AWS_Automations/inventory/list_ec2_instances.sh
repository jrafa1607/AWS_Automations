#!/usr/bin/env bash
# Purpose:  Inventory of EC2 instances (ID, Name tag, state, AZ, private and public IPs) in every account and region.
# Type:     Read-only
# IAM:      ec2:DescribeInstances (included in ReadOnlyAccess)
# Usage:    ./inventory/list_ec2_instances.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file ec2_instances)"
csv_row account region instance_id name state availability_zone private_ip public_ip > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "EC2 instances: $account / $region"
    aws ec2 describe-instances --profile "$account" --region "$region" --output text \
      --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`]|[0].Value || 'None', State.Name, Placement.AvailabilityZone, PrivateIpAddress, PublicIpAddress]' |
    while IFS=$'\t' read -r id name state az private_ip public_ip; do
      [[ -n "$id" ]] || continue
      csv_row "$account" "$region" "$id" "$name" "$state" "$az" "$private_ip" "$public_ip"
    done >> "$out"
  done
done

log "Report: $out"
