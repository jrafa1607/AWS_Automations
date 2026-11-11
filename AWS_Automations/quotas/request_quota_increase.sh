#!/usr/bin/env bash
# Purpose:  Requests a Service Quotas increase in every account (and region, for regional quotas),
#           skipping accounts where the current value already meets the target.
#           Replaces Increase_Quotas_Policies_For_Roles.sh and Increase_Quotas_VPCs_For_Regions.sh.
# Type:     CHANGES RESOURCES (opens quota requests; dry run by default)
# IAM:      servicequotas:GetServiceQuota, servicequotas:GetAWSDefaultServiceQuota;
#           to apply: servicequotas:RequestServiceQuotaIncrease
# Usage:    ./quotas/request_quota_increase.sh <service-code> <quota-code> <desired-value>
# Examples: ./quotas/request_quota_increase.sh iam L-0DA4ABF3 20   # managed policies per role (global)
#           ./quotas/request_quota_increase.sh vpc L-F678F1CE 10   # VPCs per Region
# Env:      ACCOUNTS_FILE, REGIONS, OUTPUT_DIR, DRY_RUN

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
require_tools aws

service="${1:-}" quota="${2:-}" desired="${3:-}"
[[ -n "$service" && -n "$quota" && "$desired" =~ ^[0-9]+$ ]] || die "Usage: $0 <service-code> <quota-code> <desired-value>"

# Global services keep their quotas in us-east-1 only; requesting in other regions creates duplicates.
case "$service" in
  iam|organizations|route53|cloudfront) regions="us-east-1"; log "Global service '$service': using us-east-1 only" ;;
  *) regions="$REGIONS" ;;
esac

load_accounts
banner_mode
if ! is_dry_run; then
  confirm "REQUEST" "Type REQUEST to open quota increase requests for $service/$quota = $desired:"
fi

out="$(report_file quota_requests)"
csv_row account region service quota_code current_value desired_value action > "$out"

for account in "${ACCOUNTS[@]}"; do
  check_session "$account" || continue
  for region in $regions; do
    current="$(aws service-quotas get-service-quota --service-code "$service" --quota-code "$quota" \
      --profile "$account" --region "$region" --output text --query Quota.Value 2>/dev/null ||
      aws service-quotas get-aws-default-service-quota --service-code "$service" --quota-code "$quota" \
      --profile "$account" --region "$region" --output text --query Quota.Value 2>/dev/null || echo "")"
    current="${current%%.*}"
    if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -ge "$desired" ]]; then
      action="already at or above target"
    elif is_dry_run; then
      action="would request"
    elif request_id="$(aws service-quotas request-service-quota-increase --service-code "$service" --quota-code "$quota" \
           --desired-value "$desired" --profile "$account" --region "$region" --output text --query RequestedQuota.Id 2>/dev/null)"; then
      action="requested (id: $request_id)"
    else
      action="FAILED (a request may already be open)"
    fi
    log "$account / $region: current=${current:-unknown} -> $action"
    csv_row "$account" "$region" "$service" "$quota" "$current" "$desired" "$action" >> "$out"
  done
done

log "Report: $out"
