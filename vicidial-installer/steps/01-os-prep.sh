#!/bin/bash
echo "=== STEP 01: OS Preparation ==="




echo "=== STEP 01: Disable firewall==="
systemctl disable --now firewalld || true


echo "[+] Disabling SELinux"
if grep -q "SELINUX=disabled" /etc/selinux/config; then
  echo "    SELinux already disabled"
else
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  setenforce 0 || true
fi


echo "[+] Installing nano"
yum -y install nano

echo "[+] Setting nano as default editor"
grep -q EDITOR /etc/bashrc || echo 'export EDITOR="nano"' >> /etc/bashrc

echo "[+] Setting timezone"
timedatectl set-timezone America/New_York

echo "[+] Enabling rc.local"
chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

echo "[OK] OS preparation completed"


#Expected Output : SELinux disabled & rc-local active


