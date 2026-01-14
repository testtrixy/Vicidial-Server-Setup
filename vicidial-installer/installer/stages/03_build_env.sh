#!/usr/bin/env bash
# =============================================================================
# Stage 03 – Build Environment
# Responsibilities:
#   - Prepare system for source compilation
#   - Install kernel headers & build dependencies
#   - Install Asterisk / DAHDI prerequisite libraries
#
# NO compiling
# NO services
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command dnf
require_command uname

log_info "Stage 03: Build environment preparation started"

# -----------------------------------------------------------------------------
# Validate OS kernel headers availability
# -----------------------------------------------------------------------------
KERNEL_VERSION="$(uname -r)"

log_info "Detected running kernel: ${KERNEL_VERSION}"

dnf -y install \
  kernel-devel-"${KERNEL_VERSION}" \
  kernel-headers-"${KERNEL_VERSION}" || \
  fatal "Kernel headers not found for ${KERNEL_VERSION}. Reboot into latest kernel."

# -----------------------------------------------------------------------------
# Core build tools (defensive, even if installed earlier)
# -----------------------------------------------------------------------------
log_info "Installing core compilation toolchain"

dnf -y groupinstall "Development Tools"

dnf -y install \
  gcc gcc-c++ make autoconf automake libtool \
  patch bison flex \
  pkgconfig \
  git wget curl \
  ncurses-devel \
  libxml2-devel \
  sqlite-devel \
  openssl-devel \
  libuuid-devel \
  jansson-devel \
  libedit-devel \
  elfutils-libelf-devel

# -----------------------------------------------------------------------------
# DAHDI / Telephony-specific dependencies
# -----------------------------------------------------------------------------
log_info "Installing DAHDI / telephony build dependencies"

dnf -y install \
  dahdi-linux-devel \
  libpcap-devel \
  newt-devel \
  libtermcap-devel \
  pciutils-devel

# -----------------------------------------------------------------------------
# Audio & codec build prerequisites
# -----------------------------------------------------------------------------
log_info "Installing audio & codec dependencies"

dnf -y install \
  speex-devel \
  speexdsp-devel \
  libogg-devel \
  libvorbis-devel \
  opus-devel \
  flac-devel

# -----------------------------------------------------------------------------
# SRTP & security
# -----------------------------------------------------------------------------
log_info "Installing SRTP & security libraries"

dnf -y install \
  libsrtp-devel \
  zlib-devel

# -----------------------------------------------------------------------------
# Validation summary
# -----------------------------------------------------------------------------
log_info "Validating build environment"

for cmd in gcc make ld pkg-config; do
  require_command "$cmd"
done

log_success "Stage 03 completed – build environment ready"
