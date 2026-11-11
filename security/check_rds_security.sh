#!/usr/bin/env bash
# Purpose:  Checks RDS instances for public accessibility, storage encryption, and deletion protection.
# Type:     Read-only
# IAM:      rds:DescribeDBInstances (included in SecurityAudit)
# Usage:    ./security/check_rds_security.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file rds_security)"
csv_row account region db_instance engine publicly_accessible storage_encrypted deletion_protection finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "RDS: $account / $region"
    aws rds describe-db-instances --profile "$account" --region "$region" --output text \
      --query 'DBInstances[].[DBInstanceIdentifier, Engine, PubliclyAccessible, StorageEncrypted, DeletionProtection]' |
    while IFS=$'\t' read -r db engine public encrypted protection; do
      [[ -n "$db" ]] || continue
      findings=""
      [[ "$public" == "True" ]] && findings="PUBLICLY ACCESSIBLE"
      [[ "$encrypted" == "True" ]] || findings="${findings:+$findings; }STORAGE NOT ENCRYPTED"
      [[ "$protection" == "True" ]] || findings="${findings:+$findings; }DELETION PROTECTION DISABLED"
      csv_row "$account" "$region" "$db" "$engine" "$public" "$encrypted" "$protection" "${findings:-OK}"
    done >> "$out"
  done
done

log "Report: $out"
