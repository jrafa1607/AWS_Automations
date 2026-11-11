#!/usr/bin/env bash
# Purpose:  Checks whether AWS Security Hub is enabled in every account and region, and which standards are enabled.
# Type:     Read-only
# IAM:      securityhub:DescribeHub, securityhub:GetEnabledStandards (included in SecurityAudit)
# Usage:    ./security/check_security_hub_status.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file security_hub_status)"
csv_row account region hub_enabled enabled_standards finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "Security Hub: $account / $region"
    if ! aws securityhub describe-hub --profile "$account" --region "$region" --output text --query HubArn >/dev/null 2>&1; then
      csv_row "$account" "$region" "False" "" "SECURITY HUB NOT ENABLED" >> "$out"
      continue
    fi
    standards="$(aws securityhub get-enabled-standards --profile "$account" --region "$region" --output text \
      --query 'StandardsSubscriptions[?StandardsStatus==`READY`].StandardsArn' 2>/dev/null || true)"
    names=""
    for arn in $standards; do
      name="${arn#*standards/}"
      name="${name#*ruleset/}"
      names="${names:+$names; }$name"
    done
    finding="OK"
    [[ -n "$names" ]] || finding="NO STANDARD ENABLED"
    csv_row "$account" "$region" "True" "$names" "$finding" >> "$out"
  done
done

log "Report: $out"
