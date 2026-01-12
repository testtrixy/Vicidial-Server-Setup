#!/bin/bash

echo "=== STEP 00: Environment Check ==="

exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"


grep -q "Rocky Linux 8" /etc/os-release || { echo "Wrong OS"; exit 1; }

nproc | awk '{ if ($1 < 2) print "WARN: Low CPU cores" }'
free -g | awk '/Mem:/ { if ($2 < 4) print "WARN: Low RAM" }'
df -h / | awk 'NR==2 { if ($4+0 < 20) print "WARN: Low disk" }'
ip route get 8.8.8.8 >/dev/null || echo "WARN: No outbound network"

echo "[OK] Environment check completed"