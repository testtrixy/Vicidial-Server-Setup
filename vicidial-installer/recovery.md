# RECOVERY.md — VICIdial Incident & Rebuild Playbook

> **Purpose**
> This document is the **authoritative recovery guide** for VICIdial systems after incidents such as disk loss, partial restores, broken admin pages, or database permission failures.
> It is designed to be followed **under pressure** and assumes **no installer re-run unless explicitly stated**.

---

## 0. Recovery Principles (Read First)

* **Stabilize before fixing** — confirm services and filesystem state
* **Never assume defaults** — always verify
* **One layer at a time** — OS → DB → Web → Perl → DAHDI → VICIdial
* **Use tools** — `vicidial-doctor.sh` and `99-verify.sh` are mandatory

> ⚠️ Do not open the browser until Section 6.

---

## 1. Incident Triage (5 Minutes)

### 1.1 Capture the Situation

Record:

* What failed? (disk, VM, accidental delete, upgrade)
* What was restored? (OS only, DB only, partial `/var/www`)
* Any error messages seen by users

### 1.2 Basic Host Health

```bash
uptime
lsblk
mount
free -m
```

Confirm:

* Root filesystem mounted read-write
* Sufficient free disk
* System clock roughly correct

---

## 2. Service Stabilization (Do Not Skip)

Ensure base services are up:

```bash
systemctl start mariadb httpd
systemctl enable mariadb httpd
```

Disable SELinux temporarily **for recovery only**:

```bash
setenforce 0 || true
```

---

## 3. Database Recovery

### 3.1 Is MariaDB Alive?

```bash
systemctl status mariadb
mysql -e "SELECT 1" || exit 1
```

### 3.2 Restore Database (If Needed)

If DB backup exists:

```bash
mysql asterisk < /path/to/asterisk.sql
```

### 3.3 Fix VICIdial DB User (Most Common Failure)

```sql
mysql -u root
GRANT ALL PRIVILEGES ON asterisk.* TO 'vicidialuser'@'localhost'
  IDENTIFIED BY 'PASSWORD_HERE';
FLUSH PRIVILEGES;
```

### 3.4 Validate DB Credentials

```bash
mysql -u vicidialuser -p asterisk -e "SHOW TABLES;"
```

❌ If this fails, **admin login will fail silently**.

---

## 4. Web Layer Recovery (Admin Page Issues)

### 4.1 Verify VICIdial Web Files

```bash
ls -ld /var/www/html/vicidial/admin.php
```

If missing → restore from backup or installer artifacts.

### 4.2 Remove Apache Default Test Page

```bash
mv /var/www/html/index.html /root/index.html.bak 2>/dev/null || true
```

### 4.3 Fix Ownership & Permissions

```bash
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
```

### 4.4 PHP Sanity Check

```bash
php -m | grep -E 'mysqlnd|mbstring|xml|gd'
```

Install missing modules if required.

---

## 5. SELinux Permanent Fix (After Recovery)

If SELinux must remain enabled:

```bash
setsebool -P httpd_can_network_connect_db 1
setsebool -P httpd_execmem 1

chcon -R -t httpd_sys_content_t /var/www/html
chcon -R -t httpd_sys_rw_content_t /var/www/html/vicidial

setenforce 1
```

---

## 6. astguiclient & Perl Layer

### 6.1 Validate astguiclient.conf

```bash
cat /etc/astguiclient.conf
```

Confirm:

* DB name
* User
* Password

### 6.2 Perl Module Check

```bash
perl -MDBI -e1
perl -MUnicode::Map -e1
```

Install missing modules using `cpanm` if needed.

---

## 7. DAHDI & Timing Recovery

```bash
modprobe dahdi
modprobe dahdi_dummy || true
dahdi_cfg -v
```

If timing not active → audio will be choppy or calls will fail.

---

## 8. VICIdial Runtime Restart

```bash
systemctl restart vicidial || true
/usr/share/astguiclient/start_asterisk_boot.pl
```

Verify screens:

```bash
screen -ls
```

Expected: multiple detached VICIdial screens.

---

## 9. Verification Gates (Mandatory)

### 9.1 Diagnostic Mode

```bash
vicidial-doctor.sh
```

Resolve all **FAIL** items.

### 9.2 Final Gate

```bash
installer/patches/99-verify.sh
```

❌ If this fails, do not allow agents to log in.

---

## 10. Browser Validation (LAST STEP)

Only now, test:

* Admin: `http://SERVER_IP/vicidial/admin.php`
* Agent: `http://SERVER_IP/agc/vicidial.php`

Default admin (if restored):

* User: `6666`
* Pass: as configured

---

## 11. Post-Recovery Hardening Checklist

* Re-enable SELinux (if required)
* Confirm RAM drive mounted
* Confirm cron jobs present
* Run `99-verify.sh` again

---

## 12. When to Re-run the Installer

Only re-run installer patches if:

* OS was rebuilt
* `/usr/share/astguiclient` is missing
* VICIdial scripts are corrupted

Never re-run blindly on a live system.

---

## 13. Summary

This playbook ensures:

* Predictable recovery
* Minimal downtime
* No guesswork under stress

**Follow the order. Trust the gates.**
