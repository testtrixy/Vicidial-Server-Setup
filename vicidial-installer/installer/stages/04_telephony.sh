#!/usr/bin/env bash
# =============================================================================
# Stage 04 – Telephony Core (Vicidial Stable Path)
# Responsibilities:
#   - Build DAHDI from Git master (EL9 compatible)
#   - Build LibPRI (Vicidial required version)
#   - Build LibSRTP (OpenSSL compatible)
#   - Build & patch Asterisk 18 for Vicidial
#
# Path: A (Classic Vicidial – Production Safe)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command git
require_command make
require_command gcc
require_command patch



log_success "---------------- – -------------------------------"
  log_info "Stage 04: Telephony Core (Vicidial-patched Asterisk 18) started"
log_success "---------------- – -------------------------------"




# -----------------------------------------------------------------------------
# Versions (pin explicitly – do NOT float silently)
# -----------------------------------------------------------------------------
ASTERISK_VERSION="18.21.0"
LIBPRI_VERSION="1.4.10.1"
LIBSRTP_VERSION="2.3.0"

BUILD_DIR="${INSTALLER_ROOT}/tools/build"
PATCH_DIR="${INSTALLER_ROOT}/tools/patches"

mkdir -p "${BUILD_DIR}" "${PATCH_DIR}"
cd "${BUILD_DIR}"

# -----------------------------------------------------------------------------
# 1. DAHDI – Git master (required for EL9 kernels)
# -----------------------------------------------------------------------------
log_info "Building DAHDI from Git master"

rm -rf dahdi-linux dahdi-tools

git clone https://github.com/asterisk/dahdi-linux.git
git clone https://github.com/asterisk/dahdi-tools.git

cd dahdi-linux
make
make install
cd ../dahdi-tools
autoreconf -i
./configure --libdir=/usr/lib64
make
make install

log_info "DAHDI does not require a systemd service on EL9"
#make config


#systemctl enable dahdi || true
log_info "DAHDI does not require a systemd service on EL9"

# -----------------------------------------------------------------------------
# 2. LibPRI (Vicidial-pinned)
# -----------------------------------------------------------------------------
log_info "Building LibPRI ${LIBPRI_VERSION}"

cd "${BUILD_DIR}"
rm -rf libpri*

curl -fLO "https://download.vicidial.com/required-apps/libpri-${LIBPRI_VERSION}.tar.gz"
tar -zxf "libpri-${LIBPRI_VERSION}.tar.gz"
cd "libpri-${LIBPRI_VERSION}"



log_info "Building LibPRI with relaxed compiler warnings (EL9 compatibility)"
make clean || true
make CFLAGS="-Wno-error" && make install





# -----------------------------------------------------------------------------
# 3. LibSRTP (OpenSSL compatible)
# -----------------------------------------------------------------------------
log_info "Building LibSRTP ${LIBSRTP_VERSION}"

cd "${BUILD_DIR}"
rm -rf libsrtp*

curl -fLO "https://github.com/cisco/libsrtp/archive/v${LIBSRTP_VERSION}.tar.gz"
tar -zxf "v${LIBSRTP_VERSION}.tar.gz"
cd "libsrtp-${LIBSRTP_VERSION}"

./configure --enable-openssl --prefix=/usr --libdir=/usr/lib64
make shared_library
make install

ldconfig

# -----------------------------------------------------------------------------
# 4. Asterisk 18 (Vicidial-patched)
# -----------------------------------------------------------------------------
log_info "Building Asterisk ${ASTERISK_VERSION} (Vicidial patched)"

cd "${BUILD_DIR}"
rm -rf asterisk*

curl -fLO "https://download.vicidial.com/required-apps/asterisk-${ASTERISK_VERSION}-vici.tar.gz"
tar -zxf "asterisk-${ASTERISK_VERSION}-vici.tar.gz"
cd "asterisk-${ASTERISK_VERSION}-vici"

# -----------------------------------------------------------------------------
# 5. Apply Vicidial patches (controlled, explicit)
# -----------------------------------------------------------------------------

# 
# log_info "Applying Vicidial Asterisk patches"

# PATCH_BASE_URL="http://download.vicidial.com/asterisk-patches/Asterisk-18"

#PATCHES=(
 # "amd_stats-18.patch"
  #"iax_peer_status-18.patch"
  #"sip_peer_status-18.patch"
  #"timeout_reset_dial_app-18.patch"
  #"timeout_reset_dial_core-18.patch"
#)

#mkdir -p patches
#cd patches

#for p in "${PATCHES[@]}"; do
 # curl -fLO "${PATCH_BASE_URL}/${p}"
#done

#cd ..
#for p in patches/*.patch; do
 # patch -p1 < "$p"
#done

# -----------------------------------------------------------------------------
# 6. Configure, build & install Asterisk
# -----------------------------------------------------------------------------
log_info "Configuring and compiling Asterisk"

./configure \
  --libdir=/usr/lib64 \
  --with-pjproject-bundled \
  --with-jansson-bundled \
  --with-srtp \
  --with-ssl \
  --enable-asteriskssl

make menuselect.makeopts

menuselect/menuselect \
  --enable app_meetme \
  --enable res_http_websocket \
  --enable res_srtp \
  menuselect.makeopts

make -j"$(nproc)"

make install
make samples NO_CHKCONFIG=1

log_info "Skipping 'make config' (EL9 uses systemd; service installed later)"
#make config

ldconfig

# -----------------------------------------------------------------------------
# 7. Runtime directories & permissions
# -----------------------------------------------------------------------------
log_info "Preparing Asterisk runtime directories"

mkdir -p \
  /var/log/asterisk \
  /var/lib/asterisk \
  /var/spool/asterisk \
  /var/run/asterisk



if getent passwd asterisk >/dev/null; then
  chown -R asterisk:asterisk \
    /var/log/asterisk \
    /var/lib/asterisk \
    /var/spool/asterisk \
    /var/run/asterisk
else
  log_warn "asterisk user not found; skipping ownership (Stage 01 should create it)"
fi




# -----------------------------------------------------------------------------
# 8. Enable & start Asterisk
# -----------------------------------------------------------------------------
#only build here and run 06 stage

log_info "Asterisk binaries installed (service will be configured in Stage 06)"
#systemctl enable asterisk
#systemctl restart asterisk

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 04 completed – Vicidial telephony stack ready"
