#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Vicidial EL9 Installer – Role-Aware Orchestrator
###############################################################################

INSTALLER_ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE_DIR="${INSTALLER_ROOT}/stages"

NODE_ROLE="${NODE_ROLE:-}"

usage() {
  cat <<EOF
Usage:
  NODE_ROLE=<role> ./install.sh

Valid NODE_ROLE values:
  db         Database node (MariaDB + schema)
  telephony  Dialer / Asterisk node
  web        Web UI node
  all        All-in-one (DEV / LAB ONLY)

Example:
  NODE_ROLE=db ./install.sh
EOF
  exit 1
}

[[ -z "${NODE_ROLE}" ]] && usage

run_stage() {
  local stage="$1"
  echo
  echo "============================================================"
  echo ">>> Running stage: ${stage}"
  echo "============================================================"
  bash "${STAGE_DIR}/${stage}"
}

case "${NODE_ROLE}" in
  db)
    run_stage 01_os_base.sh
    run_stage 02_web_db.sh
    run_stage 03_db_init.sh
    run_stage 05_vicidial_core.sh
    run_stage health/healthcheck.sh
    ;;
  telephony)
    run_stage 01_os_base.sh
    run_stage 02b_db_client.sh
    run_stage 04_telephony.sh
    run_stage 05_vicidial_core.sh
    run_stage health/healthcheck.sh
    ;;
  web)
    run_stage 01_os_base.sh
    run_stage 02b_db_client.sh
    run_stage 05_vicidial_core.sh
    run_stage health/healthcheck.sh
    ;;
  all)
    echo "[WARN] All-in-one mode is for DEV/LAB only"
    run_stage 01_os_base.sh
    run_stage 02_web_db.sh
    run_stage 03_db_init.sh
    run_stage 04_telephony.sh
    run_stage 05_vicidial_core.sh
    run_stage health/healthcheck.sh
    ;;
  *)
    echo "ERROR: Invalid NODE_ROLE '${NODE_ROLE}'"
    usage
    ;;
esac

echo
echo "============================================================"
echo "Vicidial installation completed for role: ${NODE_ROLE}"
echo "============================================================"
exit 0
