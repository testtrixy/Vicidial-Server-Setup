#!/usr/bin/env bash
set -e

HTTPD_CONF="/etc/httpd/conf/httpd.conf"

# Hide version info
sed -i 's/^ServerTokens.*/ServerTokens Prod/' $HTTPD_CONF || echo "ServerTokens Prod" >> $HTTPD_CONF
sed -i 's/^ServerSignature.*/ServerSignature Off/' $HTTPD_CONF || echo "ServerSignature Off" >> $HTTPD_CONF

# Disable directory listing
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' $HTTPD_CONF || true

# Restrict root filesystem
cat <<EOF >> $HTTPD_CONF

<Directory />
  AllowOverride none
  Require all denied
</Directory>
EOF

systemctl restart httpd
