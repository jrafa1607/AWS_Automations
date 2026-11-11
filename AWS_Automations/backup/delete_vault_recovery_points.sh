#!/usr/bin/env bash
# Purpose:  Deletes recovery points from an AWS Backup vault in every account (all points, or only EXPIRED ones).
#           Replaces CleanBackupVault.sh and List_And_Remove_Expired_Backups_CLI.
# Type:     CHANGES RESOURCES (DESTRUCTIVE; dry run by default)
# IAM:      backup:ListRecoveryPointsByBackupVault; to apply: backup:DeleteRecoveryPoint
# Usage:    ./backup/delete_vault_recovery_points.sh --vault <name> --region <region> [--expired-only]
#           DRY_RUN=false ./backup/delete_vault_recovery_points.sh --vault <name> --region <region> --expired-only
# Env:      ACCOUNTS_FILE, OUTPUT_DIR, DRY_RUN
# Notes:    Deleted recovery points cannot be recovered. Vaults protected by AWS Backup Vault Lock
#           (compliance mode) reject deletions before the retention period ends; those failures are reported.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws

vault="" region="" expired_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)        vault="${2:-}"; shift 2 ;;
    --region)       region="${2:-}"; shift 2 ;;
    --expired-only) expired_only=true; shift ;;
    -h|--help)      sed -n '2,13p' "$0"; exit 0 ;;
    *)              die "Unknown argument: $1 (use --help)" ;;
  esac
done
[[ -n "$vault" && -n "$region" ]] || die "Usage: $0 --vault <name> --region <region> [--expired-only]"

load_accounts
banner_mode

if [[ "$expired_only" == true ]]; then
  query='RecoveryPoints[?Status==`EXPIRED`].[RecoveryPointArn, CreationDate, Status]'
  scope="EXPIRED recovery points"
else
  query='RecoveryPoints[].[RecoveryPointArn, CreationDate, Status]'
  scope="ALL recovery points"
fi

if ! is_dry_run; then
  log "WARNING: this permanently deletes $scope in vault '$vault' ($region) in ${#ACCOUNTS[@]} account(s)."
  confirm "$vault" "Type the vault name to confirm:"
fi

out="$(report_file backup_recovery_points)"
csv_row account vault region recovery_point_arn created status action > "$out"
total=0 deleted=0 failed=0

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  log "Backup vault '$vault': $account / $region"
  points="$(aws backup list-recovery-points-by-backup-vault --backup-vault-name "$vault" \
    --profile "$account" --region "$region" --output text --query "$query" 2>/dev/null)" || {
    log "  Vault not found or not accessible in $account"
    continue
  }
  [[ -n "$points" ]] || { log "  No recovery point in scope"; continue; }

  while IFS=$'\t' read -r arn created status; do
    [[ -n "$arn" ]] || continue
    total=$((total + 1))
    if is_dry_run; then
      action="would delete"
    elif aws backup delete-recovery-point --backup-vault-name "$vault" --recovery-point-arn "$arn" \
           --profile "$account" --region "$region" </dev/null; then
      action="deleted"; deleted=$((deleted + 1))
    else
      action="FAILED (check Vault Lock or permissions)"; failed=$((failed + 1))
    fi
    csv_row "$account" "$vault" "$region" "$arn" "$created" "$status" "$action" >> "$out"
  done <<< "$points"
done

log "Recovery points in scope: $total | deleted: $deleted | failed: $failed"
log "Report: $out"
