#!/bin/bash
set -euo pipefail

### CONFIG
AST_MAJOR="18"
PATCH_BASE_URL="https://download.vicidial.com/asterisk-patches/Asterisk-${AST_MAJOR}"
SRC_BASE="/usr/src"
LOG="/var/log/vicidial-asterisk-patch.log"

echo "===================================================" | tee -a "$LOG"
echo "[INFO] VICIDIAL Asterisk ${AST_MAJOR} Patch Stage" | tee -a "$LOG"
echo "===================================================" | tee -a "$LOG"

### FIND ASTERISK SOURCE DIR
AST_SRC_DIR=$(find "$SRC_BASE" -maxdepth 1 -type d -name "asterisk-${AST_MAJOR}*" | head -n 1)

if [[ -z "$AST_SRC_DIR" ]]; then
  echo "[FATAL] Asterisk ${AST_MAJOR} source directory not found in $SRC_BASE" | tee -a "$LOG"
  exit 1
fi

echo "[OK] Found Asterisk source: $AST_SRC_DIR" | tee -a "$LOG"
cd "$AST_SRC_DIR"

### FETCH PATCH LIST
echo "[INFO] Fetching patch list from VICIDIAL..." | tee -a "$LOG"

PATCH_LIST=$(curl -fsSL "$PATCH_BASE_URL/" | \
  grep -oE 'href="[^"]+\.patch"' | \
  cut -d'"' -f2 | sort -u)

if [[ -z "$PATCH_LIST" ]]; then
  echo "[FATAL] No patches found at $PATCH_BASE_URL" | tee -a "$LOG"
  exit 1
fi

echo "[OK] Found $(echo "$PATCH_LIST" | wc -l) patches" | tee -a "$LOG"

### APPLY PATCHES
APPLIED=0

for PATCH in $PATCH_LIST; do
  echo "[PATCH] Applying $PATCH" | tee -a "$LOG"

  curl -fsSL "${PATCH_BASE_URL}/${PATCH}" | patch -p1 >> "$LOG" 2>&1 || {
    echo "[FATAL] Patch failed: $PATCH" | tee -a "$LOG"
    echo "Check log: $LOG"
    exit 1
  }

  ((APPLIED++))
done

echo "---------------------------------------------------" | tee -a "$LOG"
echo "[SUCCESS] Applied $APPLIED VICIDIAL patches" | tee -a "$LOG"
echo "---------------------------------------------------" | tee -a "$LOG"
