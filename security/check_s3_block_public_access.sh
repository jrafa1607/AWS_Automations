#!/usr/bin/env bash
# Repository: https://github.com/jrafa1607/AWS_Automations
# Purpose:  Checks S3 Block Public Access at account level and on every bucket.
# Type:     Read-only
# IAM:      s3:GetAccountPublicAccessBlock, s3:ListAllMyBuckets, s3:GetBucketPublicAccessBlock (included in SecurityAudit)
# Usage:    ./security/check_s3_block_public_access.sh
# Env:      ACCOUNTS_FILE, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file s3_block_public_access)"
csv_row account scope name block_public_acls ignore_public_acls block_public_policy restrict_public_buckets finding > "$out"

QUERY='PublicAccessBlockConfiguration.[BlockPublicAcls, IgnorePublicAcls, BlockPublicPolicy, RestrictPublicBuckets]'

evaluate() {
  if [[ "$*" == "True True True True" ]]; then echo "OK"; else echo "BLOCK PUBLIC ACCESS NOT FULLY ENABLED"; fi
}

# Prints the finding for a failed call: "not configured" only when AWS says so, otherwise the error.
missing_or_error() {
  local error
  error="$(last_error)"
  if [[ "$error" == "NoSuchPublicAccessBlockConfiguration" ]]; then echo "$1"; else echo "ERROR: $error"; fi
}

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "S3 Block Public Access: $account"
  id="$(account_id "$account")"

  if settings="$(aws_try s3control get-public-access-block --account-id "$id" --profile "$account" --output text --query "$QUERY")"; then
    read -r a b c d <<< "$settings"
    csv_row "$account" account "$id" "$a" "$b" "$c" "$d" "$(evaluate "$a" "$b" "$c" "$d")" >> "$out"
  else
    csv_row "$account" account "$id" "" "" "" "" "$(missing_or_error "NOT CONFIGURED AT ACCOUNT LEVEL")" >> "$out"
  fi

  if ! buckets="$(aws_try s3api list-buckets --profile "$account" --output text --query 'Buckets[].Name')"; then
    csv_row "$account" bucket "" "" "" "" "" "ERROR LISTING BUCKETS: $(last_error)" >> "$out"
    continue
  fi
  for bucket in $buckets; do
    if settings="$(aws_try s3api get-public-access-block --bucket "$bucket" --profile "$account" --output text --query "$QUERY")"; then
      read -r a b c d <<< "$settings"
      csv_row "$account" bucket "$bucket" "$a" "$b" "$c" "$d" "$(evaluate "$a" "$b" "$c" "$d")" >> "$out"
    else
      csv_row "$account" bucket "$bucket" "" "" "" "" "$(missing_or_error "NOT CONFIGURED ON BUCKET (account level may still protect it)")" >> "$out"
    fi
  done
done

log "Report: $out"
