#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 03 – Vicidial Database Initialization (EL9 – DB NODE ONLY)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql

log "=== Stage 03: Vicidial DB Initialization (EL9) ==="

###############################################################################
# Guards
###############################################################################

check_el9

# This stage MUST only run on DB node
require_vars VICIDIAL_DB_NAME

###############################################################################
# Verify MariaDB is Running
###############################################################################

systemctl is-active --quiet mariadb \
  || fail "MariaDB service is not running. Cannot initialize database."

###############################################################################
# Locate Vicidial SQL Schema
###############################################################################

SCHEMA_DIR="/usr/share/astguiclient/extras"
AST_SCHEMA="${SCHEMA_DIR}/MySQL_AST_CREATE_tables.sql"
VIC_SCHEMA="${SCHEMA_DIR}/MySQL_VICIDIAL_CREATE_tables.sql"

[[ -f "${AST_SCHEMA}" ]] || fail "Missing ${AST_SCHEMA}"
[[ -f "${VIC_SCHEMA}" ]] || fail "Missing ${VIC_SCHEMA}"

###############################################################################
# Import ASTERISK Database Schema (Idempotent)
###############################################################################

log "Checking asterisk database schema"

AST_EXISTS=$(mysql -N -B "${VICIDIAL_DB_NAME}" \
  -e "SHOW TABLES LIKE 'phones';" || true)

if [[ -z "${AST_EXISTS}" ]]; then
  log "Importing asterisk database schema"
  mysql "${VICIDIAL_DB_NAME}" < "${AST_SCHEMA}"
else
  log "Asterisk tables already exist – skipping import"
fi

###############################################################################
# Import VICIDIAL Database Schema (Idempotent)
###############################################################################

log "Checking vicidial database schema"

VIC_EXISTS=$(mysql -N -B vicidial \
  -e "SHOW TABLES LIKE 'vicidial_users';" || true)

if [[ -z "${VIC_EXISTS}" ]]; then
  log "Importing vicidial database schema"
  mysql vicidial < "${VIC_SCHEMA}"
else
  log "Vicidial tables already exist – skipping import"
fi

###############################################################################
# Completion
###############################################################################

log "Stage 03 completed successfully (DB schema initialized)"
