#!/bin/bash
source lib/common.sh
log "Executing phase: 04-asterisk-build.sh"
# Logic goes here

#!/bin/bash
set -e

cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz
tar xzf asterisk-${ASTERISK_VERSION}.tar.gz
cd asterisk-${ASTERISK_VERSION}

./configure --with-jansson-bundled
make menuselect.makeopts

# REQUIRED for VICIDIAL
menuselect/menuselect \
  --enable chan_sip \
  --enable app_meetme \
  --enable pbx_config \
  --disable pbx_ael \
  --disable res_config_mysql \
  menuselect.makeopts

make -j$(nproc)
make install
make samples
make config

systemctl enable asterisk
