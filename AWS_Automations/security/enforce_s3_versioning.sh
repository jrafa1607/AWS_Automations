#!/usr/bin/env bash
# Purpose:  Reports S3 buckets without versioning and, when explicitly allowed, enables it.
# Type:     CHANGES RESOURCES (dry run by default)
# IAM:      s3:ListAllMyBuckets, s3:GetBucketVersioning; to apply: s3:PutBucketVersioning
# Usage:    ./security/enforce_s3_versioning.sh                 # report only (dry run)
#           DRY_RUN=false ./security/enforce_s3_versioning.sh   # enable versioning (asks for confirmation)
# Env:      ACCOUNTS_FILE, OUTPUT_DIR, DRY_RUN
# Notes:    Versioning keeps every object version and increases storage cost.
#           Pair it with lifecycle rules that expire noncurrent versions.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts
banner_mode

if ! is_dry_run; then
  log "WARNING: versioning will be enabled on every bucket where it is not enabled, in ${#ACCOUNTS[@]} account(s)."
  confirm "ENABLE" "Type ENABLE to continue:"
fi

out="$(report_file s3_versioning)"
csv_row account bucket previous_status action > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "S3 versioning: $account"
  buckets="$(aws s3api list-buckets --profile "$account" --output text --query 'Buckets[].Name')"
  for bucket in $buckets; do
    status="$(aws s3api get-bucket-versioning --bucket "$bucket" --profile "$account" --output text --query Status 2>/dev/null || echo "ACCESS_DENIED")"
    case "$status" in
      Enabled)
        action="none" ;;
      ACCESS_DENIED)
        action="skipped: no permission to read the configuration" ;;
      *)
        if is_dry_run; then
          action="would enable"
        elif aws s3api put-bucket-versioning --bucket "$bucket" --profile "$account" \
               --versioning-configuration Status=Enabled; then
          action="enabled"
        else
          action="FAILED to enable"
        fi ;;
    esac
    [[ "$status" == "None" ]] && status="Never enabled"
    csv_row "$account" "$bucket" "$status" "$action" >> "$out"
  done
done

log "Report: $out"
