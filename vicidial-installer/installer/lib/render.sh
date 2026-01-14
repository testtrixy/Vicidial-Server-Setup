#!/usr/bin/env bash
# =============================================================================
# VICIDIAL 2026 – Template Rendering Library
# Used by: stages that need config generation
# Scope: Safe, idempotent template rendering
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

_render_fail() {
  echo "[RENDER][ERROR] $1"
  exit 1
}

# -----------------------------------------------------------------------------
# Validate required environment variables exist
# -----------------------------------------------------------------------------
require_vars() {
  local missing=0
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      echo "[RENDER][ERROR] Required variable not set: ${var}"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || exit 1
}

# -----------------------------------------------------------------------------
# Render template using envsubst-style substitution
# -----------------------------------------------------------------------------
# Usage:
#   render_template <template_path> <destination_path> [mode] [owner:group]
#
# Example:
#   render_template templates/mysql/my.cnf.tpl /etc/my.cnf.d/vicidial.cnf 0644 root:root
# -----------------------------------------------------------------------------
render_template() {
  local template="$1"
  local destination="$2"
  local mode="${3:-0644}"
  local owner="${4:-root:root}"

  [[ -f "$template" ]] || _render_fail "Template not found: $template"

  local tmp
  tmp="$(mktemp)"

  # Render with envsubst-style variable replacement
  envsubst < "$template" > "$tmp" || _render_fail "Failed rendering $template"

  # Only replace destination if content changed
  if [[ -f "$destination" ]] && cmp -s "$tmp" "$destination"; then
    rm -f "$tmp"
    echo "[RENDER] No change: $destination"
    return 0
  fi

  install -o "${owner%%:*}" -g "${owner##*:}" -m "$mode" "$tmp" "$destination"
  rm -f "$tmp"

  echo "[RENDER] Updated: $destination"
}

# -----------------------------------------------------------------------------
# Render directory of templates (preserve filenames)
# -----------------------------------------------------------------------------
# Usage:
#   render_directory templates/asterisk /etc/asterisk
# -----------------------------------------------------------------------------
render_directory() {
  local src_dir="$1"
  local dest_dir="$2"
  local mode="${3:-0644}"
  local owner="${4:-root:root}"

  [[ -d "$src_dir" ]] || _render_fail "Source directory not found: $src_dir"
  mkdir -p "$dest_dir"

  for tpl in "$src_dir"/*; do
    [[ -f "$tpl" ]] || continue
    local filename
    filename="$(basename "$tpl")"
    render_template "$tpl" "${dest_dir}/${filename}" "$mode" "$owner"
  done
}

# -----------------------------------------------------------------------------
# End of render.sh
# -----------------------------------------------------------------------------
