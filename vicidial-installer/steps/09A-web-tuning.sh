#!/bin/bash
set -euo pipefail

exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"

echo "=================================================="
echo " STEP 09A: APACHE & PHP UI STABILITY TUNING"
echo "=================================================="

APACHE_CONF="/etc/httpd/conf/httpd.conf"

# ---------------------------------------------------
# Apache Directory permissions for VICIdial
# ---------------------------------------------------

echo "[+] Configuring Apache directory permissions"

if ! grep -q 'Directory "/var/www/html"' "$APACHE_CONF"; then
  cat <<'EOF' >> "$APACHE_CONF"

# VICIdial Web UI Permissions
<Directory "/var/www/html">
    AllowOverride All
    Require all granted
</Directory>
EOF
else
  # Ensure required directives exist
  sed -i \
    -e '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride .*/AllowOverride All/' \
    -e '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/Require .*/Require all granted/' \
    "$APACHE_CONF"
fi

echo "[OK] Apache permissions configured"



# ---------------------------------------------------
# PHP.ini tuning for VICIdial Admin UI
# ---------------------------------------------------

PHP_INI=$(php --ini | awk -F': ' '/Loaded Configuration/{print $2}')

echo "[+] Tuning PHP settings in $PHP_INI"

set_php_ini () {
  local key="$1"
  local value="$2"

  if grep -q "^$key" "$PHP_INI"; then
    sed -i "s|^$key.*|$key = $value|" "$PHP_INI"
  else
    echo "$key = $value" >> "$PHP_INI"
  fi
}

set_php_ini memory_limit 512M
set_php_ini max_execution_time 360
set_php_ini max_input_time 360

echo "[OK] PHP settings applied"



echo "[+] Restarting Apache & PHP"

systemctl restart httpd

echo "[OK] Web stack restarted"
