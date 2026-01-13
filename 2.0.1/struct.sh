#!/bin/bash

# Project Root
ROOT="vicidial-installer"
mkdir -p $ROOT/{lib,stages,conf,logs}

echo "Generating Vicidial Installer structure in ./$ROOT..."

# --- 1. Master Entry Point ---
cat << 'EOF' > $ROOT/install.sh
#!/bin/bash
# Vicidial Master Installer
set -e

# Load Libraries
source lib/common.sh
source lib/os_detect.sh
source lib/state.sh

log_info "Initializing Vicidial Installation..."

# Execute stages in order
for stage in stages/[0-9]*.sh; do
    stage_name=$(basename "$stage")
    
    if is_stage_complete "$stage_name"; then
        log_warn "Skipping $stage_name (already completed)."
        continue
    fi

    log_info "Executing $stage_name..."
    bash "$stage" && mark_stage_done "$stage_name" || { log_error "Failed at $stage_name"; exit 1; }
done

log_info "All stages finished successfully!"
EOF

# --- 2. Libraries ---
cat << 'EOF' > $ROOT/lib/common.sh
#!/bin/bash
# Logging helpers
log_info()  { echo -e "\e[34m[INFO]\e[0m  $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
EOF

cat << 'EOF' > $ROOT/lib/os_detect.sh
#!/bin/bash
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}
OS_TYPE=$(detect_os)
EOF

cat << 'EOF' > $ROOT/lib/state.sh
#!/bin/bash
STATE_FILE=".install_state"

is_stage_complete() {
    grep -q "^$1$" "$STATE_FILE" 2>/dev/null
}

mark_stage_done() {
    echo "$1" >> "$STATE_FILE"
}
EOF

# --- 3. Stages ---
cat << 'EOF' > $ROOT/stages/00-preflight.sh
#!/bin/bash
source lib/common.sh
log_info "Checking system requirements..."
# Add RAM/CPU checks here
EOF

cat << 'EOF' > $ROOT/stages/01-os-hardening.sh
#!/bin/bash
source lib/common.sh
log_info
