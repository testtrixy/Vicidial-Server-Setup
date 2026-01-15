#!/usr/bin/env bash
# =============================================================================
# Stage 07 – Audio, Sounds & Codecs
# Responsibilities:
#   - Install Asterisk core & extra sounds
#   - Install Music On Hold (MOH) samples
#   - Enable MP3/WAV codec support
#   - Prepare transcoding helpers (lame, sox)
#
# ASSUMES:
#   - Stage 04 (Telephony) completed
#   - Asterisk installed & runnable
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command dnf
require_command asterisk




log_success "---------------- – -------------------------------"
  log_info "Stage 07: Audio & codec setup started"
log_success "---------------- – -------------------------------"




ASTERISK_SOUNDS_DIR="/var/lib/asterisk/sounds"
MOH_DIR="/var/lib/asterisk/moh"

# -----------------------------------------------------------------------------
# 1. Install audio utilities (transcoding helpers)
# -----------------------------------------------------------------------------
log_info "Installing audio utilities (lame, sox, flac)"

log_info "Installing audio utilities (EL9 compatible)"

dnf -y install \
  sox \
  lame \
  flac

# -----------------------------------------------------------------------------
# 2. Asterisk sound packages (RPM if available)
# -----------------------------------------------------------------------------
log_info "Installing Asterisk sound packages (if available)"

dnf -y install \
  asterisk-sounds-core-en \
  asterisk-sounds-extra-en || \
  log_warn "Sound RPMs not available – falling back to manual install"

# -----------------------------------------------------------------------------
# 3. Manual sound installation (fallback / guaranteed)
# -----------------------------------------------------------------------------
if [[ ! -d "${ASTERISK_SOUNDS_DIR}/en" ]]; then
  log_info "Downloading Asterisk sound files manually"

  cd /tmp

  curl -fLO http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz
  curl -fLO http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz

  tar -zxf asterisk-core-sounds-en-wav-current.tar.gz -C "${ASTERISK_SOUNDS_DIR}"
  tar -zxf asterisk-extra-sounds-en-wav-current.tar.gz -C "${ASTERISK_SOUNDS_DIR}"

  rm -f asterisk-core-sounds-en-wav-current.tar.gz
  rm -f asterisk-extra-sounds-en-wav-current.tar.gz
fi

# -----------------------------------------------------------------------------
# 4. Music On Hold (MOH)
# -----------------------------------------------------------------------------
log_info "Setting up Music On Hold (MOH)"

mkdir -p "${MOH_DIR}"

if [[ -z "$(ls -A "${MOH_DIR}")" ]]; then
  cd "${MOH_DIR}"

  curl -fLO http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-wav-current.tar.gz
  tar -zxf asterisk-moh-opsound-wav-current.tar.gz
  rm -f asterisk-moh-opsound-wav-current.tar.gz
fi

# -----------------------------------------------------------------------------
# 5. Permissions
# -----------------------------------------------------------------------------
log_info "Applying permissions to audio directories"

chown -R asterisk:asterisk "${ASTERISK_SOUNDS_DIR}" "${MOH_DIR}"
chmod -R 755 "${ASTERISK_SOUNDS_DIR}" "${MOH_DIR}"

# -----------------------------------------------------------------------------
# 6. Reload Asterisk
# -----------------------------------------------------------------------------
log_info "Reloading Asterisk to recognize sounds"

asterisk -rx "core reload"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 07 completed – audio & codecs ready"
