#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/backup.sh [--dry-run]

Create an encrypted local backup of configuration and Docker volumes.
USAGE
}

log() {
  printf '[backup] %s\n' "$*"
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

backup_volume() {
  local volume="$1"
  local output_dir="$2"
  local archive_name="$3"

  run docker run --rm \
    -v "${volume}:/source:ro" \
    -v "${output_dir}:/backup" \
    alpine:3.20 \
    tar -czf "/backup/${archive_name}" -C /source .
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
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
  require_command openssl
  require_command tar

  local backup_dir retention_days passphrase_file project timestamp staging final_archive
  backup_dir="$(resolve_path "${BACKUP_DIR:-./backups}")"
  retention_days="${BACKUP_RETENTION_DAYS:-14}"
  passphrase_file="$(resolve_path "${BACKUP_PASSPHRASE_FILE:-./secrets/backup_passphrase}")"
  project="${COMPOSE_PROJECT_NAME:-it-monitor}"
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  staging="${backup_dir}/.staging-${timestamp}"
  final_archive="${backup_dir}/monitoring-backup-${timestamp}.tar.gz.enc"

  if [[ ! "$retention_days" =~ ^[0-9]+$ ]]; then
    printf 'BACKUP_RETENTION_DAYS must be a positive integer.\n' >&2
    exit 1
  fi
  if [[ ! -r "$passphrase_file" ]]; then
    printf 'Backup passphrase file is not readable: %s\n' "$passphrase_file" >&2
    exit 1
  fi

  run mkdir -p "$staging"
  run tar --exclude='./.git' --exclude='./backups' --exclude='./secrets' -czf "$staging/config.tar.gz" -C "$ROOT_DIR" .

  backup_volume "${project}_grafana-data" "$staging" grafana-data.tar.gz
  backup_volume "${project}_postgres-data" "$staging" postgres-data.tar.gz
  backup_volume "${project}_prometheus-data" "$staging" prometheus-data.tar.gz
  backup_volume "${project}_alertmanager-data" "$staging" alertmanager-data.tar.gz

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would encrypt backup to ${final_archive} and remove backups older than ${retention_days} days."
    return 0
  fi

  tar -czf - -C "$staging" . | openssl enc -aes-256-cbc -salt -pbkdf2 -pass "file:${passphrase_file}" -out "$final_archive"
  rm -rf "$staging"
  find "$backup_dir" -type f -name 'monitoring-backup-*.tar.gz.enc' -mtime "+${retention_days}" -delete
  log "Created encrypted backup: ${final_archive}"
}

main "$@"
