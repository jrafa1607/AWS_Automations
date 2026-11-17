# ☁️🛡️ AWS Cloud Automations

*Multi-account AWS CLI scripts for security posture checks, inventory, and safe operations, using AWS IAM Identity Center.*

[![ShellCheck](https://img.shields.io/github/actions/workflow/status/jrafa1607/AWS_Automations/shellcheck.yml?label=ShellCheck%20%26%20Tests&style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/jrafa1607/AWS_Automations/actions/workflows/shellcheck.yml)
[![AWS CLI](https://img.shields.io/badge/AWS%20CLI-v2-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/cli/)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-green?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![IAM Identity Center](https://img.shields.io/badge/Auth-IAM%20Identity%20Center-red?style=for-the-badge&logo=amazonaws&logoColor=white)](https://docs.aws.amazon.com/singlesignon/)

---

#### 📖 Overview

Organizations with dozens of AWS accounts need the same questions answered in every account and region: *Is CloudTrail logging? Is GuardDuty on? Which security groups are open to the internet? Which access keys are old or unused?* This repository answers them with plain **Bash and the AWS CLI**, looping over the accounts listed in a local file and writing a **CSV report** for each check.

| Pillar | How the scripts support it |
| :--- | :--- |
| 🛡️ **Security** | 17 read-only posture checks |
| 📋 **Inventory** | One report per resource type |
| 🧯 **Safe operations** | Dry run by default, typed confirmation |
| 📈 **Scale** | Every account and region in one run |

---

#### 🔐 Safety Model

* **Dry run first:** scripts that change resources only report what they *would* do, unless you set `DRY_RUN=false`.
* **Typed confirmation:** when applying changes, the script asks you to type a specific word before anything happens.
* **Errors do not stop the run:** an account without a valid session is skipped, and an API error (for example, `AccessDenied` or a blocked region) is written to the report as `ERROR: <code>` while the script moves on.
* **No false findings from errors:** "not enabled" or "not configured" is reported only when AWS says so, never because a call was denied.
* **Reports stay local and private:** reports go to `reports/`, which is ignored by git and readable only by your user, because they may contain IDs and IPs. Values that a spreadsheet could run as a formula are neutralized.
* **Read-only by default:** most scripts only describe resources and run with the AWS managed policy `SecurityAudit` or `ReadOnlyAccess`.

---

#### 🗂️ Scripts

| Script | What it checks or does |
| --- | --- |
| `security/check_cloudtrail_status.sh` | Logging, multi-region, validation, KMS |
| `security/check_guardduty_status.sh` | GuardDuty enabled per region |
| `security/check_security_hub_status.sh` | Security Hub and enabled standards |
| `security/check_aws_config_status.sh` | Config recorder and delivery channel |
| `security/check_access_analyzer.sh` | External access analyzer and findings |
| `security/check_root_account_security.sh` | Root MFA and root access keys |
| `security/check_iam_password_policy.sh` | Password length, complexity, reuse |
| `security/audit_iam_access_keys.sh` | Old, unused, or never-used access keys |
| `security/check_open_security_groups.sh` | Sensitive ports open to the internet |
| `security/check_vpc_flow_logs.sh` | VPCs without active flow logs |
| `security/check_ec2_imdsv2.sh` | Instances that do not require IMDSv2 |
| `security/check_s3_block_public_access.sh` | Block Public Access, account and bucket |
| `security/check_public_snapshots.sh` | Public EBS and RDS snapshots |
| `security/check_rds_security.sh` | Public, unencrypted, or unprotected RDS |
| `security/check_ebs_default_encryption.sh` | EBS encryption by default |
| `security/check_kms_key_rotation.sh` | Customer keys without rotation |
| `security/enforce_s3_versioning.sh` | Enables S3 versioning *(dry run)* |
| `inventory/list_ec2_instances.sh` | EC2 instances, state, and IPs |
| `inventory/list_lambda_functions.sh` | Lambda functions and runtimes |
| `inventory/list_documentdb_clusters.sh` | DocumentDB clusters and protection |
| `inventory/list_route53_records.sh` | Hosted zones and DNS records |
| `inventory/list_stacks_failed_states.sh` | CloudFormation stacks in failed states |
| `inventory/find_eni_by_private_ip.sh` | Who owns a private IP |
| `backup/delete_vault_recovery_points.sh` | Recovery point cleanup *(dry run)* |
| `quotas/request_quota_increase.sh` | Quota increase requests *(dry run)* |

---

#### 🚀 Quick Start

```bash
# 1. Configure AWS CLI profiles for IAM Identity Center (see docs/SETUP.md)
cp accounts.example accounts        # then edit the profile names
aws sso login --sso-session my-sso  # one login covers every profile in the session

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
| `ACCOUNTS_FILE` | `accounts` | One AWS CLI profile per line |
| `REGIONS` | `us-east-1 sa-east-1` | Regions for regional checks |
| `DRY_RUN` | `true` | `false` applies changes |
| `OUTPUT_DIR` | `reports` | Folder for the CSV reports |

**Tests:** `./tests/run_tests.sh` runs the scripts against a fake AWS CLI, with no AWS account, and checks error handling, report safety, and dry-run behavior. The CI runs it after ShellCheck on every change.

> [!IMPORTANT]
> **Requirements:** AWS CLI v2 and Bash 3.2 or later (Linux, macOS, WSL, or AWS CloudShell).<br>
> Always read a script before running it, test changes in non-production accounts first, and only assess accounts you are authorized to.

---

#### ⚖️ Intellectual Property (IP) Notice

All source code and documentation in this repository are the exclusive Intellectual Property of the author. All rights reserved. Use of this content for academic or professional purposes must include proper citation and attribution. To report a vulnerability, see [`SECURITY.md`](SECURITY.md).

**Copyright © 2026 [João Rafael](https://www.linkedin.com/in/jrafa1607/).**
