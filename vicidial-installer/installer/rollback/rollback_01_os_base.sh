#!/usr/bin/env bash
set -euo pipefail

echo "[ROLLBACK] Stage 01 – OS base"

MARKER_DIR="/var/lib/vicidial-install"

if [[ -d "${MARKER_DIR}" ]]; then
  rm -rf "${MARKER_DIR}"
  echo "Removed marker directory"
fi

# Do NOT touch:
# - packages
# - SELinux
# - kernel

echo "[ROLLBACK] Stage 01 complete"
exit 0
