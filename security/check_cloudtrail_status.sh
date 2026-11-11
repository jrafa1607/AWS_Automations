#!/usr/bin/env bash
# Purpose:  Checks that each account has at least one CloudTrail trail that is actually logging
#           (not only created), and whether it is multi-region and validates log files.
# Type:     Read-only
# IAM:      cloudtrail:DescribeTrails, cloudtrail:GetTrailStatus (included in SecurityAudit)
# Usage:    ./security/check_cloudtrail_status.sh
# Env:      ACCOUNTS_FILE, OUTPUT_DIR, HOME_REGION (default us-east-1)

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

HOME_REGION="${HOME_REGION:-us-east-1}"
out="$(report_file cloudtrail_status)"
csv_row account trail home_region multi_region organization_trail log_validation is_logging s3_bucket finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "CloudTrail: $account"
  trails="$(aws cloudtrail describe-trails --profile "$account" --region "$HOME_REGION" --output text \
    --query 'trailList[].[TrailARN, Name, HomeRegion, IsMultiRegionTrail, IsOrganizationTrail, LogFileValidationEnabled, S3BucketName]')"
  if [[ -z "$trails" ]]; then
    csv_row "$account" "" "" "" "" "" "" "" "NO TRAIL FOUND" >> "$out"
    continue
  fi
  while IFS=$'\t' read -r arn name home multi org validation bucket; do
    logging="$(aws cloudtrail get-trail-status --name "$arn" --profile "$account" --region "$home" \
      --output text --query IsLogging </dev/null 2>/dev/null || echo "UNKNOWN")"
    finding="OK"
    if [[ "$logging" != "True" ]]; then finding="TRAIL NOT LOGGING"
    elif [[ "$multi" != "True" ]]; then finding="SINGLE-REGION TRAIL"
    elif [[ "$validation" != "True" ]]; then finding="LOG FILE VALIDATION DISABLED"
    fi
    csv_row "$account" "$name" "$home" "$multi" "$org" "$validation" "$logging" "$bucket" "$finding"
  done <<< "$trails" >> "$out"
done

log "Report: $out"
