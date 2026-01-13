#!/bin/bash

# Define the root directory
ROOT="vicidial-installer"

echo "Creating structure for $ROOT..."

# Create directory tree
mkdir -p $ROOT/{config,lib,phases,cron}

# --- Create Root Files ---
cat << 'EOF' > $ROOT/install.sh
#!/bin/bash
# Master Controller for Vicidial Installation
source lib/common.sh
source lib/checks.sh

log "Starting Vicidial Installation..."
check_root
check_internet

for phase in phases/*.sh; do
    log "Running $phase..."
    bash "$phase" || error_exit "Failed at $phase"
done

log "Installation Complete!"
EOF

cat << 'EOF' > $ROOT/README.md
# Vicidial Modular Installer
Modular bash-based installer for Vicidial on AlmaLinux/Rocky Linux.
- Run `bash install.sh` to start.
EOF

# --- Create Config Files ---
touch $ROOT/config/{versions.conf,mariadb.cnf,asterisk-menuselect.conf,modules.conf.template}

# --- Create Lib Files ---
cat << 'EOF' > $ROOT/lib/common.sh
#!/bin/bash
log() { echo -e "\e[32m[$(date +'%Y-%m-%d %H:%M:%S')] $1\e[0m"; }
error_exit() { echo -e "\e[31m[ERROR] $1\e[0m"; exit 1; }
EOF

touch $ROOT/lib/{checks.sh,db.sh}

# --- Create Phase Files ---
PHASES=(
    "01-os-prep.sh" "02-deps.sh" "03-mariadb.sh" "04-asterisk-build.sh"
    "05-astguiclient.sh" "06-database-seed.sh" "07-dialplan-generate.sh" "08-validate.sh"
)

for file in "${PHASES[@]}"; do
    echo -e "#!/bin/bash\nsource lib/common.sh\nlog \"Executing phase: $file\"\n# Logic goes here" > "$ROOT/phases/$file"
done

# --- Create Cron ---
touch $ROOT/cron/vicidial.cron

# Set permissions
chmod +x $ROOT/install.sh
chmod +x $ROOT/phases/*.sh

echo "Done! Directory '$ROOT' is ready."
