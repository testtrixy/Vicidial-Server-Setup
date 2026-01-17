Below is a final, release-grade README.md, written so that:

A new engineer can run the installer safely

A senior engineer can audit guarantees quickly

Past failure modes (MariaDB, SIP, AMI) are explicitly addressed

It matches the EL9-Golden certification we just completed

You can copy-paste this as-is into your ZIP.

VICIdial EL9 Golden Installer

Status: ✅ EL9-GOLDEN (Certified)
Target OS: Rocky Linux 9 / AlmaLinux 9
Asterisk: 18 (Vicidial-patched)
Database: MariaDB (EL9 AppStream)
Release Model: Fail-fast, smoke-gated, deterministic

1. Overview

This installer provides a production-safe, deterministic installation of VICIdial on Enterprise Linux 9.

It is designed to eliminate common failure modes seen on EL9 systems, including:

MySQL vs MariaDB driver conflicts

Socket vs TCP database ambiguity

Missing legacy SIP (chan_sip) support

Asterisk Manager Interface (AMI) timeouts

Silent install hangs and partial states

The installer enforces strict stage contracts and will fail fast if any invariant is violated.

2. Supported Platform
Component	Requirement
OS	Rocky Linux 9 / AlmaLinux 9
Architecture	x86_64
SELinux	Disabled (installer enforces this)
Firewall	firewalld (enabled, ports managed later)
Internet	Required (build + downloads)

❌ Not supported

EL7 / EL8

Debian / Ubuntu

Oracle Linux (untested)

MySQL (explicitly forbidden)

3. Installer Structure
installer/
├── install.sh                # Single entry point
├── lib/
│   └── common.sh             # Shared helpers & fatal handling
├── stages/
│   ├── 01_os_base.sh
│   ├── 02_web_db.sh
│   ├── 02b_db_client.sh
│   ├── 03_db_init.sh
│   ├── 04_telephony.sh
│   ├── 05_vicidial_core.sh
│   ├── 06_automation.sh
│   └── 07_audio_codecs.sh
├── tools/
│   ├── run_smoke_test.sh
│   ├── smoke_cleanup_v2.0_hardened.sh
│   └── release_gate.sh
└── README.md

4. Installation Flow (Authoritative)
Step 1 — Run Installer
chmod +x install.sh
./install.sh

Step 2 — Mandatory Reboot

After Stage 01, the installer requires a reboot.

You will see:

REBOOT REQUIRED before proceeding to Stage 02


Reboot the system, then re-run:

./install.sh


The installer will resume automatically.

5. Stage Responsibilities
Stage	Purpose
01	OS hardening, MySQL hard-block, SELinux disable
02	MariaDB + Apache + PHP (EL9 AppStream only)
02b	Lite DB client deps (telephony node)
03	VICIdial database schema & users
04	DAHDI, LibPRI, LibSRTP, Asterisk 18 build
05	VICIdial core config (astguiclient.conf)
06	Automation: systemd, AMI, cron
07	Audio codecs & sounds

Each stage leaves a marker file.
If a marker is missing, later stages will fail immediately.

6. Hard Contracts (Never Violated)

The installer enforces the following global invariants:

🚫 MySQL is forbidden
rpm -qa | grep -Eq 'mysql|community-mysql' && FAIL

✅ MariaDB must be reachable via TCP
mysql -h 127.0.0.1 -P 3306 -e "SELECT 1"

✅ DBI must use MariaDB driver
perl -MDBI -e 'print join(", ", DBI->available_drivers)'

✅ Legacy SIP must exist
asterisk -rx "sip show peers"

✅ AMI must be enabled
asterisk -rx "manager show settings"


If any of these fail, the installer aborts immediately.

7. Database Model (IMPORTANT)

Canonical DB Access Rules:

Setting	Value
Host	127.0.0.1
Port	3306
Socket	unused
Users	Bound to 127.0.0.1 only

localhost, sockets, and % users are intentionally not used to avoid EL9 DBI failures.

8. SIP / Asterisk Model

Both chan_sip and chan_pjsip are built

VICIdial requires legacy SIP CLI commands

Installer enforces:

sip show peers
sip show settings


If chan_sip is missing, the install fails during Stage 04, not later.

9. Smoke Test (Release Gate)

After installation:

./tools/run_smoke_test.sh


This validates:

Web login

Database connectivity

Asterisk runtime

SIP CLI availability

AMI command execution

🔒 Release Rule

❌ Smoke fails → DO NOT SHIP
✅ Smoke passes → Release allowed

10. One-Command Release Verification

Before cutting a ZIP, run:

./tools/release_gate.sh


If it prints:

RELEASE OK – EL9-GOLDEN


You are clear to ship.

11. Troubleshooting Philosophy

This installer is designed so that:

Failures are early

Errors are explicit

Silent hangs do not exist

If something fails:

Read the fatal message

Fix the contract violation

Re-run install.sh

No cleanup is required unless explicitly stated.

12. Versioning & Release Policy

Recommended tag format:

vicidial-installer-el9-vX.Y.Z


Increment version only when:

A stage contract changes

Smoke tests change

Asterisk / MariaDB versions change

13. Final Notes

This installer has been:

Architecturally reviewed

Failure-mode tested

EL9-specific issues eliminated

Certified as EL9-GOLDEN

It is safe for:

Fresh installs

Reprovisioned hosts

Team handoff

Automation pipelines