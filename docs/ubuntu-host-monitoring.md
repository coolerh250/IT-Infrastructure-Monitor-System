# Ubuntu Host Monitoring: hermesAI / 10.0.1.40

This runbook adds the Ubuntu host `hermesAI` (`10.0.1.40`) as the first real monitored Linux host.

## Required permissions on 10.0.1.40

Installation requires temporary root/sudo access to:

- create the locked-down `node_exporter` system account;
- install `/usr/local/bin/node_exporter`;
- create `/etc/systemd/system/node_exporter.service`;
- create `/var/lib/node_exporter/textfile_collector`;
- allow the Prometheus host to TCP/9100 in the host firewall;
- enable and start the systemd service.

The running service does not require sudo, shell login, SSH credentials, or write access outside the textfile collector directory.

## Network access

Allow only the Prometheus / blackbox-exporter host to access:

| Direction | Protocol | Purpose |
|---|---:|---|
| Prometheus -> 10.0.1.40:9100 | TCP | node_exporter scrape |
| blackbox-exporter -> 10.0.1.40 | ICMP echo | host reachability |
| blackbox-exporter -> 10.0.1.40:22 | TCP | SSH port availability probe only |

The default installer assumes the Prometheus source IP is `10.0.1.50`. Override with `PROMETHEUS_SOURCE_IP=<ip>` if needed.

## Install node_exporter

Run on `10.0.1.40` with root privileges:

```bash
sudo PROMETHEUS_SOURCE_IP=10.0.1.50 ./scripts/install-node-exporter-ubuntu.sh
```

Dry-run:

```bash
sudo ./scripts/install-node-exporter-ubuntu.sh --dry-run
```

## Prometheus targets

The repository includes:

- `prometheus/file_sd/node_targets.yml` for `10.0.1.40:9100`;
- `prometheus/file_sd/icmp_targets.yml` for ICMP reachability;
- `prometheus/file_sd/tcp_targets.yml` for SSH TCP connect reachability.

## Alert coverage

`prometheus/rules/ubuntu_host.yml` covers:

- host exporter down;
- ICMP down;
- SSH unavailable;
- high CPU;
- high memory;
- low disk;
- low inode availability;
- network errors;
- clock skew;
- reboot detected.

High-severity alerts follow the existing Alertmanager policy and continue to be sent outside business hours. Warning alerts are business-hours only.

## Verification

From the monitored host:

```bash
systemctl status node_exporter --no-pager
ss -lntp | grep ':9100'
curl -fsS http://10.0.1.40:9100/metrics | head
```

From the Prometheus host:

```bash
curl -fsS http://10.0.1.40:9100/metrics | head
curl -fsS 'http://127.0.0.1:9090/api/v1/targets'
```
