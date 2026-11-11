#!/usr/bin/env bash
# Purpose:  Inventory of Amazon DocumentDB clusters with encryption and deletion protection status.
# Type:     Read-only
# IAM:      rds:DescribeDBClusters (included in ReadOnlyAccess)
# Usage:    ./inventory/list_documentdb_clusters.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file documentdb_clusters)"
csv_row account region cluster_id status engine_version storage_encrypted deletion_protection > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "DocumentDB clusters: $account / $region"
    aws docdb describe-db-clusters --profile "$account" --region "$region" --output text \
      --filters Name=engine,Values=docdb \
      --query 'DBClusters[].[DBClusterIdentifier, Status, EngineVersion, StorageEncrypted, DeletionProtection]' |
    while IFS=$'\t' read -r cluster status version encrypted protection; do
      [[ -n "$cluster" ]] || continue
      csv_row "$account" "$region" "$cluster" "$status" "$version" "$encrypted" "$protection"
    done >> "$out"
  done
done

log "Report: $out"
