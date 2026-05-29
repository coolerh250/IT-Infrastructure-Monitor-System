# IT Infrastructure Monitor System

Reusable source-control repository for an automated IT infrastructure monitoring system.

## Purpose

This repository is intended to preserve reusable architecture, procedures, deployment templates, and sanitized configuration examples for building an automated monitoring mechanism based on components such as Grafana, Prometheus, Alertmanager, exporters, backup/restore scripts, and AI-friendly operational runbooks.

## Security rule

Do **not** commit production secrets or personally identifiable/internal-only information.

Use placeholders and examples instead of real values, for example:

- `10.0.0.0/24` or `192.0.2.0/24` instead of real internal networks
- `monitoring.example.internal` instead of real hostnames/FQDNs
- `admin@example.com` instead of real employee email addresses
- `${GRAFANA_ADMIN_PASSWORD}` instead of actual passwords
- `${SMTP_PASSWORD}` instead of actual SMTP credentials

See `docs/data-redaction-policy.md` before adding deployment outputs or configuration snapshots.
