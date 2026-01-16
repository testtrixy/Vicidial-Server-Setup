#!/usr/bin/env bash
# =============================================================================
# Vicidial EL9 Full Smoke Test Wrapper (FINAL)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SERVER_IP="${SERVER_IP:-}"
AUTO_CLEANUP="${AUTO_CLEANUP:-yes}"
ENABLE_SELENIUM="${ENABLE_SELENIUM:-yes}"
HEADLESS="${HEADLESS:-yes}"

usage() {
  echo "Usage:"
  echo "  SERVER_IP=x.x.x.x ./run_smoke_test.sh"
  echo
  echo "Optional:"
  echo "  ENABLE_SELENIUM=yes|no"
  echo "  HEADLESS=yes|no"
  echo "  AUTO_CLEANUP=yes|no"
  exit 1
}

[[ -z "${SERVER_IP}" ]] && usage

echo "============================================================"
echo " Vicidial EL9 End-to-End Smoke Test"
echo " Server IP        : ${SERVER_IP}"
echo " Selenium Enabled : ${ENABLE_SELENIUM}"
echo " Headless Mode    : ${HEADLESS}"
echo " Auto Cleanup     : ${AUTO_CLEANUP}"
echo "============================================================"

# -----------------------------------------------------------------------------
# Phase 1: Backend / Telephony / Web Validation
# -----------------------------------------------------------------------------
echo
echo ">>> Phase 1: Backend / Telephony / Web Validation"

bash "${SCRIPT_DIR}/smoke_vicidial_v2.0_hardened.sh" \
  || { echo "❌ Phase 1 FAILED"; exit 1; }

# -----------------------------------------------------------------------------
# Phase 2: Selenium Dependency Preflight
# -----------------------------------------------------------------------------
if [[ "${ENABLE_SELENIUM}" == "yes" ]]; then
  echo
  echo ">>> Phase 2: Selenium Dependency Preflight"
  bash "${SCRIPT_DIR}/preflight_selenium.sh" \
    || { echo "❌ Selenium preflight FAILED"; exit 1; }
fi

# -----------------------------------------------------------------------------
# Phase 3: Agent Login & Call Validation (Selenium)
# -----------------------------------------------------------------------------
if [[ "${ENABLE_SELENIUM}" == "yes" ]]; then
  echo
  echo ">>> Phase 3: Agent Login & Call Validation (Selenium)"

  command -v python3 >/dev/null \
    || { echo "❌ python3 not found"; exit 1; }

  if [[ "${HEADLESS}" == "yes" ]]; then
    command -v xvfb-run >/dev/null \
      || { echo "❌ xvfb-run missing (HEADLESS=yes)"; exit 1; }

    xvfb-run -a python3 "${SCRIPT_DIR}/smoke_login_test.py" "${SERVER_IP}" \
      || { echo "❌ Selenium smoke test FAILED"; exit 1; }
  else
    python3 "${SCRIPT_DIR}/smoke_login_test.py" "${SERVER_IP}" \
      || { echo "❌ Selenium smoke test FAILED"; exit 1; }
  fi
else
  echo
  echo ">>> Phase 3: Selenium skipped (ENABLE_SELENIUM=no)"
fi

# -----------------------------------------------------------------------------
# Phase 4: Cleanup
# -----------------------------------------------------------------------------
if [[ "${AUTO_CLEANUP}" == "yes" ]]; then
  echo
  echo ">>> Phase 4: Cleanup (v2.0 hardened)"

  bash "${SCRIPT_DIR}/smoke_vicidial_v2.0_hardened.sh" || {
    echo "[WARN] Cleanup encountered issues but pipeline will continue"
  }
fi



echo
echo "============================================================"
echo " 🎉 FULL SMOKE TEST PASSED – SYSTEM IS PRODUCTION READY"
echo "============================================================"
exit 0
