### ☁️🛡️ AWS Cloud Automations

*Multi-account AWS CLI scripts for security posture checks, inventory, and safe operations, using AWS IAM Identity Center.*

[![AWS CLI](https://img.shields.io/badge/AWS%20CLI-v2-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/cli/)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-green?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![IAM Identity Center](https://img.shields.io/badge/Auth-IAM%20Identity%20Center-red?style=for-the-badge&logo=amazonaws&logoColor=white)](https://docs.aws.amazon.com/singlesignon/)

---

#### 📖 Overview

Organizations with dozens of AWS accounts need the same questions answered in every account and region: *Is CloudTrail logging? Is GuardDuty on? Which security groups are open to the internet? Which access keys are old or unused?* This repository answers them with plain **Bash and the AWS CLI**, looping over the accounts listed in a local file and writing a **CSV report** for each check.

| Pillar | How the scripts support it |
| :--- | :--- |
| 🛡️ **Security** | Read-only checks for logging, threat detection, public exposure, encryption, and credentials |
| 📋 **Inventory** | One report per resource type across all accounts and regions |
| 🧯 **Safe operations** | Changes run in **dry-run mode by default** and require typed confirmation |
| 📈 **Scale** | The same check runs in every account listed in `accounts` |

---

#### 🔐 Safety Model

* **Read-only by default.** Most scripts only describe resources and can run with the AWS managed policies `SecurityAudit` or `ReadOnlyAccess`.
* **Dry run first.** Scripts that change resources only report what they *would* do, unless you set `DRY_RUN=false`.
* **Typed confirmation.** When applying changes, the script asks you to type a specific word before anything happens.
* **Sessions are checked.** Accounts without a valid SSO session are skipped with a clear message instead of failing halfway.
* **Reports stay local.** Reports go to `reports/`, which is ignored by git, because they may contain IDs, IPs, and user names.

---

#### 🗂️ Scripts Description

| Folder | Scripts | Type |
| --- | --- | --- |
| `security/` | CloudTrail logging, GuardDuty, open security groups, S3 Block Public Access, EBS default encryption, IAM access keys audit | Read-only (`SecurityAudit`) |
| `security/` | S3 versioning enforcement | Changes resources (dry run by default) |
| `inventory/` | EC2, Lambda, DocumentDB, Route 53, failed CloudFormation stacks, ENI lookup by IP | Read-only (`ReadOnlyAccess`) |
| `backup/` | Delete all or expired recovery points | Destructive (dry run by default) |
| `quotas/` | Request Service Quotas increases | Changes resources (dry run by default) |

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

> [!IMPORTANT]
> Always read a script before running it, and test changes in non-production accounts first.

---

#### ⚖️ Intellectual Property (IP) Notice

All source code and documentation in this repository are the exclusive Intellectual Property of the author. All rights reserved. Use of this content for academic or professional purposes must include proper citation and attribution.

**Copyright © 2026 [João Rafael](https://www.linkedin.com/in/jrafa1607/).**
