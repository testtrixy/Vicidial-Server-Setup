#!/usr/bin/env bash
set -euo pipefail


ok() { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }


require_cmd() {
command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}


require_service() {
systemctl is-active --quiet "$1" || fail "Service not running: $1"
}


require_port() {
ss -lnt | grep -q ":$1 " || fail "Port $1 not listening"
}