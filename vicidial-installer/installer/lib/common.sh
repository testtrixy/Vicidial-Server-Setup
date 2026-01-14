#!/usr/bin/env bash
# =============================================================================
# VICIDIAL 2026 – Common Installer Library
# Used by: install.sh and all stage scripts
# Scope: Logging, markers, safety, execution control
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Internal globals (set via init_installer)
# -----------------------------------------------------------------------------


: "${INSTALLER_ROOT:?INSTALLER_ROOT must be set by install.sh}"

LOG_DIR="${INSTALLER_ROOT}/logs"
MARKER_DIR="/var/lib/vicidial-install"
CURRENT_STAGE=""

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------


init_installer() {
  # ... existing logic ...
  [[ -n "$INSTALLER_ROOT" ]] || fatal "INSTALLER_ROOT not set"
  [[ -n "$LOG_DIR" ]] || fatal "LOG_DIR not set"

  # Ensure marker and log paths exist before any stage runs
  mkdir -p "$LOG_DIR"
  mkdir -p "$MARKER_DIR"
  
  # Export them so subshells (stages) see them
  export INSTALLER_ROOT LOG_DIR MARKER_DIR
}



init_installer() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) INSTALLER_ROOT="$2"; shift 2 ;;
      --logs) LOG_DIR="$2"; shift 2 ;;
      *)
        echo "ERROR: Unknown init_installer option: $1"
        exit 1
        ;;
    esac
  done

  [[ -n "$INSTALLER_ROOT" ]] || fatal "INSTALLER_ROOT not set"
  [[ -n "$LOG_DIR" ]] || fatal "LOG_DIR not set"


  # Ensure marker and log paths exist before any stage runs
  mkdir -p "$LOG_DIR"
  mkdir -p "$MARKER_DIR"
  
  # Export them so subshells (stages) see them
  export INSTALLER_ROOT LOG_DIR MARKER_DIR

}

# -----------------------------------------------------------------------------
# Logging helpers
# -----------------------------------------------------------------------------

_log() {
  local level="$1"
  local msg="$2"
  local color="$3"
  local reset="\e[0m"
  local bold="\e[1m"
  local ts
  
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  # Format the level to be exactly 7 characters for perfect vertical alignment
  local padded_level
  padded_level=$(printf "%-7s" "$level")

  # Print formatted output: [Timestamp] [LEVEL] Message
  echo -e "${bold}[${ts}]${reset} ${color}[${padded_level}]${reset} ${msg}"
}

# Define Colors
C_INFO="\e[34m"    # Blue
C_WARN="\e[33m"    # Yellow
C_ERROR="\e[31m"   # Red
C_SUCCESS="\e[32m" # Green

log_info()    { _log "INFO"    "$1" "$C_INFO"; }
log_warn()    { _log "WARN"    "$1" "$C_WARN"; }
log_error()   { _log "ERROR"   "$1" "$C_ERROR"; }
log_success() { _log "SUCCESS" "$1" "$C_SUCCESS"; }

fatal() {
  log_error "$1"
  exit 1
}

# -----------------------------------------------------------------------------
# Safety checks
# -----------------------------------------------------------------------------
require_root() {
  [[ $EUID -eq 0 ]] || fatal "Must be run as root"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command missing: $1"
}

require_file() {
  [[ -f "$1" ]] || fatal "Required file missing: $1"
}

require_dir() {
  [[ -d "$1" ]] || fatal "Required directory missing: $1"
}

# -----------------------------------------------------------------------------
# Marker handling (idempotency & resume)
# -----------------------------------------------------------------------------
stage_name() {
  basename "$1" .sh
}

marker_path() {
  echo "${MARKER_DIR}/$(stage_name "$1").done"
}

is_stage_complete() {
  [[ -f "$(marker_path "$1")" ]]
}

mark_stage_complete() {
  touch "$(marker_path "$1")"
}

# -----------------------------------------------------------------------------
# Stage execution
# -----------------------------------------------------------------------------
run_stage() {
  local stage="$1"
  local name
  local logfile

  name="$(stage_name "$stage")"
  logfile="${LOG_DIR}/${name}.log"

  require_file "$stage"

  if is_stage_complete "$stage"; then
    log_info "Skipping ${name} (already completed)"
    return 0
  fi

  log_info "Starting stage: ${name}"
  log_info "Logging to: ${logfile}"

  (
    set -euo pipefail
    CURRENT_STAGE="$name"
    source "$stage"
  ) > >(tee -a "$logfile") 2>&1

  mark_stage_complete "$stage"
  log_success "Stage completed: ${name}"
}

# -----------------------------------------------------------------------------
# Environment helpers (used by stages)
# -----------------------------------------------------------------------------
require_rebooted_if_needed() {
  # Explicit reboot marker (authoritative)
  
  if [[ -f /var/lib/vicidial-install/reboot_required ]]; then
    fatal "System reboot required before continuing installation."
  fi

  # SELinux sanity (defensive)
  if command -v sestatus >/dev/null 2>&1; then
    if sestatus | grep -q "enabled"; then
      fatal "SELinux still enabled. Reboot required before continuing."
    fi
  fi
}

# -----------------------------------------------------------------------------
# End of common.sh
# -----------------------------------------------------------------------------
