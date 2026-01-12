source "$(dirname "$0")/../lib/common.sh"


require_service httpd
require_port 80
php -m | grep -q mysqlnd || fail "PHP mysqlnd missing"

log "Configuring PHP Opcache"

OPCACHE_FILE=/etc/php.d/10-opcache.ini

if [[ ! -f "$OPCACHE_FILE" ]]; then
  cat <<EOF > "$OPCACHE_FILE"
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=32
opcache.max_accelerated_files=100000
opcache.validate_timestamps=1
opcache.revalidate_freq=5
opcache.fast_shutdown=1
EOF
  log "Opcache config created"
else
  log "Opcache config already exists"
fi

php -i | grep -q "opcache.enable => On" \
  || die "PHP Opcache not active"

ok "PHP Opcache enabled"

log "Self-validation completed for $(basename "$0")"
