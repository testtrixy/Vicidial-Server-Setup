WHY THESE PACKAGES EXIST (DO NOT SKIP)
Package	Required For
jansson-devel	JSON handling (AMI / ARI)
libedit-devel	CLI editing
unixODBC-devel	VICIDial DB access
speex / opus	Modern codecs
sox	Recording processing
mariadb-connector-c-devel	AGI DB calls
ncurses-devel	Asterisk CLI
pcre-devel	Dialplan regex
libuuid-devel	Channel UUIDs
openssl-devel	SIP-TLS / HTTPS

👉 All of these are used by Asterisk 18
👉 Several older guides MISS jansson & libedit — you did not

📍 INSTALLER FLOW (WHERE THIS FITS)

Your correct execution order is now:

installer/os/00-rocky9-base.sh
reboot

installer/asterisk/01-install-deps.sh
installer/asterisk/02-download-asterisk.sh


⚠️ Do NOT skip reboot after base OS

🧪 VERIFICATION (RUN THIS)
gcc --version
make --version
pkg-config --modversion jansson
pkg-config --modversion libedit
mysql_config --version


All must return versions.

⚠️ COMMON ROCKY 9 MISTAKES YOU AVOIDED
Mistake	Why it breaks
Missing CRB	No devel libs
Using mysql-devel	Wrong ABI
Installing DAHDI early	Conflicts
Using old ncurses	CLI crashes
Missing libedit	Broken Asterisk CLI



------
02
-----



----

03
-----

----
04
----


---
05
---


----