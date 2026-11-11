#!/usr/bin/env bash
# Purpose:  Audits IAM user access keys: status, age, last use, and service. Flags keys that are old or unused.
# Type:     Read-only
# IAM:      iam:ListUsers, iam:ListAccessKeys, iam:GetAccessKeyLastUsed (included in SecurityAudit)
# Usage:    ./security/audit_iam_access_keys.sh
# Env:      ACCOUNTS_FILE, OUTPUT_DIR, MAX_KEY_AGE_DAYS (default 90), MAX_UNUSED_DAYS (default 90)

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

MAX_KEY_AGE_DAYS="${MAX_KEY_AGE_DAYS:-90}"
MAX_UNUSED_DAYS="${MAX_UNUSED_DAYS:-90}"
out="$(report_file iam_access_keys)"
csv_row account user access_key_id status created age_days last_used days_since_use last_service finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "IAM access keys: $account"
  users="$(aws iam list-users --profile "$account" --output text --query 'Users[].UserName')"
  for user in $users; do
    keys="$(aws iam list-access-keys --user-name "$user" --profile "$account" --output text \
      --query 'AccessKeyMetadata[].[AccessKeyId, Status, CreateDate]')"
    [[ -n "$keys" ]] || continue
    while IFS=$'\t' read -r key status created; do
      read -r last_used last_service < <(aws iam get-access-key-last-used --access-key-id "$key" --profile "$account" \
        --output text --query '[AccessKeyLastUsed.LastUsedDate, AccessKeyLastUsed.ServiceName]' </dev/null)
      age="$(days_since "$created")"
      unused="$(days_since "$last_used")"
      finding="OK"
      if [[ "$status" == "Active" ]]; then
        if [[ "$last_used" == "None" ]]; then
          finding="ACTIVE KEY NEVER USED"
        elif [[ -n "$unused" && "$unused" -gt "$MAX_UNUSED_DAYS" ]]; then
          finding="ACTIVE KEY UNUSED FOR MORE THAN $MAX_UNUSED_DAYS DAYS"
        elif [[ -n "$age" && "$age" -gt "$MAX_KEY_AGE_DAYS" ]]; then
          finding="KEY OLDER THAN $MAX_KEY_AGE_DAYS DAYS: ROTATE"
        fi
      fi
      csv_row "$account" "$user" "$key" "$status" "$created" "$age" "$last_used" "$unused" "$last_service" "$finding"
    done <<< "$keys" >> "$out"
  done
done

log "Report: $out"
log "Tip: prefer IAM Identity Center or roles over long-term access keys."
