#!/usr/bin/env bash
# =============================================================================
# Stage 07a – Proprietary Codecs (OPTIONAL / MANUAL)
#
# PURPOSE:
#   - Install G.729 / G.723.1 binary codecs for Asterisk 18
#
# IMPORTANT:
#   - These codecs may be patent-encumbered
#   - Commercial use MAY require licensing
#   - This stage is NOT executed by install.sh automatically
#
# OPERATOR ACTION REQUIRED:
#   export ENABLE_PROPRIETARY_CODECS=yes
#   export ACCEPT_CODEC_LICENSE=yes
#
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# HARD GATES – DO NOT REMOVE
# -----------------------------------------------------------------------------
if [[ "${ENABLE_PROPRIETARY_CODECS:-no}" != "yes" ]]; then
  echo "[SKIP] Proprietary codecs disabled (ENABLE_PROPRIETARY_CODECS != yes)"
  exit 0
fi

if [[ "${ACCEPT_CODEC_LICENSE:-no}" != "yes" ]]; then
  echo "[FATAL] You must explicitly accept codec licensing terms."
  echo "Set ACCEPT_CODEC_LICENSE=yes to proceed."
  exit 1
fi

require_root
require_command asterisk
require_command curl

log_warn "Installing proprietary codecs – operator responsibility acknowledged"

# -----------------------------------------------------------------------------
# Detect Asterisk module directory (dynamic, safe)
# -----------------------------------------------------------------------------
ASTERISK_MODULE_DIR="$(asterisk -rx 'core show settings' | awk -F': ' '/Module Directory/{print $2}')"

if [[ -z "${ASTERISK_MODULE_DIR}" ]]; then
  fatal "Unable to determine Asterisk module directory"
fi

log_info "Asterisk module directory: ${ASTERISK_MODULE_DIR}"

# -----------------------------------------------------------------------------
# Codec binaries (Asterisk 18 ONLY)
# -----------------------------------------------------------------------------
# NOTE:
# These binaries are CPU- and ABI-sensitive.
# Use ONLY if you understand the risk.
#
# Sources shown here match legacy usage patterns.
# -----------------------------------------------------------------------------

export ENABLE_PROPRIETARY_CODECS=no
export ACCEPT_CODEC_LICENSE=no

CODEC_BASE_URL="http://asterisk.hosting.lv/bin"

CODECS=(
  "codec_g729-ast180-gcc4-glibc-x86_64-core2-sse4.so:codec_g729.so"
  "codec_g723-ast180-gcc4-glibc-x86_64-core2-sse4.so:codec_g723.so"
)

TMP_DIR="/tmp/asterisk-codecs"
mkdir -p "${TMP_DIR}"
cd "${TMP_DIR}"

for entry in "${CODECS[@]}"; do
  SRC="${entry%%:*}"
  DEST="${entry##*:}"

  log_info "Downloading ${DEST}"

  curl -fLO "${CODEC_BASE_URL}/${SRC}"

  install -m 755 "${SRC}" "${ASTERISK_MODULE_DIR}/${DEST}"
done

# -----------------------------------------------------------------------------
# Load codecs & verify
# -----------------------------------------------------------------------------
log_info "Loading proprietary codecs"

asterisk -rx "module load codec_g729.so" || log_warn "G.729 load failed"
asterisk -rx "module load codec_g723.so" || log_warn "G.723.1 load failed"

log_info "Current codec translation matrix:"
asterisk -rx "core show translation"

# -----------------------------------------------------------------------------
# Completion notice
# -----------------------------------------------------------------------------
log_success "Stage 07a completed – proprietary codecs installed (operator responsibility)"
