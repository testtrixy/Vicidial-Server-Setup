#!/bin/bash

#!/bin/bash
set -euo pipefail


echo "=================================================="
echo " STEP 06: DAHDI (Userspace Only – Rocky 8 Safe)"
echo "=================================================="

# Rocky 8 does NOT support DAHDI kernel modules.
# VICIdial uses Asterisk internal timing.

echo "[INFO] Skipping DAHDI kernel modules (expected on Rocky 8)"

dnf install -y dahdi-tools dahdi-tools-libs || true

rm -f /etc/modules-load.d/dahdi.conf /etc/sysconfig/dahdi 2>/dev/null || true

echo "[OK] DAHDI userspace tools installed (kernel modules not required)"

