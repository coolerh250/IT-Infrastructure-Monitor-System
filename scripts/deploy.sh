#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
SKIP_VALIDATE=0

usage() {
  cat <<'USAGE'
Usage: scripts/deploy.sh [--dry-run] [--skip-validate]

Deploy the monitoring stack with Docker Compose.

Environment:
  UFW_MANAGE=1  Apply UFW allow rules for MANAGEMENT_CIDR and service ports.
USAGE
}

log() {
  printf '[deploy] %s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

load_env() {
  if [[ ! -f "$ROOT_DIR/.env" ]]; then
    printf 'Missing .env. Copy .env.example to .env and set local values.\n' >&2
    exit 1
  fi

  set -a
  # shellcheck source=/dev/null
  . "$ROOT_DIR/.env"
  set +a
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_secret_file() {
  local name="$1"
  local path="${!name:-}"
  if [[ -z "$path" || ! -r "$ROOT_DIR/$path" && ! -r "$path" ]]; then
    printf 'Secret file %s is not readable. Current value: %s\n' "$name" "${path:-unset}" >&2
    exit 1
  fi
}

apply_firewall_rules() {
  local cidr="${MANAGEMENT_CIDR:-10.0.1.0/24}"
  local grafana_port="${GRAFANA_PORT:-3000}"
  local prometheus_port="${PROMETHEUS_PORT:-9090}"
  local alertmanager_port="${ALERTMANAGER_PORT:-9093}"

  if [[ "${UFW_MANAGE:-0}" != "1" ]]; then
    log "UFW_MANAGE is not 1; ensure host firewall allows only ${cidr} to ports ${grafana_port}, ${prometheus_port}, ${alertmanager_port}."
    return 0
  fi

  require_command ufw
  run sudo ufw allow from "$cidr" to any port "$grafana_port" proto tcp
  run sudo ufw allow from "$cidr" to any port "$prometheus_port" proto tcp
  run sudo ufw allow from "$cidr" to any port "$alertmanager_port" proto tcp
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --skip-validate)
        SKIP_VALIDATE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  cd "$ROOT_DIR"
  load_env
  require_command docker
  require_secret_file GRAFANA_ADMIN_PASSWORD_FILE
  require_secret_file POSTGRES_PASSWORD_FILE
  require_secret_file SMTP_PASSWORD_FILE

  if [[ "$SKIP_VALIDATE" -eq 0 ]]; then
    run "$ROOT_DIR/scripts/validate.sh"
  fi

  apply_firewall_rules
  run docker compose up -d
  log "Deployment command completed."
}

main "$@"
