#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
FORCE=0
RESTORE_CONFIG=0

usage() {
  cat <<'USAGE'
Usage: scripts/restore.sh [--dry-run] [--force] [--restore-config] BACKUP_FILE

Restore encrypted backup data into Docker volumes. Use --restore-config to also
extract tracked configuration files into the workspace.
USAGE
}

log() {
  printf '[restore] %s\n' "$*"
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
  if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    . "$ROOT_DIR/.env"
    set +a
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$ROOT_DIR" "$path"
  fi
}

restore_volume() {
  local volume="$1"
  local archive_path="$2"

  run docker volume create "$volume" >/dev/null
  run docker run --rm \
    -v "${volume}:/target" \
    -v "$(dirname "$archive_path"):/backup:ro" \
    alpine:3.20 \
    sh -c "find /target -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar -xzf /backup/$(basename "$archive_path") -C /target"
}

main() {
  local backup_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --restore-config)
        RESTORE_CONFIG=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ -n "$backup_file" ]]; then
          printf 'Only one backup file may be provided.\n' >&2
          exit 2
        fi
        backup_file="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$backup_file" ]]; then
    usage >&2
    exit 2
  fi

  cd "$ROOT_DIR"
  load_env
  require_command docker
  require_command openssl
  require_command tar

  local passphrase_file project temp_dir
  backup_file="$(resolve_path "$backup_file")"
  passphrase_file="$(resolve_path "${BACKUP_PASSPHRASE_FILE:-./secrets/backup_passphrase}")"
  project="${COMPOSE_PROJECT_NAME:-it-monitor}"
  temp_dir="$(mktemp -d)"

  if [[ ! -r "$backup_file" ]]; then
    printf 'Backup file is not readable: %s\n' "$backup_file" >&2
    exit 1
  fi
  if [[ ! -r "$passphrase_file" ]]; then
    printf 'Backup passphrase file is not readable: %s\n' "$passphrase_file" >&2
    exit 1
  fi
  if [[ "$FORCE" -ne 1 ]]; then
    printf 'Restore overwrites monitoring Docker volumes. Re-run with --force to continue.\n' >&2
    exit 1
  fi

  trap 'rm -rf "$temp_dir"' EXIT

  if [[ "$DRY_RUN" -eq 0 ]]; then
    openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:${passphrase_file}" -in "$backup_file" | tar -xzf - -C "$temp_dir"
  else
    log "Would decrypt ${backup_file} into a temporary directory."
  fi

  run docker compose down
  restore_volume "${project}_grafana-data" "$temp_dir/grafana-data.tar.gz"
  restore_volume "${project}_postgres-data" "$temp_dir/postgres-data.tar.gz"
  restore_volume "${project}_prometheus-data" "$temp_dir/prometheus-data.tar.gz"
  restore_volume "${project}_alertmanager-data" "$temp_dir/alertmanager-data.tar.gz"

  if [[ "$RESTORE_CONFIG" -eq 1 ]]; then
    run tar -xzf "$temp_dir/config.tar.gz" -C "$ROOT_DIR"
  fi

  log "Restore completed. Run scripts/deploy.sh to start the stack."
}

main "$@"
