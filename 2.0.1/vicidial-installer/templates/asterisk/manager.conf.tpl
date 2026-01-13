[general]
enabled = yes
port = {{AMI_PORT}}
bindaddr = {{AMI_BIND_IP}}
displayconnects = no
timestampevents = yes

; ===============================
; VICIDIAL CORE AMI USER
; ===============================

[{{AMI_USER}}]
secret = {{AMI_SECRET}}

read = system,call,log,verbose,command,agent,user,originate,config
write = system,call,log,verbose,command,agent,user,originate,config

deny = 0.0.0.0/0.0.0.0
permit = {{AMI_PERMIT_NET}}
