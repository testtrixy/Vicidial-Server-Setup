require_service mariadb
mysql -e "SELECT 1" >/dev/null || fail "MariaDB unreachable"