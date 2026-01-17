#!/usr/bin/env bash
# =============================================================================
# Selenium Dependency Preflight (EL9)
# =============================================================================

set -euo pipefail

AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-yes}"
HEADLESS="${HEADLESS:-yes}"

log()    { echo "[PREFLIGHT] $1"; }
warn()   { echo "[WARN] $1"; }
fatal()  { echo "[FATAL] $1"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

install_pkg() {
  if [[ "${AUTO_INSTALL_DEPS}" == "yes" ]]; then
    log "Installing: $*"
    dnf install -y "$@"
  else
    fatal "Missing dependency: $* (AUTO_INSTALL_DEPS=no)"
  fi
}

install_pip() {
  if [[ "${AUTO_INSTALL_DEPS}" == "yes" ]]; then
    pip3 install "$@"
  else
    fatal "Missing python package: $* (AUTO_INSTALL_DEPS=no)"
  fi
}

log "Checking Python 3"
need_cmd python3 || install_pkg python3 python3-pip

log "Checking pip"
need_cmd pip3 || fatal "pip3 missing even after python install"

log "Checking Selenium Python packages"
python3 - <<'EOF' >/dev/null 2>&1 || install_pip selenium webdriver-manager
import selenium
import webdriver_manager
EOF

log "Checking Chromium / Chrome"
if ! (need_cmd chromium || need_cmd google-chrome); then
  install_pkg chromium
fi

if [[ "${HEADLESS}" == "yes" ]]; then
  log "Checking Xvfb (headless mode)"
  need_cmd Xvfb || install_pkg xorg-x11-server-Xvfb
fi

log "Selenium preflight PASSED"
