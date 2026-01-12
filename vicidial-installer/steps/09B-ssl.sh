#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 09B: HTTPS (Browser Auth UX FIX)"
echo "=================================================="

yum install -y certbot python3-certbot-apache

if ! certbot certificates | grep -q "$PUBLIC_IP"; then
  echo "[+] Requesting Let’s Encrypt certificate"
  certbot --apache \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    -d "$PUBLIC_IP"
else
  echo "[OK] SSL certificate already exists"
fi

systemctl reload httpd
echo "[OK] HTTPS enabled — browser auth UX fixed permanently"
