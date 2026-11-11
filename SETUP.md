### 🛠️ Setup Guide

The scripts use the **AWS CLI v2** with **AWS IAM Identity Center (SSO)** credentials. Each AWS account is reached through a named CLI profile, and the scripts loop over the profiles listed in a local `accounts` file.

---

#### 1. Install the tools

* **AWS CLI v2:** [Installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* **Bash 3.2 or later:** available on Linux, macOS, WSL, and AWS CloudShell
* After cloning, make the scripts executable if needed: `chmod +x */*.sh`

#### 2. Create a permission set for the checks

In IAM Identity Center, assign a permission set with the least privilege the scripts need:

| Use | Recommended policy |
| --- | --- |
| Security checks (`security/`, read-only scripts) | AWS managed policy `SecurityAudit` |
| Inventory (`inventory/`) | AWS managed policy `ReadOnlyAccess` |
| Changes (`enforce_s3_versioning.sh`, `backup/`, `quotas/`) | A separate, time-bound permission set with only the actions listed in each script header |

Keeping the change permissions in a **separate permission set** means the day-to-day checks can never modify anything by accident.

#### 3. Configure the CLI profiles

Follow the official guide: [Configure the AWS CLI with IAM Identity Center](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html). The recommended format uses one `sso-session` shared by all profiles, so a single login covers every account.

**Example: `~/.aws/config`**

```ini
[sso-session my-sso]
sso_start_url = https://<your-portal>.awsapps.com/start
sso_region = <identity-center-region>
sso_registration_scopes = sso:account:access

[profile security-audit-prod]
sso_session = my-sso
sso_account_id = <account-id>
sso_role_name = SecurityAudit
region = us-east-1
output = json

[profile security-audit-dev]
sso_session = my-sso
sso_account_id = <account-id>
sso_role_name = SecurityAudit
region = us-east-1
output = json
```

#### 4. Create the `accounts` file

Copy the example and list one profile per line, using the same names as in `~/.aws/config`:

```bash
cp accounts.example accounts
```

```text
security-audit-prod
security-audit-dev
```

The `accounts` file is ignored by git, so your account profile names are never published.

---

#### 🔐 Authentication and Execution

Log in once per SSO session. The command opens the browser and stores a temporary credential in the local cache:

```bash
aws sso login --sso-session my-sso
```

Then run any script from the repository root:

```bash
./security/check_cloudtrail_status.sh
```

If a session expires during a run, the affected accounts are skipped with a message asking you to log in again.

---

#### 📄 Reports

Each script writes a timestamped CSV file to `reports/` (for example, `reports/open_security_groups_20261111_101500.csv`). Reports may contain account IDs, IPs, and user names: keep them local and share them only through approved channels.
