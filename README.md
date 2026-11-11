### ☁️🛡️ AWS Cloud Automations

*Multi-account AWS CLI scripts for security posture checks, inventory, and safe operations, using AWS IAM Identity Center (SSO).*

[![AWS CLI](https://img.shields.io/badge/AWS%20CLI-v2-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/cli/)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-green?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![IAM Identity Center](https://img.shields.io/badge/Auth-IAM%20Identity%20Center-red?style=for-the-badge&logo=amazonaws&logoColor=white)](https://docs.aws.amazon.com/singlesignon/)

---

#### 📖 Overview

Organizations with dozens of AWS accounts need the same questions answered in every account and region: *Is CloudTrail logging? Is GuardDuty on? Which security groups are open to the internet? Which access keys are old or unused?* This repository answers them with plain **Bash and the AWS CLI**, looping over the accounts listed in a local file and writing a **CSV report** for each check.

| Pillar | How the scripts support it |
| :--- | :--- |
| 🛡️ **Security posture** | Read-only checks for logging, threat detection, public exposure, encryption, and credentials |
| 📋 **Inventory** | One report per resource type across all accounts and regions |
| 🧯 **Safe operations** | Changes run in **dry-run mode by default** and require typed confirmation |
| 📈 **Scale** | The same check runs in every account listed in `accounts` |

---

#### 🔐 Safety Model

* **Read-only by default.** Most scripts only describe resources and can run with the AWS managed policies `SecurityAudit` or `ReadOnlyAccess`.
* **Dry run first.** Scripts that change resources only report what they *would* do, unless you set `DRY_RUN=false`.
* **Typed confirmation.** When applying changes, the script asks you to type a specific word (or the vault name) before anything happens.
* **Sessions are checked.** Accounts without a valid SSO session are skipped with a clear message instead of failing halfway.
* **Reports stay local.** Reports go to `reports/`, which is ignored by git, because they may contain IDs, IPs, and user names.

> [!IMPORTANT]
> Always read a script before running it, and test changes in non-production accounts first.

---

#### 🗂️ Script Catalog

**Security posture** (`security/`)

| Script | What it checks | Type | Minimum permissions |
| --- | --- | --- | --- |
| `check_cloudtrail_status.sh` | A trail exists **and is logging**, is multi-region, and validates log files | Read-only | `SecurityAudit` |
| `check_guardduty_status.sh` | GuardDuty detector enabled in every account and region | Read-only | `SecurityAudit` |
| `check_open_security_groups.sh` | Inbound rules open to `0.0.0.0/0` or `::/0` on sensitive ports or all ports | Read-only | `SecurityAudit` |
| `check_s3_block_public_access.sh` | S3 Block Public Access at account and bucket level | Read-only | `SecurityAudit` |
| `check_ebs_default_encryption.sh` | EBS encryption by default enabled per region | Read-only | `SecurityAudit` |
| `audit_iam_access_keys.sh` | Access keys never used, unused for 90+ days, or older than 90 days | Read-only | `SecurityAudit` |
| `enforce_s3_versioning.sh` | Reports buckets without versioning and, optionally, enables it | **Changes resources** (dry run by default) | `SecurityAudit` + `s3:PutBucketVersioning` |

**Inventory** (`inventory/`)

| Script | What it lists | Type | Minimum permissions |
| --- | --- | --- | --- |
| `list_ec2_instances.sh` | Instances with Name tag, state, AZ, and IPs | Read-only | `ReadOnlyAccess` |
| `list_lambda_functions.sh` | Functions with runtime (to spot deprecated runtimes) | Read-only | `ReadOnlyAccess` |
| `list_documentdb_clusters.sh` | DocumentDB clusters with encryption and deletion protection | Read-only | `ReadOnlyAccess` |
| `list_route53_records.sh` | Hosted zones and records, including alias targets | Read-only | `ReadOnlyAccess` |
| `list_stacks_failed_states.sh` | CloudFormation stacks stuck in failed rollback or delete states | Read-only | `ReadOnlyAccess` |
| `find_eni_by_private_ip.sh` | Which account, instance, and security groups own a private IP | Read-only | `ReadOnlyAccess` |

**Operations** (`backup/`, `quotas/`)

| Script | What it does | Type | Minimum permissions |
| --- | --- | --- | --- |
| `backup/delete_vault_recovery_points.sh` | Deletes all or only **EXPIRED** recovery points in a backup vault | **Destructive** (dry run by default) | `backup:ListRecoveryPointsByBackupVault`, `backup:DeleteRecoveryPoint` |
| `quotas/request_quota_increase.sh` | Requests a Service Quotas increase, skipping accounts already at the target | **Changes resources** (dry run by default) | `servicequotas:Get*`, `servicequotas:RequestServiceQuotaIncrease` |

---

#### 🚀 Quick Start

```bash
# 1. Configure AWS CLI profiles for IAM Identity Center (see docs/SETUP.md)
cp accounts.example accounts        # then edit the profile names
aws sso login --profile <profile>   # one login per SSO session

# 2. Run a read-only check
./security/check_open_security_groups.sh

# 3. Preview a change, then apply it
./security/enforce_s3_versioning.sh
DRY_RUN=false ./security/enforce_s3_versioning.sh

# Examples with arguments
./inventory/find_eni_by_private_ip.sh 10.20.30.40
./backup/delete_vault_recovery_points.sh --vault my-vault --region us-east-1 --expired-only
./quotas/request_quota_increase.sh vpc L-F678F1CE 10
```

**Settings** (environment variables)

| Variable | Default | Purpose |
| --- | --- | --- |
| `ACCOUNTS_FILE` | `accounts` | File with one AWS CLI profile per line |
| `REGIONS` | `us-east-1 sa-east-1` | Regions for regional checks |
| `DRY_RUN` | `true` | Set to `false` to apply changes |
| `OUTPUT_DIR` | `reports` | Folder for the CSV reports |

Requirements: AWS CLI v2 and Bash 3.2 or later (Linux, macOS, WSL, or AWS CloudShell).

---

#### 🔄 Migration from the Previous Scripts

| Previous script | Replaced by |
| --- | --- |
| `CleanBackupVault.sh`, `List_And_Remove_Expired_Backups_CLI` | `backup/delete_vault_recovery_points.sh` |
| `Get_All_Trails_Enabled.sh` | `security/check_cloudtrail_status.sh` |
| `Get_And_Put_Versioning_s3.sh` | `security/enforce_s3_versioning.sh` |
| `Get_IAM_All_Info.sh` | `security/audit_iam_access_keys.sh` |
| `GetRoute53_All_Info.sh` | `inventory/list_route53_records.sh` |
| `List_All_Ec2_With_ID_Information.sh`, `List_All_Ec2_With_IP_Information.sh` | `inventory/list_ec2_instances.sh` |
| `List_All_Lambda_Functions.sh` | `inventory/list_lambda_functions.sh` |
| `List_All_DocumentsDB.sh` | `inventory/list_documentdb_clusters.sh` |
| `List_All_SecurityGroups.sh` | `inventory/find_eni_by_private_ip.sh` (what it actually did) and `security/check_open_security_groups.sh` |
| `List_All_StackSet_With_Rollback_Incomplete.sh` | `inventory/list_stacks_failed_states.sh` |
| `Increase_Quotas_Policies_For_Roles.sh`, `Increase_Quotas_VPCs_For_Regions.sh` | `quotas/request_quota_increase.sh` |

---

#### ⚖️ Intellectual Property (IP) Notice

All source code and documentation in this repository are the exclusive Intellectual Property of the author. All rights reserved. Use of this content for academic or professional purposes must include proper citation and attribution.

**Copyright © 2026 [João Rafael](https://www.linkedin.com/in/jrafa1607/).**
