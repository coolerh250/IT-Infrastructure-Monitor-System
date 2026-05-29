# Deployment Guide

This guide deploys the monitoring stack to a new Ubuntu host with Docker Engine and the Docker Compose plugin.

## Prerequisites

- Ubuntu server with Docker Engine and the Compose plugin installed.
- DNS or hostnames for the systems to monitor.
- Node Exporter installed on monitored Linux hosts, or network access to existing Node Exporter endpoints.
- SMTP account for Alertmanager email delivery.
- Local secret files for Grafana, PostgreSQL, SMTP, and backup encryption.

## Configure Environment

Create a local environment file:

```bash
cp .env.example .env
```

Edit `.env` and replace placeholders. Set `ALERT_EMAIL_TO` to the approved operational recipient for the deployment site. Keep `MANAGEMENT_CIDR=10.0.1.0/24` unless the allowed management network is different.

Create local secret files. Example:

```bash
mkdir -p secrets
printf 'replace-with-strong-grafana-password\n' > secrets/grafana_admin_password
printf 'replace-with-strong-postgres-password\n' > secrets/postgres_password
printf 'replace-with-smtp-password\n' > secrets/smtp_password
printf 'replace-with-backup-passphrase\n' > secrets/backup_passphrase
chmod 600 secrets/*
```

Do not commit the `secrets/` directory.

## Configure Targets

The initial target examples represent three monitored hosts:

- `prometheus/file_sd/node_targets.yml`
- `prometheus/file_sd/http_targets.yml`

Replace `192.0.2.10`, `192.0.2.11`, and `192.0.2.12` with site-specific addresses or hostnames. Replace `.invalid` HTTP examples with real service health URLs.

## Validate

```bash
./scripts/validate.sh
```

This checks shell syntax and runs `docker compose config` when the Compose plugin is available.

## Deploy

```bash
./scripts/deploy.sh
```

To preview actions:

```bash
./scripts/deploy.sh --dry-run
```

If the host uses UFW and you want the script to add allow rules from the management CIDR:

```bash
UFW_MANAGE=1 ./scripts/deploy.sh
```

The script does not add deny rules. Confirm the host firewall policy blocks unwanted sources from Grafana, Prometheus, and Alertmanager.
