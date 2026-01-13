#!/usr/bin/env bash
set -e

TARGET="$1"
[[ -z "$TARGET" ]] && echo "Usage: $0 <target-version>" && exit 1

CURRENT=$(asterisk -V | awk '{print $2}')

echo "Upgrading Asterisk $CURRENT → $TARGET"

SCRIPT="upgrades/${CURRENT}_to_${TARGET}.sh"

[[ ! -f "$SCRIPT" ]] && echo "No upgrade script found" && exit 1

bash "$SCRIPT"
