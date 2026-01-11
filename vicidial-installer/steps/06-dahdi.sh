#!/bin/bash
echo "=== STEP 06: DAHDI ==="

cd /usr/src
wget -q http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
tar xzf dahdi-linux-complete-current.tar.gz
cd dahdi-linux-complete-*

sed -i '/pci-aspm/d' linux/include/dahdi/kernel.h

make && make install && make install-config
yum install -y dahdi-tools-libs


echo "dahdi_dummy" > /etc/modules-load.d/dahdi.conf
modprobe dahdi_dummy

modprobe dahdi
/usr/sbin/dahdi_cfg -vvvvvvvvvvvvv || true
lsmod | grep dahdi || echo "WARN: DAHDI not loaded"



echo "[OK] DAHDI installed"
