#!/usr/bin/env bash

ROOT_DIR="vicidial-installer"

echo "📂 Creating Vicidial Automation Structure..."

# 1. Create Directory Tree
mkdir -p "$ROOT_DIR/steps"
mkdir -p "$ROOT_DIR/logs"
mkdir -p "$ROOT_DIR/backups/preinstall"

# 2. Define Root Files
ROOT_FILES=(
    "install.sh"
    "rollback.sh"
    "config.env"
    "backup.sh"
    "restore.sh"
    "health-check.sh"
)

# 3. Define Step Files
STEP_FILES=(
    "00-env-check.sh"
    "01-os-prep.sh"
    "02-repos-packages.sh"
    "03-mariadb.sh"
    "04-perl.sh"
    "05-libs-codecs.sh"
    "06-dahdi.sh"
    "07-asterisk.sh"
    "08-vicidial.sh"
    "09-boot-cron.sh"
)

# 4. Create Root Files and set permissions
for file in "${ROOT_FILES[@]}"; do
    touch "$ROOT_DIR/$file"
    [[ "$file" == *.sh ]] && chmod +x "$ROOT_DIR/$file"
done

# 5. Create Step Files inside steps/
for file in "${STEP_FILES[@]}"; do
    touch "$ROOT_DIR/steps/$file"
    chmod +x "$ROOT_DIR/steps/$file"
done

# 6. Initialize config.env (The Global Config)
cat <<EOF > "$ROOT_DIR/config.env"
# GLOBAL CONFIGURATION
DB_ROOT_PASS="SET_SECURE_PASSWORD"
DB_USER="cron"
DB_PASS="1234"
VICI_SVN_REPO="svn://svn.eflo.net:3690/agc_2-X/trunk"
TIMEZONE="America/New_York"
LOG_FILE="./logs/install.log"
EOF

# 7. Initialize install.sh (The Master Engine)
cat <<EOF > "$ROOT_DIR/install.sh"
#!/usr/bin/env bash
source config.env

echo "🚀 Starting Master ViciDial Installation..." | tee -a \$LOG_FILE

for script in steps/*.sh; do
    echo "▶️ Running \$script..." | tee -a \$LOG_FILE
    ./\$script >> \$LOG_FILE 2>&1
    if [ \$? -ne 0 ]; then
        echo "❌ Error in \$script. Check \$LOG_FILE"
        exit 1
    fi
done

echo "✅ Installation Complete!"
EOF

echo "---"
echo "✅ Structure Created Successfully!"
ls -R "$ROOT_DIR"