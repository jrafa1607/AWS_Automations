#!/usr/bin/env bash
# Purpose:  Checks that AWS Config is recording and has a delivery channel in every account and region.
# Type:     Read-only
# IAM:      config:DescribeConfigurationRecorderStatus, config:DescribeDeliveryChannels (included in SecurityAudit)
# Usage:    ./security/check_aws_config_status.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file aws_config_status)"
csv_row account region recorder recording last_status delivery_channel finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "AWS Config: $account / $region"
    read -r recorder recording last_status < <(aws configservice describe-configuration-recorder-status \
      --profile "$account" --region "$region" --output text \
      --query 'ConfigurationRecordersStatus[0].[name, recording, lastStatus]') || true
    channel="$(aws configservice describe-delivery-channels --profile "$account" --region "$region" \
      --output text --query 'DeliveryChannels[0].name')"
    findings=""
    if [[ -z "$recorder" || "$recorder" == "None" ]]; then
      findings="NO CONFIGURATION RECORDER"
    elif [[ "$recording" != "True" ]]; then
      findings="RECORDER NOT RECORDING"
    elif [[ "$last_status" == "FAILURE" ]]; then
      findings="RECORDER LAST STATUS FAILURE"
    fi
    if [[ -z "$channel" || "$channel" == "None" ]]; then
      findings="${findings:+$findings; }NO DELIVERY CHANNEL"
    fi
    csv_row "$account" "$region" "$recorder" "$recording" "$last_status" "$channel" "${findings:-OK}" >> "$out"
  done
done

log "Report: $out"
