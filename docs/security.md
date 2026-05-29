# Security Guide

## Secret Handling

Never commit real passwords, tokens, PATs, SMTP passwords, or backup passphrases. This repository tracks only placeholders and examples.

Use local secret files referenced by `.env`:

- `GRAFANA_ADMIN_PASSWORD_FILE`
- `POSTGRES_PASSWORD_FILE`
- `SMTP_PASSWORD_FILE`
- `BACKUP_PASSPHRASE_FILE`

Set permissions so only the deployment operator can read them:

```bash
chmod 600 secrets/*
```

## Network Access

The default management source network is `10.0.1.0/24` through `MANAGEMENT_CIDR`. Override it in `.env` for each site.

Grafana, Prometheus, and Alertmanager expose ports for management use. Restrict these ports at the host firewall or upstream network firewall. The deploy script can add UFW allow rules when `UFW_MANAGE=1`, but it does not enforce a complete deny policy.

## Example Values

Documentation and sample target files use reserved example IP ranges and `.invalid` names. Replace them with local values during deployment, but do not commit internal CIDRs, personal data, or private hostnames unless the repository policy allows it.

## Backup Encryption

Backups are encrypted locally with OpenSSL AES-256-CBC and PBKDF2. Store `BACKUP_PASSPHRASE_FILE` outside git and back it up through an approved secret-management process. Without that passphrase, encrypted backups cannot be restored.

## Email

Alertmanager reads the SMTP password from `SMTP_PASSWORD_FILE`. The repository must never contain the real SMTP password.
