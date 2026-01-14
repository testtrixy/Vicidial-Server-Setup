[mysqld]
bind-address = ${MYSQL_BIND_ADDRESS}

max_connections = ${MYSQL_MAX_CONNECTIONS}
open_files_limit = 65535
skip-name-resolve

# InnoDB
innodb_buffer_pool_size = ${MYSQL_INNODB_BUFFER_POOL}
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 512M
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT

# Caches
thread_cache_size = 100
table_open_cache = 4096
