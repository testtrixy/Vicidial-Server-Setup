#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Bootstrap installer root (standalone entry point)
# -----------------------------------------------------------------------------
INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export INSTALLER_ROOT

# -----------------------------------------------------------------------------
# Load common library
# -----------------------------------------------------------------------------
source "${INSTALLER_ROOT}/lib/common.sh"

require_root
