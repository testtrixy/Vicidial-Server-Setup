# DB connectivity
perl -MDBI -e 'DBI->connect("DBI:mysql:database=asterisk;host=localhost","cron","1234") && print "DB OK\n";'

# AMI
asterisk -rx "manager show connected"

# Cron jobs present
crontab -l | grep astguiclient

# Log activity
ls -ltr /var/log/astguiclient | tail