#!/usr/bin/env bash
set -euo pipefail

############################################
# Download Asterisk 18 LTS Source
# Rocky Linux 9
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ASTERISK_VERSION="18.22.0"
ASTERISK_TARBALL="asterisk-${ASTERISK_VERSION}.tar.gz"
ASTERISK_URL="https://downloads.asterisk.org/pub/telephony/asterisk/${ASTERISK_TARBALL}"

SRC_BASE="/usr/src"
ASTERISK_SRC="${SRC_BASE}/asterisk-${ASTERISK_VERSION}"
BUILD_SYMLINK="${SRC_BASE}/asterisk"

echo "================================================="
echo "[$SCRIPT_NAME] Downloading Asterisk ${ASTERISK_VERSION}"
echo "================================================="

### --- SAFETY ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

### --- PREPARE SRC DIR ---
mkdir -p "$SRC_BASE"
cd "$SRC_BASE"

### --- CLEAN OLD SOURCES ---
if [[ -d "$ASTERISK_SRC" ]]; then
  echo "[INFO] Existing Asterisk source found, removing"
  rm -rf "$ASTERISK_SRC"
fi

rm -f "$ASTERISK_TARBALL"

### --- DOWNLOAD ---
echo "[INFO] Downloading ${ASTERISK_TARBALL}"
curl -fL "$ASTERISK_URL" -o "$ASTERISK_TARBALL"

### --- BASIC VALIDATION ---
if [[ ! -s "$ASTERISK_TARBALL" ]]; then
  echo "[ERROR] Download failed or file empty"
  exit 1
fi

### --- EXTRACT ---
echo "[INFO] Extracting Asterisk source"
tar xzf "$ASTERISK_TARBALL"

if [[ ! -d "$ASTERISK_SRC" ]]; then
  echo "[ERROR] Extracted source directory missing"
  exit 1
fi

### --- SYMLINK (STANDARDIZE PATH) ---
echo "[INFO] Creating /usr/src/asterisk symlink"
rm -f "$BUILD_SYMLINK"
ln -s "$ASTERISK_SRC" "$BUILD_SYMLINK"

### --- PERMISSIONS ---
chown -R root:root "$ASTERISK_SRC"

### --- SUMMARY ---
echo "================================================="
echo "[SUCCESS] Asterisk source ready"
echo "Version     : ${ASTERISK_VERSION}"
echo "Source Path : ${ASTERISK_SRC}"
echo "Symlink     : ${BUILD_SYMLINK}"
echo "================================================="

echo "[INFO] Next step: 03-apply-vicidial-patches.sh"
