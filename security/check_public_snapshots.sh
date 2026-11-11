#!/usr/bin/env bash
# Purpose:  Finds EBS snapshots and RDS (instance and cluster) snapshots shared publicly.
# Type:     Read-only
# IAM:      ec2:DescribeSnapshots, rds:DescribeDBSnapshots, rds:DescribeDBSnapshotAttributes,
#           rds:DescribeDBClusterSnapshots, rds:DescribeDBClusterSnapshotAttributes (included in SecurityAudit)
# Usage:    ./security/check_public_snapshots.sh
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws
load_accounts

out="$(report_file public_snapshots)"
csv_row account region type snapshot_id source finding > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $REGIONS; do
    log "Public snapshots: $account / $region"

    aws ec2 describe-snapshots --owner-ids self --restorable-by-user-ids all \
      --profile "$account" --region "$region" --output text \
      --query 'Snapshots[].[SnapshotId, VolumeId]' |
    while IFS=$'\t' read -r snapshot volume; do
      [[ -n "$snapshot" ]] || continue
      csv_row "$account" "$region" "EBS" "$snapshot" "$volume" "PUBLIC SNAPSHOT"
    done >> "$out"

    for snapshot in $(aws rds describe-db-snapshots --snapshot-type manual --profile "$account" --region "$region" \
        --output text --query 'DBSnapshots[].DBSnapshotIdentifier'); do
      shared="$(aws rds describe-db-snapshot-attributes --db-snapshot-identifier "$snapshot" \
        --profile "$account" --region "$region" --output text \
        --query 'DBSnapshotAttributesResult.DBSnapshotAttributes[?AttributeName==`restore`].AttributeValues[]')"
      if [[ " $shared " == *" all "* ]]; then
        csv_row "$account" "$region" "RDS" "$snapshot" "db instance" "PUBLIC SNAPSHOT" >> "$out"
      fi
    done

    for snapshot in $(aws rds describe-db-cluster-snapshots --snapshot-type manual --profile "$account" --region "$region" \
        --output text --query 'DBClusterSnapshots[].DBClusterSnapshotIdentifier'); do
      shared="$(aws rds describe-db-cluster-snapshot-attributes --db-cluster-snapshot-identifier "$snapshot" \
        --profile "$account" --region "$region" --output text \
        --query 'DBClusterSnapshotAttributesResult.DBClusterSnapshotAttributes[?AttributeName==`restore`].AttributeValues[]')"
      if [[ " $shared " == *" all "* ]]; then
        csv_row "$account" "$region" "RDS cluster" "$snapshot" "db cluster" "PUBLIC SNAPSHOT" >> "$out"
      fi
    done
  done
done

log "Report: $out (only public snapshots are listed; an empty report means none were found)"
