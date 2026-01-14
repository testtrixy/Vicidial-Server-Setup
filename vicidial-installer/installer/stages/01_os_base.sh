#!/usr/bin/env bash
# =============================================================================
# Stage 01 – OS Base
# Responsibilities:
#   - OS validation (EL9)
#   - SELinux disable (config + runtime)
#   - Base repos
#   - Dev tools
#   - Core utilities
#   - Kernel / limits tuning
#   - Time sync baseline
#
# NO rendering
# NO database
# NO web
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command dnf
require_command systemctl

log_info "Stage 01: OS base bootstrap started"

# -----------------------------------------------------------------------------
# OS validation (EL9 only)
# -----------------------------------------------------------------------------
if ! grep -qE 'Rocky|Alma' /etc/os-release; then
  fatal "Unsupported OS. Rocky or Alma Linux EL9 required."
fi

log_info "OS validation passed (EL9)"

# -----------------------------------------------------------------------------
# Disable SELinux (effective after reboot)
# -----------------------------------------------------------------------------
log_info "Disabling SELinux (runtime + config)"

if command -v setenforce >/dev/null 2>&1; then
  setenforce 0 || true
fi

sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# -----------------------------------------------------------------------------
# Firewall baseline (ports opened in later stages)
# -----------------------------------------------------------------------------
log_info "Enabling firewalld baseline"

#systemctl enable firewalld --now

if systemctl list-unit-files | grep -q '^firewalld.service'; then
  log_info "Enabling firewalld"
  systemctl enable --now firewalld
else
  log_warn "firewalld not installed — skipping (expected on minimal images)"
fi


# -----------------------------------------------------------------------------
# System update
# -----------------------------------------------------------------------------
log_info "Updating system packages"
dnf -y update

# -----------------------------------------------------------------------------
# Repositories & Development Tools
# -----------------------------------------------------------------------------
log_info "Enabling repositories and development tools"

dnf -y install epel-release
dnf config-manager --set-enabled crb
dnf -y groupinstall "Development Tools"

# -----------------------------------------------------------------------------
# Base utilities & Perl core (Vicidial-ready)
# -----------------------------------------------------------------------------
log_info "Installing base utilities and Perl core"

dnf -y install \
  vim nano wget curl git unzip tar \
  net-tools bind-utils lsof htop tmux \
  rsync jq psmisc procps-ng \
  chrony \
  policycoreutils-python-utils \
  perl-interpreter perl-devel perl-CPAN

# -----------------------------------------------------------------------------
# Time synchronization
# -----------------------------------------------------------------------------
log_info "Configuring time synchronization (chrony)"

systemctl enable chronyd --now
timedatectl set-timezone UTC

sleep 5
chronyc tracking || log_warn "Chrony not yet synchronized"

# -----------------------------------------------------------------------------
# Kernel & network tuning (VOIP safe defaults)
# -----------------------------------------------------------------------------
log_info "Applying kernel and network tuning"

cat >/etc/sysctl.d/99-vicidial.conf <<EOF
# Telephony & high-concurrency tuning
fs.file-max = 2097152
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15

# Memory behavior
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

sysctl --system

# -----------------------------------------------------------------------------
# File descriptor & process limits
# -----------------------------------------------------------------------------
log_info "Configuring file descriptor and process limits"

cat >/etc/security/limits.d/vicidial.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc  65535
* hard nproc  65535
EOF

# -----------------------------------------------------------------------------
# Transparent Huge Pages (Asterisk best practice)
# -----------------------------------------------------------------------------
log_info "Disabling Transparent Huge Pages"

cat >/etc/systemd/system/disable-thp.service <<EOF
[Unit]
Description=Disable Transparent Huge Pages
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable disable-thp --now

# -----------------------------------------------------------------------------
# Swap verification (cloud safety)
# -----------------------------------------------------------------------------
log_info "Verifying swap availability"

if ! swapon --show | grep -q '^'; then
  log_warn "No swap detected. Strongly recommended before heavy DB / dialing load."
else
  swapon --show
fi

# -----------------------------------------------------------------------------
# Completion notice
# -----------------------------------------------------------------------------
log_success "--------------------------------------------------------"
log_success "------------------Stage 01 completed--------------------"
log_success "--------------------------------------------------------"


log_warn "System reboot is REQUIRED before continuing installation"
mkdir -p /var/lib/vicidial-install
touch /var/lib/vicidial-install/reboot_required
log_warn "REBOOT REQUIRED before proceeding to Stage 02 (SELinux & kernel changes)"
#require_rebooted_if_needed