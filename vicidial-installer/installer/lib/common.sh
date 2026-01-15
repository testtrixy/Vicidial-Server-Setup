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
  # Ensure required globals are present
  [[ -n "$INSTALLER_ROOT" ]] || fatal "INSTALLER_ROOT not set"
  [[ -n "$LOG_DIR" ]] || fatal "LOG_DIR not set"

  # Ensure marker and log paths exist
  mkdir -p "$LOG_DIR"
  mkdir -p "$MARKER_DIR"

  # Export for subshells
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

# -----------------------------------------------------------------------------
# Stage marker helpers (EL9-Golden)
# -----------------------------------------------------------------------------


ensure_marker_dir() {
  mkdir -p "${MARKER_DIR}"
}

stage_begin() {
  local stage="$1"
  local marker="${MARKER_DIR}/${stage}.done"

  ensure_marker_dir

  if [[ -f "${marker}" ]]; then
    log "Stage ${stage} already completed – skipping"
    exit 0
  fi

  log "Starting stage: ${stage}"
}

stage_finish() {
  local stage="$1"
  local marker="${MARKER_DIR}/${stage}.done"

  touch "${marker}"
  log "Stage ${stage} completed successfully"
}




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
  export CURRENT_STAGE="$name"
  
}



require_vars() {
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Required variable not set: $var"
      return 1
    fi
  done
}
# -----------------------------------------------------------------------------
# Environment helpers (used by stages)
# -----------------------------------------------------------------------------

require_rebooted_if_needed() {
  # 1. Explicit reboot marker (source of truth)
  if [[ -f /var/lib/vicidial-install/reboot_required ]]; then
    fatal "Reboot required. Please reboot the system and re-run install.sh"
  fi

  # 2. Defensive SELinux verification (backup safety net)
  if command -v getenforce >/dev/null 2>&1; then
    if [[ "$(getenforce)" != "Disabled" ]]; then
      fatal "SELinux is not disabled. Reboot required before continuing."
    fi
  fi
}

# -----------------------------------------------------------------------------
# End of common.sh
# -----------------------------------------------------------------------------

#!/usr/bin/env bash
set -euo pipefail

#############################################
# EL9 Vicidial – Common Functions
# Authoritative for Rocky / Alma Linux 9
#############################################

log() {
  echo -e "[INFO] $*"
}

fail() {
  echo -e "[FATAL] $*" >&2
  exit 1
}

#############################################
# OS & Platform Guard
#############################################
check_el9() {
  if ! grep -qE 'Rocky Linux 9|AlmaLinux 9' /etc/os-release; then
    fail "Unsupported OS. This installer is EL9-only."
  fi
  log "EL9 OS detected"
}

#############################################
# MariaDB Server Check
#############################################
check_mariadb_service() {
  if ! systemctl is-active --quiet mariadb; then
    fail "MariaDB service is not running"
  fi
  log "MariaDB service is running"
}

#############################################
# Perl + DBI + DBD::MariaDB Check
#############################################
check_perl_db_stack() {
  log "Checking Perl DBI stack..."

  perl -MDBI -e 'exit' 2>/dev/null \
    || fail "Perl DBI missing (install perl-DBI)"

  perl -MDBD::MariaDB -e 'exit' 2>/dev/null \
    || fail "Perl DBD::MariaDB missing (install perl-DBD-MariaDB)"

  log "Perl DBI + DBD::MariaDB OK"
}

#############################################
# Detect MariaDB Socket Dynamically
#############################################
get_mariadb_socket() {
  local socket

  socket=$(mysql -e "SHOW VARIABLES LIKE 'socket';" \
           -s --skip-column-names 2>/dev/null | awk '{print $2}')

  if [[ -z "${socket}" ]]; then
    fail "Unable to detect MariaDB socket"
  fi

  if [[ ! -S "${socket}" ]]; then
    fail "MariaDB socket not found at ${socket}"
  fi

  echo "${socket}"
}

#############################################
# DBI Connectivity Test (Authoritative)
#############################################
check_dbi_connection() {
  local socket
  socket="$(get_mariadb_socket)"

  log "Testing DBI connectivity via socket ${socket}"

  perl -MDBI -e "
    DBI->connect(
      'DBI:MariaDB:database=mysql;host=localhost;mariadb_socket=${socket}',
      'root',''
    ) or die \$DBI::errstr;
  " 2>/dev/null \
    || fail "DBI connection test failed"

  log "DBI CONNECT OK"
}

#############################################
# Composite Preflight (Call This in Stages)
#############################################
db_preflight() {
  check_el9
  check_mariadb_service
  check_perl_db_stack
  check_dbi_connection
}
