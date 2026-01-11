#!/bin/bash
echo "=== STEP 09: Boot & Cron ==="

chmod +x /etc/rc.d/rc.local
crontab -l > /tmp/cron.bak || true
crontab -e

echo "[OK] Boot & cron configured"
