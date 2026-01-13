#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Applying OS hardening"

# ---- SELinux ----
setenforce 0 || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# ---- Firewall ----
systemctl disable --now firewalld || true

# ---- Sysctl ----
cp "$INSTALL_ROOT/conf/sysctl-vicidial.conf" /etc/sysctl.d/99-vicidial.conf
sysctl --system

# ---- Limits ----
cp "$INSTALL_ROOT/conf/limits-vicidial.conf" /etc/security/limits.d/99-vicidial.conf

log INFO "OS hardening complete"
