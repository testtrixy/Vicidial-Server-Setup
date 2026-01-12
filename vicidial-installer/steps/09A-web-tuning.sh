#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 09A: APACHE, PHP & AUTH UX FIX"
echo "=================================================="

APACHE_VHOST="/etc/httpd/conf.d/vicidial.conf"

echo "[+] Writing Apache VICIdial vhost with AUTH + HTTPS-ready config"

cat <<EOF > "$APACHE_VHOST"
<VirtualHost *:80>
    ServerName ${PUBLIC_IP}
    DocumentRoot /var/www/html

    <Directory "/var/www/html/vicidial">
        AuthType Basic
        AuthName "CONTACT-CENTER-ADMIN"
        AuthUserFile /etc/httpd/conf/vicidial.auth
        Require valid-user
        AllowOverride All
    </Directory>

    # Redirect ALL VICIdial traffic to HTTPS
    RewriteEngine On
    RewriteCond %{REQUEST_URI} ^/vicidial
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [L,R=301]
</VirtualHost>
EOF

echo "[OK] Apache VICIdial vhost written"

# ---------------------------------------------------
# Ensure auth file exists
# ---------------------------------------------------
if [ ! -f /etc/httpd/conf/vicidial.auth ]; then
  echo "[+] Creating default VICIdial HTTP auth user"
  htpasswd -bc /etc/httpd/conf/vicidial.auth 6666 1234
fi

chmod 640 /etc/httpd/conf/vicidial.auth
chown root:apache /etc/httpd/conf/vicidial.auth

# ---------------------------------------------------
# PHP tuning (safe detection)
# ---------------------------------------------------
PHP_INI=$(php --ini 2>/dev/null | awk -F': ' '/Loaded Configuration/{print $2}')

if [[ -z "$PHP_INI" || ! -f "$PHP_INI" ]]; then
  PHP_INI="/etc/opt/remi/php74/php.ini"
fi

echo "[+] Using php.ini: $PHP_INI"

set_php_ini () {
  local key="$1"
  local value="$2"
  grep -q "^$key" "$PHP_INI" \
    && sed -i "s|^$key.*|$key = $value|" "$PHP_INI" \
    || echo "$key = $value" >> "$PHP_INI"
}

set_php_ini memory_limit 512M
set_php_ini max_execution_time 360
set_php_ini max_input_time 360

echo "[OK] PHP tuned"

systemctl restart httpd
echo "[OK] Apache restarted"

echo "=================================================="
