#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 09A: APACHE & PHP UI STABILITY TUNING"
echo "=================================================="

# ---------------------------------------------------
# Sanity check
# ---------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "[FATAL] Must be run as root"
  exit 1
fi

# ---------------------------------------------------
# Apache Directory permissions (BEST PRACTICE)
# ---------------------------------------------------
echo "[+] Configuring Apache directory permissions"

APACHE_VHOST="/etc/httpd/conf.d/vicidial.conf"

cat <<'EOF' > "$APACHE_VHOST"
# VICIdial Web UI Permissions
<Directory "/var/www/html">
    AllowOverride All
    Require all granted
</Directory>
EOF

echo "[OK] Apache permissions configured"

# ---------------------------------------------------
# Detect php.ini (Rocky 8 / Remi SAFE)
# ---------------------------------------------------
PHP_INI=""

# 1️⃣ Preferred: Apache PHP always uses this if present
if [[ -f /etc/php.ini ]]; then
  PHP_INI="/etc/php.ini"
fi

# 2️⃣ Fallback: CLI reported ini
if [[ -z "$PHP_INI" ]] && command -v php >/dev/null 2>&1; then
  PHP_INI=$(php --ini 2>/dev/null | awk -F': ' '/Loaded Configuration/{print $2}')
fi

# 3️⃣ Last resort: Remi SCL path
if [[ -z "$PHP_INI" || ! -f "$PHP_INI" ]]; then
  if [[ -f /etc/opt/remi/php74/php.ini ]]; then
    PHP_INI="/etc/opt/remi/php74/php.ini"
  fi
fi

# Final validation
if [[ -z "$PHP_INI" || ! -f "$PHP_INI" ]]; then
  echo "[FATAL] php.ini not found (checked /etc/php.ini, php --ini, remi path)"
  exit 1
fi

echo "[OK] Using php.ini: $PHP_INI"

# ---------------------------------------------------
# PHP tuning (IDEMPOTENT)
# ---------------------------------------------------
set_php_ini() {
  local key="$1"
  local value="$2"

  if grep -qE "^[; ]*$key\s*=" "$PHP_INI"; then
    sed -i "s|^[; ]*$key\s*=.*|$key = $value|" "$PHP_INI"
  else
    echo "$key = $value" >> "$PHP_INI"
  fi
}

echo "[+] Applying PHP performance tuning"

set_php_ini memory_limit 512M
set_php_ini max_execution_time 360
set_php_ini max_input_time 360

echo "[OK] PHP settings applied"

# ---------------------------------------------------
# Restart services safely
# ---------------------------------------------------
echo "[+] Restarting web services"

systemctl restart httpd

# Restart PHP-FPM only if present
if systemctl list-unit-files | grep -q '^php74-php-fpm'; then
  systemctl restart php74-php-fpm
elif systemctl list-unit-files | grep -q '^php-fpm'; then
  systemctl restart php-fpm
fi

# ---------------------------------------------------
# Validation
# ---------------------------------------------------
if ! systemctl is-active --quiet httpd; then
  echo "[FATAL] Apache failed to restart"
  exit 1
fi

echo "[OK] Apache & PHP restarted successfully"
echo "=================================================="
