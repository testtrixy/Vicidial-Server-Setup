#!/bin/bash

# Define the root directory
ROOT="installer"

echo "Creating VICIDIAL installer directory structure..."

# 1. Create Directories
mkdir -p $ROOT/config
mkdir -p $ROOT/lib
mkdir -p $ROOT/templates/{asterisk,mysql,vicidial}
mkdir -p $ROOT/sql/{schema,seed}
mkdir -p $ROOT/tools
mkdir -p $ROOT/logs
mkdir -p $ROOT/stages
mkdir -p $ROOT/health

# 2. Create Root Files
touch $ROOT/install.sh
touch $ROOT/MASTER.md

# 3. Create Config Files
touch $ROOT/config/{versions.env,paths.env,secrets.env}

# 4. Create Library Files
touch $ROOT/lib/{common.sh,render.sh}

# 5. Create Stage Scripts
STAGES=(
    "01_os_base.sh"
    "02_web_db.sh"
    "03_build_env.sh"
    "04_telephony.sh"
    "05_vicidial_core.sh"
    "06_automation.sh"
    "07_audio_codecs.sh"
    "08_modern_extras.sh"
)

for script in "${STAGES[@]}"; do
    touch "$ROOT/stages/$script"
done

# 6. Create Health Files
touch $ROOT/health/healthcheck.sh

# 7. Set Permissions (Optional but recommended for .sh files)
find $ROOT -name "*.sh" -exec chmod +x {} \;

echo "✅ Done. Exact structure generated in ./$ROOT"
