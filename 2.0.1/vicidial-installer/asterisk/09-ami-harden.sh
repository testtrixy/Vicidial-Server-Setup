#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " AMI HARDENING (Vicidial / Asterisk 18)"
echo "========================================"

### --- SAFETY CHECKS ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

command -v asterisk >/dev/null || {
  echo "[ERROR] Asterisk not installed"
  exit 1
}

### --- VERIFY MANAGER.CONF EXISTS ---
if [[ ! -f /etc/asterisk/manager.conf ]]; then
  echo "[FATAL] /etc/asterisk/manager.conf missing"
  exit 1
fi

### --- ENSURE WEB AMI IS DISABLED ---
if grep -qi '^webenabled\s*=\s*yes' /etc/asterisk/manager.conf; then
  echo "[INFO] Disabling AMI web interface"
  sed -i 's/^webenabled\s*=.*/webenabled = no/' /etc/asterisk/manager.conf
fi

### --- ENSURE AMI BINDS TO LOCALHOST ---
if ! grep -q '^bindaddr\s*=\s*127.0.0.1' /etc/asterisk/manager.conf; then
  echo "[WARN] bindaddr not localhost — enforcing"
  sed -i 's/^bindaddr\s*=.*/bindaddr = 127.0.0.1/' /etc/asterisk/manager.conf
fi

### --- FIREWALL HARDENING ---
if systemctl is-active --quiet firewalld; then
  echo "[INFO] Ensuring AMI port is NOT exposed externally"

  firewall-cmd --remove-port=5038/tcp --permanent >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1
else
  echo "[INFO] firewalld not running — skipping firewall step"
fi

### --- RELOAD AMI ---
echo "[INFO] Reloading Asterisk manager"
asterisk -rx "manager reload" || true

### --- VERIFY AMI USER EXISTS ---
if ! asterisk -rx "manager show users" | grep -qi vicidial; then
  echo "[FATAL] Vicidial AMI user not detected"
  exit 1
fi

echo "[OK] AMI hardened successfully"
