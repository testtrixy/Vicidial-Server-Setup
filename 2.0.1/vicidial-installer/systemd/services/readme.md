HOW THIS FITS INTO YOUR INSTALLER (IMPORTANT)

Your installer flow now looks like this:

🧱 INSTALLER STEP ORDER (REQUIRED)
1️⃣ Install system packages

perl

mariadb

asterisk

astguiclient

2️⃣ Install VICIDIAL scripts
/usr/share/astguiclient/*.pl


⚠️ systemd services depend on these existing

3️⃣ Generate systemd unit files

Example:

generate_systemd_units() {
  cp systemd/services/*.service /etc/systemd/system/
  cp systemd/timers/*.timer /etc/systemd/system/
}

4️⃣ Reload systemd
systemctl daemon-reexec
systemctl daemon-reload

5️⃣ Enable services
systemctl enable --now vicidial-keepalive
systemctl enable --now vicidial-hopper
systemctl enable --now vicidial-hungcalls

6️⃣ REMOVE old cron jobs
crontab -r


(or selectively remove VICIDIAL ones)

🧪 HOW YOU VERIFY IT WORKS (THIS IS KEY)
Check services
systemctl status vicidial-keepalive
systemctl status vicidial-hopper

Check logs
journalctl -u vicidial-keepalive -f
journalctl -u vicidial-hopper -f