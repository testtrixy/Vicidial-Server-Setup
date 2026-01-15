#!/usr/bin/env bash
set -euo pipefail

source lib/common.sh


STAGE_NAME="Stage_02b"
stage_begin "${STAGE_NAME}"


if [[ -f "${STAGE_MARKER}" ]]; then
  log "Stage ${STAGE_ID} already completed – skipping"
  exit 0
fi


check_el9

log "Installing lite DB dependencies (telephony node)"

dnf install -y \
  perl \
  perl-DBI \
  perl-DBD-MariaDB \
  mariadb

log "Lite DB deps installed"
stage_finish "${STAGE_NAME}"