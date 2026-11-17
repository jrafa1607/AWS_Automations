#!/usr/bin/env bash
# Purpose:  Checks that an IAM Access Analyzer for external access is active in every account and region,
#           and counts its active findings (resources shared outside the zone of trust).
# Type:     Read-only
# IAM:      access-analyzer:ListAnalyzers, access-analyzer:ListFindingsV2 (included in SecurityAudit)
# Usage:    ./security/check_access_analyzer.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR
# Note:     A member account without its own analyzer may still be covered by an ORGANIZATION analyzer
#           created in the management or delegated administrator account.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file access_analyzer)"
csv_row account region analyzer type active_findings finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "IAM Access Analyzer: $account / $region"
    if ! analyzers="$(aws_try accessanalyzer list-analyzers --profile "$account" --region "$region" --output text \
        --query 'analyzers[?status==`ACTIVE` && (type==`ACCOUNT` || type==`ORGANIZATION`)].[arn, name, type]')"; then
      csv_row "$account" "$region" "" "" "" "ERROR: $(last_error)" >> "$out"
      continue
    fi
    if [[ -z "$analyzers" ]]; then
      csv_row "$account" "$region" "" "" "" "NO ACTIVE ANALYZER IN THIS ACCOUNT (check for an organization analyzer)" >> "$out"
      continue
    fi
    while IFS=$'\t' read -r arn name type; do
      if count="$(aws_try accessanalyzer list-findings-v2 --analyzer-arn "$arn" --profile "$account" --region "$region" \
          --filter '{"status": {"eq": ["ACTIVE"]}}' --output text --query 'length(findings)' </dev/null)"; then
        finding="OK"
        if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then finding="$count ACTIVE EXTERNAL ACCESS FINDING(S) TO REVIEW"; fi
      else
        count=""
        finding="ERROR READING FINDINGS: $(last_error)"
      fi
      csv_row "$account" "$region" "$name" "$type" "$count" "$finding"
    done <<< "$analyzers" >> "$out"
  done
done

log "Report: $out"
