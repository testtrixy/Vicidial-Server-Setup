#!/usr/bin/env bash
# =============================================================================
# VICIDIAL 2026 – MASTER INSTALLER
# Phase 0: Orchestration Only
# Architecture: MASTER.md (LOCKED)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 1. Resolve installer root (absolute, symlink-safe)
# -----------------------------------------------------------------------------
INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# 2. Core paths (DO NOT hardcode elsewhere)
# -----------------------------------------------------------------------------
CONFIG_DIR="${INSTALLER_ROOT}/config"
LIB_DIR="${INSTALLER_ROOT}/lib"
STAGES_DIR="${INSTALLER_ROOT}/stages"
LOG_DIR="${INSTALLER_ROOT}/logs"

# -----------------------------------------------------------------------------
# 3. Sanity checks (Phase 0 responsibility)
# -----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Installer must be run as root"
  exit 1
fi

for dir in "$CONFIG_DIR" "$LIB_DIR" "$STAGES_DIR"; do
  [[ -d "$dir" ]] || {
    echo "ERROR: Required directory missing: $dir"
    exit 1
  }
done

# -----------------------------------------------------------------------------
# 4. Load configuration (order matters)
# -----------------------------------------------------------------------------
source "${CONFIG_DIR}/versions.env"
source "${CONFIG_DIR}/paths.env"
source "${CONFIG_DIR}/secrets.env"

# -----------------------------------------------------------------------------
# Global configuration
# -----------------------------------------------------------------------------
source "${CONFIG_DIR}/versions.env"
source "${CONFIG_DIR}/paths.env"
source "${CONFIG_DIR}/secrets.env"

# Optional feature flags (safe defaults)
if [[ -f "${CONFIG_DIR}/features.env" ]]; then
  source "${CONFIG_DIR}/features.env"
else
  echo "[WARN] config/features.env not found – optional features disabled"
fi

# -----------------------------------------------------------------------------
# 5. Load shared libraries
# -----------------------------------------------------------------------------
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/render.sh"

# -----------------------------------------------------------------------------
# 6. Initialize installer context
# -----------------------------------------------------------------------------
init_installer \
  --root "${INSTALLER_ROOT}" \
  --logs "${LOG_DIR}"

log_info "Vicidial 2026 Master Installer started"
log_info "Installer root: ${INSTALLER_ROOT}"

# -----------------------------------------------------------------------------
# 7. Stage execution (Phase 1 entry point)
# -----------------------------------------------------------------------------
for stage in "${STAGES_DIR}"/[0-9][0-9]_*.sh; do
  run_stage "${stage}"
done

# -----------------------------------------------------------------------------
# 8. Phase 2 – Health checks
# -----------------------------------------------------------------------------
if [[ -x "${INSTALLER_ROOT}/health/healthcheck.sh" ]]; then
  log_info "Running health checks"
  "${INSTALLER_ROOT}/health/healthcheck.sh"
else
  log_warn "Health check script not found or not executable"
fi

# -----------------------------------------------------------------------------
# 9. Completion
# -----------------------------------------------------------------------------
log_success "Vicidial installation completed successfully"
exit 0
