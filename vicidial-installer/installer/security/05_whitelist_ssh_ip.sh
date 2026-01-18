
#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 05_whitelist_ssh_ip.sh
#
# Purpose:
#   - Automatically whitelist the CURRENT SSH client IP
#   - Safe for dynamic home IPs
#   - Applies to firewalld + Fail2Ban
#
# Requirements:
#   - Must be run during an active SSH session
#   - firewalld and/or fail2ban may or may not be installed yet
###############################################################################

WHITELIST_TAG="vicidial-admin"
F2B_IGNORE_FILE="/etc/fail2ban/jail.d/whitelist.local"

log() { echo "[SECURITY][WHITELIST] $*"; }

###############################################################################
# Detect SSH Client IP (robust)
###############################################################################

SSH_IP=""

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  SSH_IP="$(echo "${SSH_CONNECTION}" | awk '{print $1}')"
elif [[ -n "${SSH_CLIENT:-}" ]]; then
  SSH_IP="$(echo "${SSH_CLIENT}" | awk '{print $1}')"
fi

if [[ -z "${SSH_IP}" ]]; then
  log "No SSH client IP detected — skipping whitelist (safe exit)"
  exit 0
fi

log "Detected SSH client IP: ${SSH_IP}"

###############################################################################
# Validate IP
###############################################################################

if ! [[ "${SSH_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  log "Invalid IPv4 detected (${SSH_IP}) — skipping"
  exit 0
fi

###############################################################################
# firewalld: whitelist SSH IP
###############################################################################

if systemctl is-active --quiet firewalld; then
  log "Applying firewalld whitelist"

  firewall-cmd --permanent \
    --add-rich-rule="rule family=ipv4 source address=${SSH_IP}/32 accept" \
    || true

  firewall-cmd --reload || true
else
  log "firewalld not active — skipping firewall whitelist"
fi

###############################################################################
# Fail2Ban: ignoreip
###############################################################################

log "Ensuring Fail2Ban ignoreip includes ${SSH_IP}"

mkdir -p "$(dirname "${F2B_IGNORE_FILE}")"

if [[ ! -f "${F2B_IGNORE_FILE}" ]]; then
  cat > "${F2B_IGNORE_FILE}" <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ${SSH_IP}
EOF
else
  if ! grep -q "${SSH_IP}" "${F2B_IGNORE_FILE}"; then
    sed -i "s|^ignoreip =|ignoreip = ${SSH_IP} |" "${F2B_IGNORE_FILE}"
  fi
fi

###############################################################################
# Reload Fail2Ban if running
###############################################################################

if systemctl is-active --quiet fail2ban; then
  log "Reloading Fail2Ban"
  fail2ban-client reload || systemctl restart fail2ban
else
  log "Fail2Ban not active — ignoreip will apply on install"
fi

log "SSH IP ${SSH_IP} successfully whitelisted"
exit 0
