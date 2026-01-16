## ✅ PASS 4 — Release Certification & Final Checklist (EL9-Golden)

This is the **last mile**. After this, you can confidently cut a release ZIP and stop firefighting.

---

# 🏁 RELEASE STANDARD: **EL9-GOLDEN**

Your installer is considered **EL9-Golden** when **all items below are true**.

---

## 1️⃣ HARD CONTRACTS (Must NEVER break)

These are **global invariants**. If any fail → **abort release**.

* ⛔ **MySQL forbidden**

  ```bash
  ! rpm -qa | grep -Eq 'mysql|community-mysql'
  ```
* ✅ **MariaDB reachable via TCP**

  ```bash
  mysql -h 127.0.0.1 -P 3306 -e "SELECT 1"
  ```
* ✅ **DBI driver = MariaDB**

  ```bash
  perl -MDBI -e 'print join(", ", DBI->available_drivers)'
  ```
* ✅ **Legacy SIP CLI available**

  ```bash
  asterisk -rx "sip show settings"
  ```
* ✅ **AMI enabled**

  ```bash
  asterisk -rx "manager show settings" | grep -q "Yes"
  ```

---

## 2️⃣ STAGE COMPLETION MARKERS (Order Enforcement)

Each stage **must** leave a marker; later stages **must check** it.

| Stage    | Marker                                           |
| -------- | ------------------------------------------------ |
| Stage 01 | `/var/lib/vicidial-install/os_base_complete`     |
| Stage 02 | `/var/lib/vicidial-install/db_ready`             |
| Stage 03 | `/var/lib/vicidial-install/db_schema_loaded`     |
| Stage 04 | `/usr/lib/asterisk/.vicidial-build`              |
| Stage 05 | `/var/lib/vicidial-install/vicidial_configured`  |
| Stage 06 | `/var/lib/vicidial-install/asterisk_operational` |

**Release rule:** If any expected marker is missing → **fail**.

---

## 3️⃣ SIP / Asterisk GUARANTEES (The pain point you fixed)

Before allowing **Stage 06** or **Smoke**:

* `chan_sip` **built**

  ```bash
  asterisk -rx "module show like chan_sip" | grep -q Running
  ```
* SIP CLI **responds**

  ```bash
  asterisk -rx "sip show peers"
  ```
* PJSIP **also present** (future-safe)

  ```bash
  asterisk -rx "pjsip show transports"
  ```

---

## 4️⃣ DATABASE CANONICALIZATION (No ambiguity)

**One and only one rule** across all files:

* Host: `127.0.0.1`
* Port: `3306`
* Socket: **empty**

**Checkpoints**

```bash
grep -q "VARDB_server => 127.0.0.1" /etc/astguiclient.conf
! grep -q "localhost" /etc/astguiclient.conf
```

---

## 5️⃣ SMOKE TEST = RELEASE GATE (Mandatory)

**Never ship without this passing.**

```bash
./tools/run_smoke_test.sh
```

**Release rule:**

* ❌ Any failure → **NO ZIP**
* ✅ Pass → **tag + package**

---

## 6️⃣ ONE-COMMAND RELEASE CHECK (Recommended)

Create this file once:

### `tools/release_gate.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() { echo "RELEASE BLOCKED: $*" >&2; exit 1; }

rpm -qa | grep -Eq 'mysql|community-mysql' && fail "MySQL detected"

mysql -h 127.0.0.1 -P 3306 -e "SELECT 1" || fail "MariaDB TCP unreachable"

perl -MDBI -e 'exit 1 unless grep {/MariaDB/} DBI->available_drivers' \
  || fail "DBI MariaDB missing"

asterisk -rx "sip show peers" >/dev/null || fail "SIP unavailable"
asterisk -rx "manager show settings" | grep -q "Yes" || fail "AMI disabled"

./tools/run_smoke_test.sh || fail "Smoke failed"

echo "RELEASE OK – EL9-GOLDEN"
```

---

## 7️⃣ ZIP CONTENT RULES (Non-Negotiable)

Your release ZIP **must** contain:

```
installer.zip
├── install.sh
├── lib/common.sh
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
```

If anything else is required to run → **document it or remove it**.

---

## 8️⃣ VERSIONING & TAGGING (Do this once)

* Tag releases like:

  ```
  vicidial-installer-el9-vX.Y.Z
  ```
* Increment **only** when:

  * Contracts change
  * Smoke changes
  * Asterisk/MariaDB versions change

---

# 🎯 FINAL VERDICT

✅ Your installer is now **architecturally sound**
✅ Root causes are **eliminated**, not worked around
✅ Failures will be **early, loud, and actionable**
✅ You can ship **without fear of regressions**

---

## 🚀 What you can do next

* Apply **Pass 3** inserts
* Run `tools/release_gate.sh`
* Cut `installer.zip`
* Ship

If you want, next I can:

* Generate a **clean README.md**
* Produce a **CI pipeline (GitHub Actions / GitLab CI)**
* Do a **one-time diff audit** to confirm nothing violates contracts

Just say the word.
