systemctl is-active --quiet asterisk
asterisk -rx "core show version" | grep -q "18"

strings /usr/sbin/asterisk | grep -i vicidial || true