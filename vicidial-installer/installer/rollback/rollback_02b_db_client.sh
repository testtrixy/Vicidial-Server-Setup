#!/usr/bin/env bash
set -euo pipefail

echo "[ROLLBACK] Stage 02b – DB Client Dependencies"

dnf -y remove \
  mariadb \
  perl-DBI \
  perl-DBD-MariaDB || true

# IMPORTANT:
# Do NOT remove:
# - perl itself
# - MariaDB-server (never installed here)
# - shared libraries

echo "[ROLLBACK] Stage 02b completed safely"
exit 0
