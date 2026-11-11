#!/usr/bin/env bash
# Purpose:  Finds which network interface (and instance, security groups, account, region) owns a private IP.
#           Useful during incident response or when a firewall log shows only an IP.
# Type:     Read-only
# IAM:      ec2:DescribeNetworkInterfaces (included in ReadOnlyAccess)
# Usage:    ./inventory/find_eni_by_private_ip.sh 10.20.30.40
# Env:      ACCOUNTS_FILE, REGIONS

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws

ip="${1:-}"
[[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "Usage: $0 <private-ipv4-address>"
load_accounts

found=false
for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    result="$(aws ec2 describe-network-interfaces --profile "$account" --region "$region" --output text \
      --filters "Name=addresses.private-ip-address,Values=$ip" \
      --query 'NetworkInterfaces[].[NetworkInterfaceId, Attachment.InstanceId, VpcId, SubnetId, join(`,`, Groups[].GroupId), Description]')"
    if [[ -n "$result" ]]; then
      found=true
      while IFS=$'\t' read -r eni instance vpc subnet groups description; do
        printf 'account=%s region=%s eni=%s instance=%s vpc=%s subnet=%s security_groups=%s description="%s"\n' \
          "$account" "$region" "$eni" "$instance" "$vpc" "$subnet" "$groups" "$description"
      done <<< "$result"
    fi
  done
done

[[ "$found" == true ]] || log "No network interface found with private IP $ip"
