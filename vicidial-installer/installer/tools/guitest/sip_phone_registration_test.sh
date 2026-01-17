

#   Create: sip_phone_registration_test.sh
#   Goal
#   Prove a phone can register

#   Not tied to Vicidial campaigns
#   No originate, no agents
#   What it checks
#   SIP or PJSIP endpoint exists
#   Contact becomes OK
#   NAT + transport working


#   Example checks
#   asterisk -rx "sip show peer 1000"
#   asterisk -rx "pjsip show endpoint 1000"
#   asterisk -rx "pjsip show contacts"


#   ⚠️ This script:
#    Requires a real softphone (Linphone / Zoiper)
#    Is manual or semi-automated
#    Should be optional


#!/usr/bin/env bash
# =============================================================================
# SIP / PJSIP Phone Registration Test (EL9 – Safe Validation)
#
# Purpose:
#   - Verify a SIP or PJSIP phone can REGISTER successfully
#   - Validate transport, NAT, auth, and endpoint wiring
#
# Requires:
#   - A real softphone (Linphone / Zoiper)
#   - Human action to register the phone
#
# Safe:
#   - NO calls
#   - NO originate
#   - NO Vicidial logic
#   - NO database writes
#
#  export ENABLE_SIP_REG_TEST=yes export TEST_EXTEN=1000 export WAIT_SECONDS=90
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command asterisk
check_el9

# -----------------------------------------------------------------------------
# Opt-in Guard
# -----------------------------------------------------------------------------
if [[ "${ENABLE_SIP_REG_TEST:-no}" != "yes" ]]; then
  log_warn "SIP registration test disabled (ENABLE_SIP_REG_TEST!=yes)"
  exit 0
fi

# -----------------------------------------------------------------------------
# Test Parameters (SAFE DEFAULTS)
# -----------------------------------------------------------------------------
TEST_EXTEN="${TEST_EXTEN:-1000}"
WAIT_SECONDS="${WAIT_SECONDS:-60}"

log_info "=== SIP PHONE REGISTRATION TEST START ==="
log_info "Test Extension : ${TEST_EXTEN}"
log_info "Wait Time      : ${WAIT_SECONDS}s"

# -----------------------------------------------------------------------------
# Detect SIP Stack
# -----------------------------------------------------------------------------
if asterisk -rx "sip show settings" >/dev/null 2>&1; then
  SIP_MODE="SIP"
elif asterisk -rx "pjsip show transports" >/dev/null 2>&1; then
  SIP_MODE="PJSIP"
else
  fatal "No SIP stack loaded (chan_sip or PJSIP)"
fi

log_success "Detected SIP mode: ${SIP_MODE}"

# -----------------------------------------------------------------------------
# Verify Endpoint Exists
# -----------------------------------------------------------------------------
if [[ "${SIP_MODE}" == "SIP" ]]; then
  asterisk -rx "sip show peer ${TEST_EXTEN}" >/dev/null 2>&1 \
    || fatal "SIP peer ${TEST_EXTEN} not defined"
else
  asterisk -rx "pjsip show endpoint ${TEST_EXTEN}" >/dev/null 2>&1 \
    || fatal "PJSIP endpoint ${TEST_EXTEN} not defined"
fi

log_success "Endpoint ${TEST_EXTEN} exists"

# -----------------------------------------------------------------------------
# Prompt Human Registration
# -----------------------------------------------------------------------------
cat <<EOF

========================================================================
📱 ACTION REQUIRED
========================================================================

Please REGISTER your softphone now:

  Extension : ${TEST_EXTEN}
  Password  : ${TEST_EXTEN}
  Server    : <THIS SERVER IP>
  Transport : UDP
  Codec     : ulaw

You have ${WAIT_SECONDS} seconds...

========================================================================
EOF

# -----------------------------------------------------------------------------
# Wait for Registration
# -----------------------------------------------------------------------------
END_TIME=$((SECONDS + WAIT_SECONDS))
REGISTERED="no"

while [[ "${SECONDS}" -lt "${END_TIME}" ]]; do
  if [[ "${SIP_MODE}" == "SIP" ]]; then
    if asterisk -rx "sip show peer ${TEST_EXTEN}" | grep -q "Status.*OK"; then
      REGISTERED="yes"
      break
    fi
  else
    if asterisk -rx "pjsip show contacts" | grep -q "${TEST_EXTEN}"; then
      REGISTERED="yes"
      break
    fi
  fi
  sleep 2
done

# -----------------------------------------------------------------------------
# Result
# -----------------------------------------------------------------------------
if [[ "${REGISTERED}" != "yes" ]]; then
  fatal "Phone ${TEST_EXTEN} did NOT register within ${WAIT_SECONDS}s"
fi

log_success "Phone ${TEST_EXTEN} REGISTERED successfully"

# -----------------------------------------------------------------------------
# Dialplan Reachability (Non-Call Check)
# -----------------------------------------------------------------------------
log_info "Verifying dialplan reachability"

if ! asterisk -rx "dialplan show vicidial-auto-phones" >/dev/null 2>&1; then
  log_warn "Vicidial dialplan not present (not fatal for SIP test)"
else
  log_success "Vicidial dialplan reachable"
fi

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "=== SIP PHONE REGISTRATION TEST PASSED ==="
exit 0
