# VICIdial Scratch Installer – Rocky Linux 8.5

## Overview

This repository provides a **fully automated, idempotent, production-grade**
scratch installer for **VICIdial** on **Rocky Linux 8.5**.

It is designed for:
- Bare-metal servers
- Cloud VMs
- Disaster recovery rebuilds
- Repeatable “golden image” creation

The installer supports:
- Step-by-step execution
- Safe re-runs (idempotent)
- Automatic rollback on failure
- Backup & restore
- Health checks
- Post-install validation

---

## ⚠️ Supported Platform

- OS: **Rocky Linux 8.5 (x86_64)**
- Kernel: 4.18.x
- Asterisk: 13.29.2-vici
- PHP: 7.4
- Database: MariaDB

> ❗ Other OS versions are NOT supported unless explicitly tested.

---

## Directory Structure

--------


vicidial-installer/
├── install.sh # Master auto installer
├── rollback.sh # Safe rollback
├── backup.sh # Full system backup
├── restore.sh # Disaster recovery restore
├── health-check.sh # Non-blocking health check
├── post-install-verify.sh # BLOCKING production verification
├── config.env # Global configuration
├── steps/ # Ordered install steps
│ ├── 00-env-check.sh
│ ├── 01-os-prep.sh
│ ├── 02-repos-packages.sh
│ ├── 03-mariadb.sh
│ ├── 04-perl.sh
│ ├── 05-libs-codecs.sh
│ ├── 06-dahdi.sh
│ ├── 07-asterisk.sh
│ ├── 08-vicidial.sh
│ └── 09-boot-cron.sh
├── logs/ # Installer logs
└── state/ # Idempotency state files



-------


---

## Pre-Install Requirements

- Root access
- Clean Rocky Linux 8.5 install
- Internet connectivity
- Minimum:
  - 4 CPU cores (8+ recommended)
  - 8 GB RAM (16+ recommended)
  - 100 GB disk (recordings grow fast)

---

## Installation (One Command)

```bash
chmod +x *.sh steps/*.sh
./install.sh
