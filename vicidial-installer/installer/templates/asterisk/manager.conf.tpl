[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1
displayconnects = no

[cron]
secret = ${AMI_CRON_SECRET}
read = system,call,log,verbose,command,agent,user,originate
write = system,call,log,verbose,command,agent,user,originate
