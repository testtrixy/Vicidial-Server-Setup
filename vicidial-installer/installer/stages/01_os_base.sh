#!/usr/bin/env bash
# =============================================================================
# Stage 01 – OS Base (EL9 HARDENED)
#
# Responsibilities:
#   - OS validation (Rocky / Alma EL9 only)
#   - Hard-block MySQL permanently
#   - SELinux disable (runtime + config)
#   - Base repos (CRB, EPEL)
#   - Dev tools & core utilities
#   - Kernel / limits tuning (VOIP safe)
#   - Time sync baseline
#   - Asterisk system user
#   - Enforced reboot boundary
#
# STRICT STAGE:
#   - NO database
#   - NO Asterisk install
#   - NO SIP / PJSIP
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
require_root
require_command dnf
require_command systemctl

log_info "Stage 01: OS base bootstrap started"

STAGE_NAME="Stage_01"
stage_begin "${STAGE_NAME}"

# -----------------------------------------------------------------------------
# OS validation (MUST be first)
# -----------------------------------------------------------------------------
if ! grep -Eq 'Rocky|Alma' /etc/os-release; then
  fatal "Unsupported OS. Rocky or Alma Linux EL9 required."
fi

log_info "OS validation passed (EL9)"

# -----------------------------------------------------------------------------
# Hard-block MySQL permanently (CRITICAL)
# -----------------------------------------------------------------------------
log_info "Checking for existing MySQL packages"

if rpm -qa | grep -Eq 'mysql|community-mysql'; then
  fatal "MySQL packages already installed — unsupported state"
fi

log_info "Blocking MySQL at DNF level"

cat >> /etc/dnf/dnf.conf <<'EOF'
exclude=mysql*
exclude=community-mysql*
EOF

# -----------------------------------------------------------------------------
# Enable repositories (single authoritative block)
# -----------------------------------------------------------------------------
log_info "Enabling base repositories (CRB + EPEL)"

dnf install -y dnf-plugins-core epel-release
dnf config-manager --set-enabled crb

# -----------------------------------------------------------------------------
# Firewall baseline
# -----------------------------------------------------------------------------
log_info "Configuring firewalld baseline"

if systemctl list-unit-files | grep -q '^firewalld.service'; then
  systemctl enable --now firewalld
else
  log_warn "firewalld not installed — skipping (minimal image)"
fi

# -----------------------------------------------------------------------------
# System update
# -----------------------------------------------------------------------------
log_info "Updating system packages"
dnf -y update

# -----------------------------------------------------------------------------
# Development tools
# -----------------------------------------------------------------------------
log_info "Installing Development Tools"
dnf -y groupinstall "Development Tools"

# -----------------------------------------------------------------------------
# Base utilities & Perl core (VICIdial-ready)
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
# Disable SELinux (runtime + config)
# -----------------------------------------------------------------------------
log_info "Disabling SELinux (runtime + config)"

if command -v setenforce >/dev/null 2>&1; then
  setenforce 0 || true
fi

sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# -----------------------------------------------------------------------------
# Time synchronization
# -----------------------------------------------------------------------------
TIMEZONE="${TIMEZONE:-UTC}"
log_info "Configuring time synchronization (chrony, TZ=${TIMEZONE})"

systemctl enable chronyd --now
timedatectl set-timezone "${TIMEZONE}"

sleep 5
chronyc tracking || log_warn "Chrony not yet synchronized"

# -----------------------------------------------------------------------------
# Kernel & network tuning (VOIP-safe defaults)
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
# Disable Transparent Huge Pages (Asterisk best practice)
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
# Swap verification
# -----------------------------------------------------------------------------
log_info "Verifying swap availability"

if ! swapon --show | grep -q '^'; then
  log_warn "No swap detected. Strongly recommended for DB / dialer load."
else
  swapon --show
fi

# -----------------------------------------------------------------------------
# Ensure asterisk system user and group exist
# -----------------------------------------------------------------------------
log_info "Ensuring asterisk system user and group exist"

if ! getent group asterisk >/dev/null; then
  groupadd --system asterisk
fi

if ! getent passwd asterisk >/dev/null; then
  useradd \
    --system \
    --gid asterisk \
    --home-dir /var/lib/asterisk \
    --shell /sbin/nologin \
    asterisk
fi

# -----------------------------------------------------------------------------
# Enforce reboot boundary
# -----------------------------------------------------------------------------
log_warn "Stage 01 completed — system reboot REQUIRED"

mkdir -p /var/lib/vicidial-install
touch /var/lib/vicidial-install/reboot_required

log_warn "REBOOT REQUIRED before proceeding to Stage 02"

stage_finish "${STAGE_NAME}"

log_success "--------------------------------------------------------"
log_success "------------------ Stage 01 COMPLETED ------------------"
log_success "--------------------------------------------------------"

exit 0
