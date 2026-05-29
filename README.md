# IT Infrastructure Monitor System

Docker Compose based monitoring stack for Ubuntu hosts. The stack includes:

- Prometheus
- Grafana
- PostgreSQL for Grafana metadata
- Alertmanager with email notifications
- Blackbox Exporter
- Node Exporter

This repository is intended to make the current monitoring environment repeatable on a new Ubuntu/Docker host without committing secrets or internal personal data.

## Quick Start

1. Install Docker Engine with the Compose plugin on Ubuntu.
2. Copy `.env.example` to `.env`.
3. Replace placeholder values in `.env`. Do not commit `.env`.
4. Put SMTP and backup encryption secrets in local files outside git, for example under `./secrets/`.
5. Validate configuration:

   ```bash
   ./scripts/validate.sh
   ```

6. Deploy:

   ```bash
   ./scripts/deploy.sh
   ```

Grafana is exposed on `${GRAFANA_PORT:-3000}` and Prometheus is exposed on `${PROMETHEUS_PORT:-9090}`. Management access should be restricted to `${MANAGEMENT_CIDR:-10.0.1.0/24}` by host firewall rules; see [docs/security.md](docs/security.md).

## Required Local Secret Files

The stack reads secrets from files that are intentionally not tracked:

- `GRAFANA_ADMIN_PASSWORD_FILE`
- `POSTGRES_PASSWORD_FILE`
- `SMTP_PASSWORD_FILE`
- `BACKUP_PASSPHRASE_FILE`

Each file should contain exactly one secret value. Example paths are documented in `.env.example`.

## Operations

- Deployment guide: [docs/deployment.md](docs/deployment.md)
- Backup, restore, and routine operations: [docs/operations.md](docs/operations.md)
- Security controls and secret handling: [docs/security.md](docs/security.md)

## Validation

Run the local validation helper before deployment or after edits:

```bash
./scripts/validate.sh
```

It performs shell syntax checks and, when Docker Compose is available, validates the Compose model.


## First monitored host

The first real monitored Ubuntu host is `hermesAI` (`10.0.1.40`). Host-side setup and monitoring scope are documented in [docs/ubuntu-host-monitoring.md](docs/ubuntu-host-monitoring.md).
