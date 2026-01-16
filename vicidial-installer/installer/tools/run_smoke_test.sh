#!/usr/bin/env bash
# =============================================================================
# Vicidial EL9 Full Smoke Test Wrapper
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SERVER_IP="${SERVER_IP:-}"
AUTO_CLEANUP="${AUTO_CLEANUP:-yes}"

usage() {
  echo "Usage:"
  echo "  SERVER_IP=x.x.x.x ./run_smoke_test.sh"
  echo
  echo "Optional:"
  echo "  AUTO_CLEANUP=no   (keep smoke data)"
  exit 1
}

[[ -z "${SERVER_IP}" ]] && usage

echo "============================================================"
echo " Vicidial EL9 End-to-End Smoke Test"
echo " Server IP : ${SERVER_IP}"
echo "============================================================"

echo
echo ">>> Phase 1: Backend / Telephony / Web Validation"
bash "${SCRIPT_DIR}/smoke_vicidial_v1.9.sh" \
  || { echo "❌ Backend smoke test FAILED"; exit 1; }

echo
echo ">>> Phase 2: Agent Login & Call Validation (Selenium)"
python3 "${SCRIPT_DIR}/smoke_login_test.py" "${SERVER_IP}" \
  || { echo "❌ Selenium smoke test FAILED"; exit 2; }

if [[ "${AUTO_CLEANUP}" == "yes" ]]; then
  echo
  echo ">>> Phase 3: Cleanup"
  bash "${SCRIPT_DIR}/smoke_cleanup_v1.9.sh" || true
fi

echo
echo "============================================================"
echo " 🎉 FULL SMOKE TEST PASSED – SYSTEM IS PRODUCTION READY"
echo "============================================================"
exit 0
