source "$(dirname "$0")/../lib/common.sh"

dahdi_cfg -t >/dev/null || fail "No DAHDI timing source"

#!/usr/bin/env bash
set -euo pipefail


echo "[06] DAHDI timing enforcement"


dnf install -y dahdi dahdi-tools


modprobe dahdi || true
modprobe dahdi_dummy || true


echo "dahdi" > /etc/modules-load.d/dahdi.conf
echo "dahdi_dummy" >> /etc/modules-load.d/dahdi.conf


if ! dahdi_cfg -t >/dev/null 2>&1; then
echo "[ERROR] DAHDI timing not active"
exit 1
fi



log "Ensuring DAHDI timing source"

modprobe dahdi || true
modprobe dahdi_dummy || true

echo "dahdi" > /etc/modules-load.d/dahdi.conf
echo "dahdi_dummy" >> /etc/modules-load.d/dahdi.conf

if ! dahdi_cfg -t >/dev/null 2>&1; then
  die "DAHDI timing source not active"
fi

ok "DAHDI timing active"



echo "[06] DAHDI timing active"

log "Self-validation completed for $(basename "$0")"