#!/usr/bin/env bash
# Shared helpers for every script in this repository.
# Usage inside a script:
#   # shellcheck source=../lib/common.sh
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

set -euo pipefail

# Settings (override with environment variables)
ACCOUNTS_FILE="${ACCOUNTS_FILE:-accounts}"    # one AWS CLI profile per line
REGIONS="${REGIONS:-us-east-1 sa-east-1}"     # space-separated list of regions
DRY_RUN="${DRY_RUN:-true}"                    # scripts that change resources act only when DRY_RUN=false
OUTPUT_DIR="${OUTPUT_DIR:-reports}"           # CSV reports go here (ignored by git)
export AWS_PAGER=""

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool"
  done
}

# Reads the accounts file into the ACCOUNTS array, ignoring comments and blank lines.
# Compatible with Bash 3.2 (macOS) and later.
load_accounts() {
  [[ -f "$ACCOUNTS_FILE" ]] || die "Accounts file not found: $ACCOUNTS_FILE (see docs/SETUP.md)"
  # shellcheck disable=SC2034  # ACCOUNTS is used by the scripts that source this file
  ACCOUNTS=()
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//$'\r'/}"
    line="${line//[[:space:]]/}"
    if [[ -n "$line" ]]; then ACCOUNTS+=("$line"); fi
  done < "$ACCOUNTS_FILE"
  [[ ${#ACCOUNTS[@]} -gt 0 ]] || die "No accounts listed in $ACCOUNTS_FILE"
  log "Loaded ${#ACCOUNTS[@]} account profile(s) from $ACCOUNTS_FILE"
}

# Returns 1 (and logs) when the profile has no valid session, so the caller can skip it.
check_session() {
  local profile="$1"
  if ! aws sts get-caller-identity --profile "$profile" --query Account --output text >/dev/null 2>&1; then
    log "Skipping $profile: no valid session (run: aws sso login --profile $profile)"
    return 1
  fi
}

account_id() {
  aws sts get-caller-identity --profile "$1" --query Account --output text
}

# Creates the output folder and prints a timestamped CSV path.
report_file() {
  mkdir -p "$OUTPUT_DIR"
  printf '%s/%s_%s.csv' "$OUTPUT_DIR" "$1" "$(date '+%Y%m%d_%H%M%S')"
}

# Prints one CSV row, quoting every field.
csv_row() {
  local first=true field
  for field in "$@"; do
    if [[ "$first" == true ]]; then first=false; else printf ','; fi
    field="${field//\"/\"\"}"
    printf '"%s"' "$field"
  done
  printf '\n'
}

is_dry_run() { [[ "$DRY_RUN" != "false" ]]; }

# Runs a command only when DRY_RUN=false; otherwise prints it.
run_or_print() {
  if is_dry_run; then
    log "DRY RUN (not executed): $*"
  else
    "$@"
  fi
}

# Asks the operator to type an exact value before any change is made.
confirm() {
  local expected="$1" prompt="$2" answer
  read -r -p "$prompt " answer
  [[ "$answer" == "$expected" ]] || die "Confirmation failed. Nothing was changed."
}

banner_mode() {
  if is_dry_run; then
    log "Mode: DRY RUN. No resource will be changed. Set DRY_RUN=false to apply."
  else
    log "Mode: APPLY. Resources WILL be changed."
  fi
}

# Days between an ISO-8601 timestamp and now (GNU date or BSD/macOS date).
days_since() {
  local day="${1%%T*}" now past
  if [[ -z "$day" || "$day" == "None" ]]; then printf ''; return 0; fi
  now="$(date +%s)"
  if past="$(date -d "$day" +%s 2>/dev/null)"; then :
  elif past="$(date -j -f '%Y-%m-%d' "$day" +%s 2>/dev/null)"; then :
  else printf ''; return 0
  fi
  printf '%s' "$(( (now - past) / 86400 ))"
}
