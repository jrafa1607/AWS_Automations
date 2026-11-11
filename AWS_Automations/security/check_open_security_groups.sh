#!/usr/bin/env bash
# Purpose:  Finds inbound security group rules open to the internet (0.0.0.0/0 or ::/0)
#           on sensitive ports, or on all ports.
# Type:     Read-only
# IAM:      ec2:DescribeSecurityGroupRules (included in SecurityAudit)
# Usage:    ./security/check_open_security_groups.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR,
#           SENSITIVE_PORTS (default "22 3389 3306 5432 1433 6379 27017 9200")

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

SENSITIVE_PORTS="${SENSITIVE_PORTS:-22 3389 3306 5432 1433 6379 27017 9200}"
out="$(report_file open_security_groups)"
csv_row account region group_id rule_id protocol from_port to_port source finding > "$out"

exposed_ports() {
  local protocol="$1" from="$2" to="$3" port hits=""
  if [[ "$protocol" == "-1" ]]; then echo "ALL PORTS"; return; fi
  for port in $SENSITIVE_PORTS; do
    if [[ "$from" =~ ^-?[0-9]+$ && "$to" =~ ^-?[0-9]+$ ]] && (( from <= port && port <= to )); then
      hits="${hits:+$hits }$port"
    fi
  done
  echo "$hits"
}

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "Security groups: $account / $region"
    aws ec2 describe-security-group-rules --profile "$account" --region "$region" --output text \
      --query 'SecurityGroupRules[?IsEgress==`false` && (CidrIpv4==`0.0.0.0/0` || CidrIpv6==`::/0`)].[GroupId, SecurityGroupRuleId, IpProtocol, FromPort, ToPort, CidrIpv4 || CidrIpv6]' |
    while IFS=$'\t' read -r group rule protocol from to source; do
      [[ -n "$group" ]] || continue
      ports="$(exposed_ports "$protocol" "$from" "$to")"
      [[ -n "$ports" ]] || continue
      csv_row "$account" "$region" "$group" "$rule" "$protocol" "$from" "$to" "$source" "OPEN TO THE INTERNET: $ports"
    done >> "$out"
  done
done

log "Report: $out"
