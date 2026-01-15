#!/usr/bin/env bash
set -euo pipefail

source lib/common.sh

check_el9

log "Installing lite DB dependencies (telephony node)"

dnf install -y \
  perl \
  perl-DBI \
  perl-DBD-MariaDB \
  mariadb

log "Lite DB deps installed"
