#!/usr/bin/env bash
# Purpose:  Checks RDS DB instances for public accessibility, storage encryption, and deletion protection.
#           For cluster members (Aurora, DocumentDB, Neptune), deletion protection is read from the cluster.
# Type:     Read-only
# IAM:      rds:DescribeDBInstances, rds:DescribeDBClusters (included in SecurityAudit)
# Usage:    ./security/check_rds_security.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file rds_security)"
csv_row account region db_instance engine cluster publicly_accessible storage_encrypted deletion_protection finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "RDS: $account / $region"
    if ! instances="$(aws_try rds describe-db-instances --profile "$account" --region "$region" --output text \
        --query 'DBInstances[].[DBInstanceIdentifier, Engine, DBClusterIdentifier || `"None"`, PubliclyAccessible, StorageEncrypted, DeletionProtection]')"; then
      csv_row "$account" "$region" "" "" "" "" "" "" "ERROR: $(last_error)" >> "$out"
      continue
    fi
    [[ -n "$instances" ]] || continue
    # "cluster-id:True cluster-id:False" (Bash 3.2 has no associative arrays)
    clusters=" $(aws_try rds describe-db-clusters --profile "$account" --region "$region" --output text \
      --query 'DBClusters[].join(`:`, [DBClusterIdentifier, to_string(DeletionProtection)])' | tr '\t\n' '  ' || true) "
    while IFS=$'\t' read -r db engine cluster public encrypted protection; do
      [[ -n "$db" ]] || continue
      if [[ "$cluster" != "None" ]]; then
        if [[ "$clusters" == *" $cluster:true "* ]]; then protection="True (cluster)"
        elif [[ "$clusters" == *" $cluster:false "* ]]; then protection="False (cluster)"
        else protection="UNKNOWN (cluster)"
        fi
      fi
      findings=""
      [[ "$public" == "True" ]] && findings="PUBLICLY ACCESSIBLE"
      [[ "$encrypted" == "True" ]] || findings="${findings:+$findings; }STORAGE NOT ENCRYPTED"
      [[ "$protection" == True* || "$protection" == UNKNOWN* ]] || findings="${findings:+$findings; }DELETION PROTECTION DISABLED"
      csv_row "$account" "$region" "$db" "$engine" "$cluster" "$public" "$encrypted" "$protection" "${findings:-OK}"
    done <<< "$instances" >> "$out"
  done
done

log "Report: $out"
