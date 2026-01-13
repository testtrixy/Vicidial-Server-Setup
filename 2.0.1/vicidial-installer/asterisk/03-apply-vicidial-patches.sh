#!/usr/bin/env bash
set -euo pipefail

############################################
# Apply Official Vicidial Asterisk 18 Patches
# Rocky Linux 9
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ASTERISK_SRC="/usr/src/asterisk"
PATCH_BASE_URL="https://download.vicidial.com/asterisk-patches/Asterisk-18"
PATCH_DIR="/usr/src/vicidial-patches/asterisk-18"

echo "================================================="
echo "[$SCRIPT_NAME] Applying Vicidial patches"
echo "================================================="

### --- SAFETY ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

if [[ ! -d "$ASTERISK_SRC" ]]; then
  echo "[ERROR] Asterisk source not found at $ASTERISK_SRC"
  exit 1
fi

command -v patch >/dev/null || {
  echo "[ERROR] patch utility missing"
  exit 1
}

### --- PATCH LIST (OFFICIAL VICIDIAL) ---
PATCHES=(
  "18.0-queue-rules.patch"
  "18.0-amd-fix.patch"
  "18.0-sip-dialplan-fix.patch"
)

### --- PREPARE PATCH DIR ---
mkdir -p "$PATCH_DIR"
cd "$PATCH_DIR"

### --- DOWNLOAD PATCHES ---
for PATCH in "${PATCHES[@]}"; do
  if [[ ! -f "$PATCH" ]]; then
    echo "[INFO] Downloading $PATCH"
    curl -fLO "${PATCH_BASE_URL}/${PATCH}"
  else
    echo "[INFO] Patch already downloaded: $PATCH"
  fi
done

### --- APPLY PATCHES ---
cd "$ASTERISK_SRC"

for PATCH in "${PATCHES[@]}"; do
  echo "-------------------------------------------------"
  echo "[INFO] Applying patch: $PATCH"

  if patch -p1 --dry-run < "${PATCH_DIR}/${PATCH}" >/dev/null 2>&1; then
    patch -p1 < "${PATCH_DIR}/${PATCH}"
    echo "[OK] Applied: $PATCH"
  else
    echo "[WARN] Patch $PATCH may already be applied or incompatible"
    echo "[INFO] Attempting reverse check..."

    if patch -p1 -R --dry-run < "${PATCH_DIR}/${PATCH}" >/dev/null 2>&1; then
      echo "[OK] Patch already applied: $PATCH"
    else
      echo "[FATAL] Patch failed and not reversible: $PATCH"
      exit 1
    fi
  fi
done

### --- MARK PATCH STATE ---
touch "$ASTERISK_SRC/.vicidial_patched"

echo "================================================="
echo "[SUCCESS] Vicidial patches applied"
echo "Marker file: $ASTERISK_SRC/.vicidial_patched"
echo "================================================="

echo "[INFO] Next step: 04-build-asterisk.sh"
