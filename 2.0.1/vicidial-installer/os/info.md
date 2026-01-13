WHY EACH SECTION EXISTS (VERY IMPORTANT)
Section	Why it matters
SELinux permissive	VICIdial breaks under enforcing; permissive keeps audit logs
Firewall disabled	Avoids SIP/AMI false failures during build
CRB + EPEL	Required for Rocky 9 dev packages
Limits + sysctl	Prevents file-descriptor exhaustion
chrony	Call timestamps & DB integrity
No Asterisk here	Clean separation of concerns
🔁 HOW THIS SCRIPT IS CALLED
🔹 Option A (Manual – Recommended for now)
cd installer/os
./00-rocky9-base.sh
reboot


Only proceed after reboot.

🔹 Option B (Master Installer Entry Point – Later)

Your future install.sh will do:

installer/os/00-rocky9-base.sh
installer/asterisk/01-install-deps.sh


But NOT YET.

🧪 VERIFICATION CHECKLIST (DO THIS)

After reboot, confirm:

getenforce
# → Permissive

timedatectl
# → UTC

sysctl fs.file-max
# → 1000000

ulimit -n
# → 100000 (or higher)

dnf repolist | grep -E "epel|crb"