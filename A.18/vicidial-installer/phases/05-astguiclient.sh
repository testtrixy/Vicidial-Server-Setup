#!/bin/bash
source lib/common.sh
log "Executing phase: 05-astguiclient.sh"
# Logic goes here

#!/bin/bash
set -e

cd /usr/src
svn checkout svn://svn.vicidial.org/agc/${AGC_BRANCH} astguiclient
cd astguiclient

# FIRST RUN (copies files)
perl install.pl --no-prompt
