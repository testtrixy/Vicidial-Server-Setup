#!/usr/bin/env bash
set -e

PHPINI=$(php --ini | grep "Loaded Configuration" | awk '{print $4}')

sed -i 's/^expose_php.*/expose_php = Off/' $PHPINI
sed -i 's/^display_errors.*/display_errors = Off/' $PHPINI
sed -i 's/^memory_limit.*/memory_limit = 256M/' $PHPINI
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 64M/' $PHPINI
sed -i 's/^post_max_size.*/post_max_size = 64M/' $PHPINI
sed -i 's/^max_execution_time.*/max_execution_time = 330/' $PHPINI
sed -i 's/^short_open_tag.*/short_open_tag = On/' $PHPINI

systemctl restart httpd
