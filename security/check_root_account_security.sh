#!/usr/bin/env bash
# Purpose:  Checks that the root user has MFA enabled and no access keys.
# Type:     Read-only
# IAM:      iam:GetAccountSummary (included in SecurityAudit)
# Usage:    ./security/check_root_account_security.sh
# Env:      ACCOUNTS_FILE, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file root_account_security)"
csv_row account root_mfa_enabled root_access_keys_present finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "Root account: $account"
  read -r mfa keys < <(aws iam get-account-summary --profile "$account" --output text \
    --query 'SummaryMap.[AccountMFAEnabled, AccountAccessKeysPresent]') || true
  findings=""
  [[ "$mfa" == "1" ]] || findings="ROOT MFA DISABLED"
  [[ "$keys" == "0" ]] || findings="${findings:+$findings; }ROOT ACCESS KEYS PRESENT"
  csv_row "$account" "$mfa" "$keys" "${findings:-OK}" >> "$out"
done

log "Report: $out"
log "Tip: in AWS Organizations, consider centralized root access management to remove root credentials from member accounts."
