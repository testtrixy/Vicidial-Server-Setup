#!/usr/bin/env bash
# =============================================================================
# Stage 08 – Modern Extras (OPTIONAL)
#
# Purpose:
#   - HTTPS for Vicidial UI
#   - WebRTC preparation (non-invasive)
#   - Monitoring hooks
#   - Light security hardening
#
# IMPORTANT:
#   - Nothing in this stage is required for dialing
#   - All features are opt-in via environment flags
#   - Safe to skip entirely
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety
# -----------------------------------------------------------------------------
require_root
require_command systemctl

STAGE_NAME="Stage_08"
stage_begin "${STAGE_NAME}"

log_success "---------------- – -------------------------------"
 log_info "Stage 08: Modern extras (optional) started"
log_success "---------------- – -------------------------------"






# -----------------------------------------------------------------------------
# 1. HTTPS for Vicidial UI (OPTIONAL)
# -----------------------------------------------------------------------------
if [[ "${ENABLE_HTTPS:-no}" == "yes" ]]; then
  log_info "HTTPS enabled – configuring Apache TLS"

  require_command certbot || dnf -y install certbot python3-certbot-apache

  require_vars VICIDIAL_FQDN ADMIN_EMAIL

  # Obtain certificate (non-interactive)
  certbot --apache \
    -d "${VICIDIAL_FQDN}" \
    --non-interactive \
    --agree-tos \
    -m "${ADMIN_EMAIL}" || \
    log_warn "Certbot failed – HTTPS not enforced"

  # Enforce HTTPS redirect (safe)
  cat <<'EOF' > /etc/httpd/conf.d/99-vicidial-https.conf
<VirtualHost *:80>
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>
EOF

  systemctl reload httpd
else
  log_info "HTTPS not enabled (ENABLE_HTTPS != yes)"
fi

# -----------------------------------------------------------------------------
# 2. WebRTC Preparation (NO functional enablement)
# -----------------------------------------------------------------------------
if [[ "${ENABLE_WEBRTC_PREP:-no}" == "yes" ]]; then
  log_info "Preparing system for future WebRTC usage"

  # Verify required Asterisk modules exist
  for mod in res_http_websocket.so res_srtp.so; do
    if ! asterisk -rx "module show like ${mod}" | grep -q "${mod}"; then
      log_warn "Asterisk module missing: ${mod}"
    fi
  done

  # RTP range sanity (does NOT change firewall)
  cat <<EOF > /etc/sysctl.d/98-asterisk-rtp.conf
net.ipv4.ip_local_port_range = 10000 65000
EOF

  sysctl --system
else
  log_info "WebRTC prep not enabled (ENABLE_WEBRTC_PREP != yes)"
fi

# -----------------------------------------------------------------------------
# 3. Monitoring Hooks (NO agents by default)
# -----------------------------------------------------------------------------
if [[ "${ENABLE_MONITORING_HOOKS:-no}" == "yes" ]]; then
  log_info "Installing lightweight monitoring hooks"

  # Node exporter (optional, passive)
  dnf -y install node_exporter || log_warn "node_exporter not available"

  systemctl enable node_exporter --now || true

  # Simple local health endpoint
  cat <<'EOF' > /usr/local/bin/vicidial-health.sh
#!/usr/bin/env bash
asterisk -rx "core show uptime" >/dev/null 2>&1 || exit 1
mysqladmin ping >/dev/null 2>&1 || exit 1
exit 0
EOF

  chmod +x /usr/local/bin/vicidial-health.sh
else
  log_info "Monitoring hooks not enabled (ENABLE_MONITORING_HOOKS != yes)"
fi

# -----------------------------------------------------------------------------
# 4. Light Security Hardening (NON-BLOCKING)
# -----------------------------------------------------------------------------
if [[ "${ENABLE_LIGHT_HARDENING:-no}" == "yes" ]]; then
  log_info "Applying light security hardening"

  # Apache security headers (safe)
  cat <<'EOF' > /etc/httpd/conf.d/99-security-headers.conf
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
EOF

  systemctl reload httpd

  # Fail2ban (OPTIONAL – SIP jails NOT enabled automatically)
  dnf -y install fail2ban || log_warn "fail2ban install failed"
  systemctl enable fail2ban --now || true
else
  log_info "Light hardening not enabled (ENABLE_LIGHT_HARDENING != yes)"
fi

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 08 completed – modern extras applied (optional)"
stage_finish "${STAGE_NAME}"