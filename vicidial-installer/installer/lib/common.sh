#!/usr/bin/env bash
set -euo pipefail

log()  { echo "[INFO] $1"; }
ok()   { echo "[OK]   $1"; }
warn() { echo "[WARN] $1"; }
die()  { echo "[FAIL] $1"; exit 1; }
