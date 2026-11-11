#!/usr/bin/env bash
# Purpose:  Checks the IAM password policy for length, complexity, and reuse prevention.
# Type:     Read-only
# IAM:      iam:GetAccountPasswordPolicy (included in SecurityAudit)
# Usage:    ./security/check_iam_password_policy.sh
# Env:      ACCOUNTS_FILE, OUTPUT_DIR, MIN_PASSWORD_LENGTH (default 14), MIN_REUSE_PREVENTION (default 24)

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

MIN_PASSWORD_LENGTH="${MIN_PASSWORD_LENGTH:-14}"
MIN_REUSE_PREVENTION="${MIN_REUSE_PREVENTION:-24}"
out="$(report_file iam_password_policy)"
csv_row account min_length symbols numbers uppercase lowercase max_age_days reuse_prevention finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "IAM password policy: $account"
  if ! policy="$(aws iam get-account-password-policy --profile "$account" --output text \
      --query 'PasswordPolicy.[MinimumPasswordLength, RequireSymbols, RequireNumbers, RequireUppercaseCharacters, RequireLowercaseCharacters, MaxPasswordAge, PasswordReusePrevention]' 2>/dev/null)"; then
    csv_row "$account" "" "" "" "" "" "" "" "NO PASSWORD POLICY (AWS defaults apply)" >> "$out"
    continue
  fi
  read -r length symbols numbers upper lower max_age reuse <<< "$policy"
  findings=""
  if [[ ! "$length" =~ ^[0-9]+$ || "$length" -lt "$MIN_PASSWORD_LENGTH" ]]; then
    findings="MINIMUM LENGTH BELOW $MIN_PASSWORD_LENGTH"
  fi
  if [[ "$symbols $numbers $upper $lower" != "True True True True" ]]; then
    findings="${findings:+$findings; }COMPLEXITY NOT FULLY REQUIRED"
  fi
  if [[ ! "$reuse" =~ ^[0-9]+$ || "$reuse" -lt "$MIN_REUSE_PREVENTION" ]]; then
    findings="${findings:+$findings; }REUSE PREVENTION BELOW $MIN_REUSE_PREVENTION"
  fi
  csv_row "$account" "$length" "$symbols" "$numbers" "$upper" "$lower" "$max_age" "$reuse" "${findings:-OK}" >> "$out"
done

log "Report: $out"
