#!/usr/bin/env bash
set -Eeuo pipefail

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
LISTEN_ADDRESS="${NODE_EXPORTER_LISTEN_ADDRESS:-10.0.1.40:9100}"
TEXTFILE_DIR="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
PROMETHEUS_SOURCE_IP="${PROMETHEUS_SOURCE_IP:-10.0.1.50}"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/install-node-exporter-ubuntu.sh [--dry-run]

Install node_exporter as a locked-down systemd service on Ubuntu.
Environment overrides:
  NODE_EXPORTER_VERSION       default: 1.8.2
  NODE_EXPORTER_LISTEN_ADDRESS default: 10.0.1.40:9100
  NODE_EXPORTER_TEXTFILE_DIR  default: /var/lib/node_exporter/textfile_collector
  PROMETHEUS_SOURCE_IP        default: 10.0.1.50
USAGE
}

log() { printf '[node-exporter-install] %s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %q ' "$@"; printf '\n'; return 0
  fi
  "$@"
}
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf 'This installer must run as root, for example: sudo %s\n' "$0" >&2
    exit 1
  fi
}
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
  done

  if [[ "$DRY_RUN" -eq 0 ]]; then
    require_root
  fi
  require_command curl
  require_command tar
  require_command install

  local arch url tmpdir tarball extracted
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
  esac

  url="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${arch}.tar.gz"
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT
  tarball="${tmpdir}/node_exporter.tar.gz"
  extracted="${tmpdir}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${arch}"

  run curl -fsSL "$url" -o "$tarball"
  run tar -xzf "$tarball" -C "$tmpdir"

  if ! id node_exporter >/dev/null 2>&1; then
    run useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
  fi

  run install -o root -g root -m 0755 "${extracted}/node_exporter" /usr/local/bin/node_exporter
  run install -o node_exporter -g node_exporter -m 0755 -d "$TEXTFILE_DIR"

  run tee /etc/systemd/system/node_exporter.service >/dev/null <<SERVICE
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=${LISTEN_ADDRESS} \
  --collector.systemd \
  --collector.processes \
  --collector.textfile.directory=${TEXTFILE_DIR}
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
ReadWritePaths=${TEXTFILE_DIR}
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
LockPersonality=true
MemoryDenyWriteExecute=true
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

  if command -v ufw >/dev/null 2>&1; then
    run ufw allow from "$PROMETHEUS_SOURCE_IP" to any port 9100 proto tcp
  else
    log 'ufw not installed; apply equivalent host/network firewall rule manually.'
  fi

  run systemctl daemon-reload
  run systemctl enable --now node_exporter
  run systemctl status node_exporter --no-pager
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry-run completed for node_exporter on ${LISTEN_ADDRESS}; allow only ${PROMETHEUS_SOURCE_IP} to TCP/9100."
  else
    log "node_exporter installed on ${LISTEN_ADDRESS}; allow only ${PROMETHEUS_SOURCE_IP} to TCP/9100."
  fi
}

main "$@"
