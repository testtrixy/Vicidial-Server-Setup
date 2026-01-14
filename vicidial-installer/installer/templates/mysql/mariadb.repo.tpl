
[mariadb]
name = MariaDB {{ MARIADB_VERSION }}
baseurl = https://downloads.mariadb.com/MariaDB/mariadb-{{ MARIADB_VERSION }}/yum/rhel/$releasever/$basearch
module_hotfixes = 1
gpgkey = https://downloads.mariadb.com/MariaDB/mariadb-{{ MARIADB_VERSION }}/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1