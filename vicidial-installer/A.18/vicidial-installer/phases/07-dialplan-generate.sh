#!/bin/bash
source lib/common.sh
log "Executing phase: 07-dialplan-generate.sh"
# Logic goes here

#!/bin/bash
set -e

log "Running ADMIN_update_server_ip.pl"
/usr/share/astguiclient/ADMIN_update_server_ip.pl

log "SECOND install.pl run (dialplan generation)"
cd /usr/src/astguiclient
perl install.pl --no-prompt

log "Forcing AST_update"
asterisk -rx "core reload"
