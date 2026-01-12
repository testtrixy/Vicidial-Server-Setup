#!/bin/bash

#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 06: DAHDI (Userspace only – Rocky 8 safe)"
echo "=================================================="

# ---------------------------------------------------
# Rocky Linux 8 does NOT support DAHDI kernel modules
# VICIdial uses Asterisk internal timing instead
# ---------------------------------------------------

echo "[INFO] Skipping DAHDI kernel module build (unsupported on Rocky 8)"

# ---------------------------------------------------
# Install userspace tools ONLY (optional but safe)
# ---------------------------------------------------
echo "[+] Installing DAHDI userspace utilities (if available)"

dnf install -y dahdi-tools dahdi-tools-libs || true

# ---------------------------------------------------
# Ensure no legacy DAHDI autoload configs exist
# ---------------------------------------------------
rm -f /etc/modules-load.d/dahdi.conf 2>/dev/null || true
rm -f /etc/sysconfig/dahdi 2>/dev/null || true

# ---------------------------------------------------
# Informational checks (non-fatal)
# ---------------------------------------------------
if command -v dahdi_cfg >/dev/null 2>&1; then
  echo "[INFO] dahdi_cfg present (not required)"
else
  echo "[INFO] dahdi_cfg not present (expected on Rocky 8)"
fi

echo "[OK] DAHDI step completed (no kernel modules used)"
echo "=================================================="
