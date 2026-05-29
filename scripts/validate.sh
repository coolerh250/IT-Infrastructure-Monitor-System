#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '[validate] %s\n' "$*"
}

main() {
  cd "$ROOT_DIR"

  log "Checking shell syntax."
  bash -n scripts/*.sh

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Checking Docker Compose configuration."
    docker compose config >/dev/null
  else
    log "Docker Compose is not available; skipping compose config validation."
  fi

  log "Validation completed."
}

main "$@"
