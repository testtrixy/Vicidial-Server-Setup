#!/bin/bash
echo "=== STEP 02: Repositories & Base Packages ==="

yum -y install epel-release
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
yum -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
yum -y install yum-utils

dnf module enable php:remi-7.4 -y
dnf config-manager --set-enabled powertools

echo "[+] Installing development tools"
yum groupinstall "Development Tools" -y

echo "[+] Installing system packages"



yum install -y \
php php-cli php-gd php-curl php-mysql php-ldap php-zip php-mbstring \
php-imap php-xml php-xmlrpc php-pear php-opcache \
httpd wget unzip curl screen sox sendmail mutt \
kernel-devel kernel-headers openssl-devel \
libpcap libpcap-devel ncurses-devel newt-devel \
htop iftop certbot mod_ssl mariadb-devel \
subversion 


yum install -y \
  nc \
  mutt \
  patch \
  libedit-devel

  



yum install -y \
perl-File-Which \
libxml2-devel \
sqlite-devel \
libuuid-devel \
ImageMagick \
lame-devel






echo "[OK] Repos & packages installed"


# need to add these 
# perl-File-Which libpcap-devel newt-devel libxml2-devel sqlite-devel libuuid-devel sendmail ImageMagick
