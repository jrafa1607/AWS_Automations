#!/usr/bin/env bash
# Purpose:  Finds enabled customer managed KMS keys (symmetric) without automatic key rotation.
# Type:     Read-only
# IAM:      kms:ListKeys, kms:DescribeKey, kms:GetKeyRotationStatus (included in SecurityAudit)
# Usage:    ./security/check_kms_key_rotation.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR
# Note:     AWS managed keys rotate automatically; asymmetric and HMAC keys do not support rotation.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file kms_key_rotation)"
csv_row account region key_id description rotation_enabled finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "KMS key rotation: $account / $region"
    keys="$(aws kms list-keys --profile "$account" --region "$region" --output text --query 'Keys[].KeyId')"
    for key in $keys; do
      IFS=$'\t' read -r manager spec state description < <(aws kms describe-key --key-id "$key" \
        --profile "$account" --region "$region" --output text \
        --query 'KeyMetadata.[KeyManager, KeySpec, KeyState, Description || `"None"`]' 2>/dev/null) || continue
      [[ "$manager" == "CUSTOMER" && "$spec" == "SYMMETRIC_DEFAULT" && "$state" == "Enabled" ]] || continue
      rotation="$(aws kms get-key-rotation-status --key-id "$key" --profile "$account" --region "$region" \
        --output text --query KeyRotationEnabled 2>/dev/null || echo "UNKNOWN")"
      finding="OK"
      [[ "$rotation" == "True" ]] || finding="AUTOMATIC ROTATION DISABLED"
      csv_row "$account" "$region" "$key" "$description" "$rotation" "$finding" >> "$out"
    done
  done
done

log "Report: $out"
