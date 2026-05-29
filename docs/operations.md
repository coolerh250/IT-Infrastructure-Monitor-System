# Operations Guide

## Backup

Backups are local, encrypted, and retained for 14 days by default.

```bash
./scripts/backup.sh
```

The script creates `monitoring-backup-YYYYMMDDTHHMMSSZ.tar.gz.enc` under `BACKUP_DIR`, encrypting with AES-256-CBC and PBKDF2 using `BACKUP_PASSPHRASE_FILE`.

Preview without writing:

```bash
./scripts/backup.sh --dry-run
```

## Restore

Restores overwrite monitoring Docker volumes, so `--force` is required.

```bash
./scripts/restore.sh --force backups/monitoring-backup-YYYYMMDDTHHMMSSZ.tar.gz.enc
./scripts/deploy.sh
```

To also restore repository configuration files from the archive:

```bash
./scripts/restore.sh --force --restore-config backups/monitoring-backup-YYYYMMDDTHHMMSSZ.tar.gz.enc
```

## Target Changes

Update file service discovery files and reload Prometheus:

```bash
docker compose exec prometheus wget -qO- --post-data='' http://localhost:9090/-/reload
```

You can also restart Prometheus:

```bash
docker compose restart prometheus
```

## Alert Routing

Email notifications are sent to `ALERT_EMAIL_TO`. Set this value in the local `.env` file to the operational recipient approved for the deployment site.

Severity routing:

- High and critical alerts send at all times.
- Warning and info alerts send only Monday to Friday, 09:00 to 18:00 in the Alertmanager container timezone.

## Routine Checks

Use these commands during operations:

```bash
docker compose ps
docker compose logs --tail=100 prometheus
docker compose logs --tail=100 alertmanager
docker compose logs --tail=100 grafana
./scripts/validate.sh
```
