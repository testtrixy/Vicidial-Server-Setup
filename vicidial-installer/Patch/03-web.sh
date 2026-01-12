require_service httpd
require_port 80
php -m | grep -q mysqlnd || fail "PHP mysqlnd missing"