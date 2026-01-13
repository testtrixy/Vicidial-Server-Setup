mysql asterisk -e "show tables;" | grep -q vicidial_users
mysql asterisk -e "select count(*) from servers;" | grep -q "[1-9]"
