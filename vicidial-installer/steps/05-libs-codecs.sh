#!/bin/bash
echo "=== STEP 05: Codecs & Libraries ==="


dnf --enablerepo=powertools install libsrtp-devel -y

cd /usr/src
wget -q http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz
tar xzf lame-3.99.5.tar.gz
cd lame-3.99.5
./configure && make && make install

cd /usr/src
wget -q https://digip.org/jansson/releases/jansson-2.13.tar.gz
tar xzf jansson-2.13.tar.gz
cd jansson-2.13
./configure && make && make install
ldconfig


cd /usr/src
wget http://download.vicidial.com/required-apps/asterisk-perl-0.08.tar.gz
tar xzf asterisk-perl-0.08.tar.gz
cd asterisk-perl-0.08
perl Makefile.PL
make
make install


echo "[OK] Codecs installed"
