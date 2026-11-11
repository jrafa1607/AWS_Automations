#!/usr/bin/env bash
# Purpose:  Checks whether EBS encryption by default is enabled in every account and region.
# Type:     Read-only
# IAM:      ec2:GetEbsEncryptionByDefault, ec2:GetEbsDefaultKmsKeyId (included in SecurityAudit)
# Usage:    ./security/check_ebs_default_encryption.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file ebs_default_encryption)"
csv_row account region encryption_by_default default_kms_key finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "EBS default encryption: $account / $region"
    enabled="$(aws ec2 get-ebs-encryption-by-default --profile "$account" --region "$region" --output text --query EbsEncryptionByDefault)"
    key="$(aws ec2 get-ebs-default-kms-key-id --profile "$account" --region "$region" --output text --query KmsKeyId 2>/dev/null || echo "")"
    finding="OK"
    [[ "$enabled" == "True" ]] || finding="EBS ENCRYPTION BY DEFAULT DISABLED"
    csv_row "$account" "$region" "$enabled" "$key" "$finding" >> "$out"
  done
done

log "Report: $out"
