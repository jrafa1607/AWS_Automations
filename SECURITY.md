# Security Policy ( Recommendations )

## Reporting a vulnerability

If you find a security issue in these scripts (for example, a command that could change resources in dry-run mode, leak data into reports, or run unexpected input), please **do not open a public issue**. Use GitHub's [private vulnerability reporting](https://github.com/jrafa1607/AWS_Automations/security/advisories/new) instead.

Please include the script name, the steps to reproduce, and the impact. You will receive an answer within 7 days.

## Safe use

* Run the read-only checks with the AWS managed policy `SecurityAudit` or `ReadOnlyAccess`.
* Run scripts that change resources only with a separate, time-bound permission set, in dry-run mode first.
* Never commit the `accounts` file or the `reports/` folder; both are ignored by git.
* Only run these scripts against accounts you own or are authorized to assess.
