#!/usr/bin/env bash
# Repository: https://github.com/jrafa1607/AWS_Automations
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

    if ebs="$(aws_try ec2 describe-snapshots --owner-ids self --restorable-by-user-ids all \
        --profile "$account" --region "$region" --output text --query 'Snapshots[].[SnapshotId, VolumeId]')"; then
      while IFS=$'\t' read -r snapshot volume; do
        [[ -n "$snapshot" ]] || continue
        csv_row "$account" "$region" "EBS" "$snapshot" "$volume" "PUBLIC SNAPSHOT"
      done <<< "$ebs" >> "$out"
    else
      csv_row "$account" "$region" "EBS" "" "" "ERROR: $(last_error)" >> "$out"
    fi

    if db_snapshots="$(aws_try rds describe-db-snapshots --snapshot-type manual --profile "$account" --region "$region" \
        --output text --query 'DBSnapshots[].DBSnapshotIdentifier')"; then
      for snapshot in $db_snapshots; do
        shared="$(aws_try rds describe-db-snapshot-attributes --db-snapshot-identifier "$snapshot" \
          --profile "$account" --region "$region" --output text \
          --query 'DBSnapshotAttributesResult.DBSnapshotAttributes[?AttributeName==`restore`].AttributeValues[]' || true)"
        if [[ " $shared " == *" all "* ]]; then
          csv_row "$account" "$region" "RDS" "$snapshot" "db instance" "PUBLIC SNAPSHOT" >> "$out"
        fi
      done
    else
      csv_row "$account" "$region" "RDS" "" "" "ERROR: $(last_error)" >> "$out"
    fi

    if cluster_snapshots="$(aws_try rds describe-db-cluster-snapshots --snapshot-type manual --profile "$account" --region "$region" \
        --output text --query 'DBClusterSnapshots[].DBClusterSnapshotIdentifier')"; then
      for snapshot in $cluster_snapshots; do
        shared="$(aws_try rds describe-db-cluster-snapshot-attributes --db-cluster-snapshot-identifier "$snapshot" \
          --profile "$account" --region "$region" --output text \
          --query 'DBClusterSnapshotAttributesResult.DBClusterSnapshotAttributes[?AttributeName==`restore`].AttributeValues[]' || true)"
        if [[ " $shared " == *" all "* ]]; then
          csv_row "$account" "$region" "RDS cluster" "$snapshot" "db cluster" "PUBLIC SNAPSHOT" >> "$out"
        fi
      done
    else
      csv_row "$account" "$region" "RDS cluster" "" "" "ERROR: $(last_error)" >> "$out"
    fi
  done
done

log "Report: $out (only public snapshots and errors are listed; an empty report means none were found)"
