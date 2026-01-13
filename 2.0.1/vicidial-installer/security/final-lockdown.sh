#!/usr/bin/env bash
set -e

# Ensure services auto-start
systemctl enable httpd mariadb asterisk crond

# Remove installer leftovers
rm -f /root/*.sql || true
rm -f /root/*.sh || true

echo "SYSTEM HARDENING COMPLETE"
