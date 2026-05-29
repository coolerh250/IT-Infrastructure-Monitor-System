# Data Redaction Policy

This repository is designed to publish reusable monitoring architecture, process, and configuration patterns. Before committing or pushing any generated artifact, redact sensitive information.

## Never commit

- Passwords, tokens, API keys, OAuth secrets, bearer tokens
- Grafana admin passwords, service account tokens, API keys, datasource credentials
- Prometheus bearer tokens, `basic_auth`, remote_write credentials, scrape tokens
- Alertmanager SMTP, webhook, Teams, Slack, Telegram, LINE, PagerDuty secrets
- `.env` files, private config files, generated secret files
- Backup encryption keys, GPG/age private keys, restic/borg passwords
- SSH private keys, sudo credentials, database connection strings with passwords
- TLS private keys, PKCS#12 bundles, internal CA signing keys
- Cloud credentials, kubeconfig files with embedded tokens

## Redact before committing

- Real internal IP addresses, management networks, VPN ranges, NAT mappings
- Real hostnames, FQDNs, AD domains, internal DNS zones
- Employee names, phone numbers, personal email addresses, on-call rosters
- Device serial numbers, asset tags, MAC addresses
- Exact vulnerability findings or incident details tied to internal systems

## Recommended placeholder patterns

| Real data type | Placeholder example |
|---|---|
| Internal CIDR | `10.0.0.0/24` or `192.0.2.0/24` |
| Hostname | `monitoring-01.example.internal` |
| Email | `admin@example.com` |
| Password | `${GRAFANA_ADMIN_PASSWORD}` |
| Token | `${GRAFANA_API_TOKEN}` |
| SMTP password | `${SMTP_PASSWORD}` |
| Backup key path | `/run/secrets/backup-encryption.key` |

## Required pre-push checklist

1. Run `git status --short` and review every staged file.
2. Run a secret scanner when available, for example `gitleaks detect --source . --no-git`.
3. Search for obvious sensitive strings before commit:
   - `password`, `token`, `secret`, `apikey`, `authorization`, `bearer`, `smtp`, `private_key`
4. Ensure all real environment files are ignored and only `.env.example` templates are committed.
5. Replace site-specific values with placeholders or documented variables.
6. If a secret was accidentally committed, rotate the secret and purge the commit history before pushing.
