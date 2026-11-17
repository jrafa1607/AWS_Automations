#!/usr/bin/env bash
# Offline tests: run the scripts against a fake AWS CLI (tests/stub/aws). No AWS account is needed.
# Usage: ./tests/run_tests.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export PATH="$ROOT/tests/stub:$PATH"
export ACCOUNTS_FILE="$WORK/accounts" OUTPUT_DIR="$WORK/reports" STUB_LOG="$WORK/calls.log" REGIONS="us-east-1"
printf 'acct-ok\nacct-denied\nacct-bad\n' > "$ACCOUNTS_FILE"

passed=0 failed=0
check() {
  local description="$1"; shift
  if "$@"; then
    passed=$((passed + 1)); printf 'PASS  %s\n' "$description"
  else
    failed=$((failed + 1)); printf 'FAIL  %s\n' "$description"
  fi
}

# Runs a script quietly and prints the path of the newest report it wrote.
run() {
  rm -rf "$OUTPUT_DIR"
  "$ROOT/$1" >/dev/null 2>&1 </dev/null
  find "$OUTPUT_DIR" -name '*.csv' | head -n 1
}

report="$(run security/check_guardduty_status.sh)"
check "an AccessDenied account does not stop the run" grep -q '"acct-bad","us-east-1","","","GUARDDUTY NOT ENABLED"' "$report"
check "the AccessDenied account is reported as ERROR" grep -q '"acct-denied","us-east-1","","","ERROR: AccessDenied"' "$report"
check "a healthy account is reported as OK" grep -q '"acct-ok","us-east-1","det123","ENABLED","OK"' "$report"

report="$(run security/check_iam_password_policy.sh)"
check "NoSuchEntity is reported as a missing password policy" grep -q '"acct-bad".*"NO PASSWORD POLICY' "$report"
check "AccessDenied is not reported as a missing password policy" grep -q '"acct-denied".*"ERROR: AccessDenied"' "$report"

report="$(run inventory/list_ec2_instances.sh)"
check "values that start a spreadsheet formula are neutralized" grep -q "\"'=HYPERLINK(\"\"http://example.invalid\"\")\"" "$report"
check "negative numbers are kept as numbers" grep -q '"i-002","-1"' "$report"

report="$(run security/check_rds_security.sh)"
check "Aurora deletion protection is read from the cluster" grep -q '"aurora-1".*"True (cluster)","OK"' "$report"
check "a standalone instance still gets its findings" grep -q '"pg-1".*"PUBLICLY ACCESSIBLE; STORAGE NOT ENCRYPTED; DELETION PROTECTION DISABLED"' "$report"

: > "$STUB_LOG"
report="$(run security/enforce_s3_versioning.sh)"
check "dry run reports the change" grep -q '"bucket-b","Never enabled","would enable"' "$report"
no_change_calls() { ! grep -q put-bucket-versioning "$STUB_LOG"; }
check "dry run never calls put-bucket-versioning" no_change_calls

owner_only() { [[ -n "$(find "$report" -perm 600)" ]]; }
check "reports are readable only by the owner" owner_only

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
