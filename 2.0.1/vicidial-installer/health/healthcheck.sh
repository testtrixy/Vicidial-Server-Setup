#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

echo "=============================="
echo " VICIDIAL SYSTEM HEALTH CHECK "
echo "=============================="

for check in "$BASE_DIR"/checks/*.sh; do
  echo
  echo "▶ Running: $(basename "$check")"
  if bash "$check"; then
    echo "✔ PASS"
    ((PASS++))
  else
    echo "✖ FAIL"
    ((FAIL++))
  fi
done

echo
echo "=============================="
echo " PASSED: $PASS"
echo " FAILED: $FAIL"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
