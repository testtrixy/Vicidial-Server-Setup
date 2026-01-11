#!/bin/bash
echo "=== STEP 07: Asterisk ==="

cd /usr/src
wget -q http://download.vicidial.com/required-apps/asterisk-13.29.2-vici.tar.gz
tar xzf asterisk-13.29.2-vici.tar.gz
cd asterisk-13.29.2

./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled


#make menuselect

echo "=== STEP 07: Auto select Menue ==="
menuselect/menuselect \
  --enable app_meetme \
  --enable res_srtp \
  --enable res_http_websocket \
  menuselect.makeopts



make && make install
make samples
make config

echo "[OK] Asterisk installed"
