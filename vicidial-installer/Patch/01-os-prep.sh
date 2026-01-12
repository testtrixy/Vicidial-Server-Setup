
source "$(dirname "$0")/../lib/common.sh"



mountpoint -q /var/spool/asterisk/monitor || fail "RAM drive not mounted"
getenforce | grep -Eq "Permissive|Disabled" && ok "SELinux acceptable"

#!/usr/bin/env bash
set -euo pipefail


echo "[01] OS prep: limits, RAM drive, SELinux"


# ---- RAM DRIVE FOR RECORDINGS ----
MONDIR=/var/spool/asterisk/monitor
MEM_MB=$(free -m | awk '/Mem:/ {print $2}')
SIZE_MB=$((MEM_MB / 4))
[[ "$SIZE_MB" -lt 512 ]] && SIZE_MB=512


mkdir -p "$MONDIR"


if ! grep -q "$MONDIR" /etc/fstab; then
echo "tmpfs $MONDIR tmpfs rw,size=${SIZE_MB}M 0 0" >> /etc/fstab
fi


mountpoint -q "$MONDIR" || mount "$MONDIR"


# ---- FILE LIMITS ----
cat <<EOF > /etc/security/limits.d/vicidial.conf
asterisk soft nofile 100000
asterisk hard nofile 100000
EOF


# ---- SELINUX (EXPLICIT) ----
if command -v getenforce >/dev/null 2>&1; then
setsebool -P httpd_can_network_connect_db 1
setsebool -P httpd_execmem 1
fi




log "Configuring RAM drive for call recordings"

MONDIR=/var/spool/asterisk/monitor
MEM_MB=$(free -m | awk '/Mem:/ {print $2}')
SIZE_MB=$((MEM_MB / 4))
[[ "$SIZE_MB" -lt 512 ]] && SIZE_MB=512

mkdir -p "$MONDIR"

if ! grep -q "$MONDIR" /etc/fstab; then
  echo "tmpfs $MONDIR tmpfs rw,size=${SIZE_MB}M 0 0" >> /etc/fstab
  log "Added tmpfs entry to /etc/fstab"
fi

if ! mountpoint -q "$MONDIR"; then
  mount "$MONDIR"
fi

mountpoint -q "$MONDIR" || die "RAM drive not mounted"
ok "RAM drive active at $MONDIR"


echo "[01] OS prep completed"

log "Self-validation completed for $(basename "$0")"