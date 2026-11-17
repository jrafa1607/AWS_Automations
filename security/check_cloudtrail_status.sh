#!/usr/bin/env bash
# Purpose:  Checks that each account has at least one CloudTrail trail that is actually logging
#           (not only created), and whether it is multi-region, validates log files, is encrypted
#           with KMS, and sends events to CloudWatch Logs.
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
csv_row account trail home_region multi_region organization_trail log_validation kms_encrypted cloudwatch_logs is_logging s3_bucket finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "CloudTrail: $account"
  if ! trails="$(aws_try cloudtrail describe-trails --profile "$account" --region "$HOME_REGION" --output text \
      --query 'trailList[].[TrailARN, Name, HomeRegion, IsMultiRegionTrail, IsOrganizationTrail, LogFileValidationEnabled, KmsKeyId || `"None"`, CloudWatchLogsLogGroupArn || `"None"`, S3BucketName]')"; then
    csv_row "$account" "" "" "" "" "" "" "" "" "" "ERROR: $(last_error)" >> "$out"
    continue
  fi
  if [[ -z "$trails" ]]; then
    csv_row "$account" "" "" "" "" "" "" "" "" "" "NO TRAIL FOUND" >> "$out"
    continue
  fi
  while IFS=$'\t' read -r arn name home multi org validation kms cwlogs bucket; do
    logging="$(aws_try cloudtrail get-trail-status --name "$arn" --profile "$account" --region "$home" \
      --output text --query IsLogging </dev/null || echo "UNKNOWN")"
    encrypted="False"; [[ "$kms" != "None" ]] && encrypted="True"
    integrated="False"; [[ "$cwlogs" != "None" ]] && integrated="True"
    findings=""
    [[ "$logging" == "True" ]] || findings="TRAIL NOT LOGGING"
    [[ "$multi" == "True" ]] || findings="${findings:+$findings; }SINGLE-REGION TRAIL"
    [[ "$validation" == "True" ]] || findings="${findings:+$findings; }LOG FILE VALIDATION DISABLED"
    [[ "$encrypted" == "True" ]] || findings="${findings:+$findings; }NOT ENCRYPTED WITH KMS"
    [[ "$integrated" == "True" ]] || findings="${findings:+$findings; }NO CLOUDWATCH LOGS INTEGRATION"
    csv_row "$account" "$name" "$home" "$multi" "$org" "$validation" "$encrypted" "$integrated" "$logging" "$bucket" "${findings:-OK}"
  done <<< "$trails" >> "$out"
done

log "Report: $out"
