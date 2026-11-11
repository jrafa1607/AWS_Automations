#!/usr/bin/env bash
# Purpose:  Inventory of Route 53 hosted zones and their records (including alias targets).
# Type:     Read-only
# IAM:      route53:ListHostedZones, route53:ListResourceRecordSets (included in ReadOnlyAccess)
# Usage:    ./inventory/list_route53_records.sh
# Env:      ACCOUNTS_FILE, OUTPUT_DIR (Route 53 is a global service)
# Note:     Empty fields are printed as None so tab-separated parsing keeps the columns aligned.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file route53_records)"
csv_row account zone_id zone_name private_zone record_name type ttl values alias_target > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "Route 53: $account"
  zones="$(aws route53 list-hosted-zones --profile "$account" --output text \
    --query 'HostedZones[].[Id, Name, Config.PrivateZone]')"
  if [[ -z "$zones" ]]; then
    log "  $account has no hosted zone"
    continue
  fi
  while IFS=$'\t' read -r zone_id zone_name private_zone; do
    [[ -n "$zone_id" ]] || continue
    aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --profile "$account" --output text \
      --query 'ResourceRecordSets[].[Name, Type, TTL, join(` `, ResourceRecords[].Value || `[]`) || 'None', AliasTarget.DNSName]' </dev/null |
    while IFS=$'\t' read -r name type ttl values alias; do
      csv_row "$account" "$zone_id" "$zone_name" "$private_zone" "$name" "$type" "$ttl" "$values" "$alias"
    done >> "$out"
  done <<< "$zones"
done

log "Report: $out"
