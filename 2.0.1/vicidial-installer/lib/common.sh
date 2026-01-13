#!/usr/bin/env bash

LOG_FILE="/var/log/vicidial-install.log"
STATE_DIR="/var/lib/vicidial"
STATE_FILE="$STATE_DIR/install.state"

mkdir -p "$STATE_DIR"
touch "$STATE_FILE"
touch "$LOG_FILE"

log() {
  local level="$1"; shift
  echo "[$(date '+%F %T')] [$level] $*" | tee -a "$LOG_FILE"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log ERROR "Run as root"
    exit 1
  fi
}

run_stage() {
  local stage="$1"
  if state_done "$stage"; then
    log INFO "Skipping $stage (already completed)"
    return
  fi

  log INFO "Running stage: $stage"
  bash "$INSTALL_ROOT/stages/$stage.sh"
  state_mark_done "$stage"
}
