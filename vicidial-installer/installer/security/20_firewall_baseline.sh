#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 20 – Firewall Baseline (EL9 – Golden)
#
# Purpose:
#   - Establish a secure default firewall posture
#   - Expose only required VICIdial services
#   - Work with dynamic/home public IPs
#   - Integrate cleanly with Fail2Ban (nftables)
#
# Safe:
#   - Never blocks SSH
#   - Idempotent
#   - No hardcoded IPs
#   - EL9 native (firewalld + nftables)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command firewall-cmd
require_command systemctl

check_el9

STAGE_NAME="Stage_20_Firewall_Baseline"
stage_begin "${STAGE_NAME}"

log_info "=== Stage 20: Firewall Baseline ==="

# -----------------------------------------------------------------------------
# Ensure firewalld installed and running
# -----------------------------------------------------------------------------
log_info "Ensuring firewalld is installed and running"

dnf install -y firewalld >/dev/null

systemctl enable --now firewalld

log_success "firewalld active"

# -----------------------------------------------------------------------------
# Detect default zone
# -----------------------------------------------------------------------------
DEFAULT_ZONE="$(firewall-cmd --get-default-zone)"
log_info "Using firewalld zone: ${DEFAULT_ZONE}"

# -----------------------------------------------------------------------------
# Core services (NEVER LOCK OUT)
# -----------------------------------------------------------------------------
log_info "Allowing core management services"

firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-service=ssh
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-service=http
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-service=https

# -----------------------------------------------------------------------------
# VICIdial signaling (SIP + PJSIP)
# -----------------------------------------------------------------------------
log_info "Allowing SIP / PJSIP signaling ports"

# SIP / PJSIP signaling
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-port=5060/udp
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-port=5060/tcp
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-port=5061/udp
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-port=5061/tcp

# -----------------------------------------------------------------------------
# RTP audio (media)
# -----------------------------------------------------------------------------
log_info "Allowing RTP audio ports (10000–20000 UDP)"

firewall-cmd --permanent --zone="${DEFAULT_ZONE}" --add-port=10000-20000/udp

# -----------------------------------------------------------------------------
# AMI (LOCAL ONLY – DO NOT EXPOSE)
# -----------------------------------------------------------------------------
log_info "Restricting Asterisk AMI to localhost only"

firewall-cmd --permanent --zone="${DEFAULT_ZONE}" \
  --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port protocol="tcp" port="5038" accept'

firewall-cmd --permanent --zone="${DEFAULT_ZONE}" \
  --add-rich-rule='rule family="ipv6" source address="::1" port protocol="tcp" port="5038" accept'

# Explicit drop for external AMI access
firewall-cmd --permanent --zone="${DEFAULT_ZONE}" \
  --add-rich-rule='rule family="ipv4" port protocol="tcp" port="5038" drop'

# -----------------------------------------------------------------------------
# Reload firewall
# -----------------------------------------------------------------------------
log_info "Reloading firewall rules"

firewall-cmd --reload

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
log_info "Validating firewall configuration"

firewall-cmd --list-all --zone="${DEFAULT_ZONE}"

log_success "Firewall baseline applied successfully"


#-----------
# firewalld rich rule (UDP SIP)
#-------------------------------


log_info "Applying SIP rate-limiting (UDP 5060–5061)"

firewall-cmd --permanent --add-rich-rule='
rule family="ipv4"
port port="5060-5061" protocol="udp"
limit value="25/s" burst="50"
accept'

# tcop

firewall-cmd --permanent --add-rich-rule='
rule family="ipv4"
port port="5060-5061" protocol="tcp"
limit value="10/s" burst="20"
accept'

# reload 

firewall-cmd --reload
log_success "SIP rate-limiting rules applied"


# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 20 completed – Secure firewall baseline active"
stage_finish "${STAGE_NAME}"






#-- How to run and check
#   firewall-cmd --list-all

# You should see:
# Ports: 5060/tcp 5060/udp 5061/tcp 5061/udp 10000-20000/udp
# Services: ssh http https
# NO 3306

# Check nftables:
# nft list ruleset | grep asterisk -n
#


# firewall-cmd --list-ports
# Expected:
#5060/udp 5060/tcp 5061/udp 5061/tcp 10000-20000/udp

#ss -lntp | grep 5038  ==> 127.0.0.1