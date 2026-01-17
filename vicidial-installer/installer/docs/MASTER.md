Below is a **clean, complete, production-grade `MASTER.md`** for your repository.
It reflects **everything we designed, fixed, and locked**, and it is written so that:

* Ops teams can follow it
* Auditors can understand it
* Future maintainers don’t break it
* You don’t have to explain things verbally

This is the **canonical document** for the repo.

---

# 📘 Vicidial 2026 – Master Installation & Architecture Guide

## 1. Purpose of This Repository

This repository provides a **deterministic, production-grade installer** for **Vicidial 2026** on **EL9 (Rocky Linux / AlmaLinux)**.

The goal is to:

* Replace legacy “one-big-script” installs
* Enforce a **clear SDLC-style lifecycle**
* Separate **core dialing logic** from **optional enhancements**
* Make the system **auditable, repeatable, and safe to operate**

This installer is suitable for:

* Production call centers
* Cloud deployments
* Enterprise / PE-grade environments
* CI / automated provisioning

---

## 2. Design Principles (Non-Negotiable)

This installer follows these principles strictly:

1. **Stage Isolation**
   Each stage has a single responsibility.

2. **Idempotency**
   Stages can be re-run safely.

3. **No Hidden Side Effects**
   No silent installs of optional or licensed components.

4. **Explicit Risk Handling**
   Proprietary codecs and modern extras require opt-in.

5. **Auditability**
   Configuration, secrets, and features are separated.

6. **Dialing First**
   Optional features must never block core dialing.

---

## 3. Supported Platform

| Component    | Supported                   |
| ------------ | --------------------------- |
| OS           | Rocky Linux 9 / AlmaLinux 9 |
| Architecture | x86_64                      |
| Asterisk     | 18 (Vicidial-patched)       |
| Database     | MariaDB 10.11               |
| PHP          | 7.4 (Remi)                  |
| Init system  | systemd                     |

---

## 4. Repository Structure

```text
installer/
├── MASTER.md                 # This document
├── install.sh                # Master orchestrator
├── config/
│   ├── versions.env          # Version pinning
│   ├── paths.env             # Filesystem paths & constants
│   ├── secrets.env           # Credentials (DO NOT COMMIT REAL SECRETS)
│   └── features.env          # Optional feature flags (all OFF by default)
├── lib/
│   ├── common.sh             # Shared helpers, guards, logging
│   └── render.sh             # Template rendering logic
├── templates/
│   ├── asterisk/             # Asterisk configs (AMI, etc.)
│   ├── mysql/                # DB templates (future use)
│   └── vicidial/             # Vicidial configs
├── stages/
│   ├── 01_os_base.sh
│   ├── 02_web_db.sh
│   ├── 03_build_env.sh
│   ├── 04_telephony.sh
│   ├── 05_vicidial_core.sh
│   ├── 06_automation.sh
│   ├── 07_audio_codecs.sh
│   ├── 07a_proprietary_codecs.sh   # OPTIONAL / MANUAL
│   └── 08_modern_extras.sh          # OPTIONAL
└── health/
    └── healthcheck.sh         # Read-only system validation
```

---

## 5. Configuration Files (Important)

### 5.1 `config/versions.env`

Defines **exact versions** used in the build.

Examples:

```bash
PHP_VERSION=7.4
ASTERISK_VERSION=18.21.0
MARIADB_VERSION=10.11
```

🔒 **Do not float versions silently.**

---

### 5.2 `config/paths.env`

Defines filesystem paths and constants.

Examples:

```bash
VICIDIAL_HOME=/usr/share/astguiclient
ASTERISK_ETC=/etc/asterisk
VICIDIAL_DB_NAME=asterisk
```

---

### 5.3 `config/secrets.env`

Contains sensitive values.

Examples:

```bash
VARDB_USER=cron
VARDB_PASS=strongpassword
AMI_CRON_SECRET=strongsecret
ADMIN_EMAIL=admin@example.com
```

⚠️ **Never commit real secrets to git.**

---

### 5.4 `config/features.env` (IMPORTANT)

Controls **optional functionality**.
All values must default to `no`.

```bash
ENABLE_HTTPS=no
ENABLE_WEBRTC_PREP=no
ENABLE_MONITORING_HOOKS=no
ENABLE_LIGHT_HARDENING=no
```

This file is sourced **once** by `install.sh` and applies globally.

---

## 6. Installation Stages (Authoritative)

### Stage 01 – OS Base

**Purpose**

* OS hardening
* SELinux disable (with reboot requirement)
* Base packages
* Kernel tuning

---

### Stage 02 – Web & Database

**Purpose**

* MariaDB 10.11
* Apache
* PHP 7.4 (Remi)
* DB performance tuning

---

### Stage 03 – Build Environment

**Purpose**

* Development tools
* Perl & CPAN modules
* Asterisk::Perl

---

### Stage 04 – Telephony Core

**Purpose**

* DAHDI (Git master for EL9)
* LibPRI (Vicidial-pinned)
* LibSRTP
* Asterisk 18 (Vicidial-patched)

---

### Stage 05 – Vicidial Core

**Purpose**

* Vicidial source install
* Database bootstrap (`asterisk`)
* `/etc/astguiclient.conf`
* Non-interactive install

---

### Stage 06 – Automation & Hardening

**Purpose**

* Full Vicidial cron set
* Keepalive watchdog
* DB optimization
* AMI hardening (localhost only)
* systemd reliability

---

### Stage 07 – Audio & Open Codecs

**Purpose**

* Asterisk sound files
* MOH
* WAV / MP3 tools
* Open, license-safe media support

---

### Stage 07a – Proprietary Codecs (OPTIONAL)

**Purpose**

* G.729 / G.723.1 (binary)

⚠️ **Not executed automatically**
⚠️ Requires explicit environment flags
⚠️ Operator assumes licensing responsibility

---

### Stage 08 – Modern Extras (OPTIONAL)

**Purpose**

* HTTPS (Certbot)
* WebRTC preparation (non-invasive)
* Monitoring hooks
* Light security headers

All features are opt-in via `features.env`.

---

## 7. Health Check

### `health/healthcheck.sh`

* Read-only
* No restarts
* No mutations
* CI-friendly exit codes
* Color output (TTY-safe)

Validates:

* OS & time sync
* Database
* Asterisk
* Vicidial core
* Cron jobs
* AMI security
* Audio assets
* Optional features (if enabled)

Run:

```bash
./health/healthcheck.sh
```

Exit codes:

* `0` → Healthy
* `1` → Action required

---

## 8. What This Installer Will NOT Do

* Install proprietary codecs silently
* Modify firewall rules aggressively
* Assume DAHDI hardware exists
* Use legacy `screen` processes
* Rely on root DB access
* Hide configuration or secrets

---

## 9. Operational Guidance

### Recommended Flow

1. Fresh EL9 server
2. Run `install.sh`
3. Reboot when prompted (Stage 01)
4. Re-run `install.sh`
5. Configure Vicidial UI
6. Run `health/healthcheck.sh`

---

## 10. Final Status

This installer is:

* ✅ Production-ready
* ✅ Auditable
* ✅ Safe by default
* ✅ Modular
* ✅ Future-proof

**This `MASTER.md` is the source of truth.**

\