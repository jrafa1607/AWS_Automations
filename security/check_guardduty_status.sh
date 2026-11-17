#!/usr/bin/env bash
# Purpose:  Checks whether Amazon GuardDuty is enabled in every account and region.
# Type:     Read-only
# IAM:      guardduty:ListDetectors, guardduty:GetDetector (included in SecurityAudit)
# Usage:    ./security/check_guardduty_status.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file guardduty_status)"
csv_row account region detector_id status finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "GuardDuty: $account / $region"
    if ! detector="$(aws_try guardduty list-detectors --profile "$account" --region "$region" --output text --query 'DetectorIds[0]')"; then
      csv_row "$account" "$region" "" "" "ERROR: $(last_error)" >> "$out"
      continue
    fi
    if [[ -z "$detector" || "$detector" == "None" ]]; then
      csv_row "$account" "$region" "" "" "GUARDDUTY NOT ENABLED" >> "$out"
      continue
    fi
    if ! status="$(aws_try guardduty get-detector --detector-id "$detector" --profile "$account" --region "$region" --output text --query Status)"; then
      csv_row "$account" "$region" "$detector" "" "ERROR: $(last_error)" >> "$out"
      continue
    fi
    finding="OK"
    [[ "$status" == "ENABLED" ]] || finding="DETECTOR NOT ENABLED"
    csv_row "$account" "$region" "$detector" "$status" "$finding" >> "$out"
  done
done

log "Report: $out"
