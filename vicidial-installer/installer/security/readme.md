# fail2ban-client set asterisk unbanip 39.45.46.15 


Below is a **clean, copy-paste ready “Security” section** you can drop directly into your **README.md**.
It is written in **installer / production documentation style**, aligned with what you actually implemented in `installer_2.5`.

---

# 🔐 Security Architecture (EL9 – Golden)

This installer includes a **production-grade security baseline** designed specifically for **VICIdial on EL9 (Rocky / Alma Linux 9)**.
All controls are **idempotent**, **nftables-native**, and **tested via smoke tests**.

---

## 🎯 Security Goals

* Protect Asterisk (SIP & PJSIP) from brute-force attacks
* Remain compatible with **EL9 nftables**
* Avoid self-lockout during installation
* Keep configuration **auditable and repeatable**
* Detect silent failures via smoke tests

---

## 📁 Security Stages Overview

```text
installer/security/
├── 05_whitelist_ssh_ip.sh
├── 10_pjsip_unlock.sh
├── 20_firewall_baseline.sh
├── 30_fail2ban_asterisk.sh
├── 40_logrotate.sh
└── 90_security_smoke_test.sh
```

Each script is safe to re-run and can be executed independently.

---

## 🔓 10 – PJSIP Unlock (Admin UI Fix)

**Problem:**
VICIdial Admin UI hides PJSIP options by default on newer Asterisk versions.

**Solution:**
The installer updates the database schema to explicitly allow both SIP and PJSIP.

**What it does:**

* Expands `system_settings.allowed_sip_stacks`
* Forces `SIP_and_PJSIP`
* Makes PJSIP selectable in Admin → Phones

**File:**
`installer/security/10_pjsip_unlock.sh`

---

## 🔥 20 – Firewall Baseline (firewalld + nftables)

**Why firewalld?**
EL9 uses **nftables**, not legacy iptables.

**What is opened:**

* `5060–5061 UDP/TCP` → SIP / PJSIP signaling
* `10000–20000 UDP` → RTP audio
* `SSH / HTTP / HTTPS` → management & UI

**Key properties:**

* Persistent rules
* No raw iptables usage
* Safe reloads

**File:**
`installer/security/20_firewall_baseline.sh`

---

## 🛑 30 – Fail2Ban for Asterisk / PJSIP (Critical)

This stage protects the server from **SIP brute-force bots**, which aggressively scan public IPs.

### ✔️ Why the default setup fails

* Modern Asterisk logs include **IP:PORT**
* PJSIP logs differ from legacy chan_sip
* EL9 requires **nftables**, not iptables

### ✔️ What this installer fixes

* Regex matches:

  * `Failed to authenticate`
  * `No matching endpoint found`
  * `Username/auth mismatch`
  * `IP:PORT` patterns
* Uses `nftables-multiport`
* Uses `polling` backend (EL9-safe)
* Supports both SIP and PJSIP

### Files deployed

```text
/etc/fail2ban/filter.d/asterisk.conf
/etc/fail2ban/jail.local
```

### Default behavior

* `maxretry = 3`
* `bantime = 24h`
* Kernel-level traffic drop
* Logs may still appear (expected behavior)

**File:**
`installer/security/30_fail2ban_asterisk.sh`

---

## 🧾 40 – Log Rotation (Disk Protection)

High-volume SIP attacks can fill disks quickly.

**What is rotated:**

* `/var/log/asterisk/messages`
* `/var/log/astguiclient/*`

**Policy:**

* Daily rotation
* Compression enabled
* Safe retention

**File:**
`installer/security/40_logrotate.sh`

---

## 🧷 SSH Auto-Whitelist (Lockout Prevention)

Because many environments use **dynamic public IPs**, the installer automatically:

* Detects current SSH IP
* Adds it to Fail2Ban `ignoreip`
* Prevents accidental self-bans

This is **best-effort** and non-fatal if IP detection fails.

**File:**
`installer/security/05_whitelist_ssh_ip.sh`

---

## 🧪 Security Smoke Test (Validation)

The installer includes a **read-only security smoke test** that verifies the full stack.

### What it checks

* Fail2Ban service running
* Asterisk jail active
* Regex matching real logs
* nftables backend present
* firewalld state
* logrotate configs
* SSH IP whitelist

### No risk

* No bans triggered
* No traffic generated
* Safe for production

**File:**
`installer/security/90_security_smoke_test.sh`

---

## ⚠️ Important Notes

* Seeing SIP attack logs **after banning** is normal
  → packets hit Asterisk but are dropped by nftables
* This is expected and indicates **successful protection**
* For additional hardening:

  * Restrict SIP to VPN or IP allow-list
  * Enable SIP TLS (5061)
  * GeoIP-based blocking

---

## ✅ Security Status After Install

If installation completes successfully:

* SIP brute-force attacks are blocked
* Asterisk is protected at kernel level
* Logs are controlled
* Admin UI fully supports PJSIP
* Installer is EL9-native and future-safe

---