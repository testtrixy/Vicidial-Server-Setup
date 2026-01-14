#!/usr/bin/env bash
# =============================================================================
# Stage 03 – Build Environment (EL9)
# Responsibilities:
#   - Verify running kernel matches installed headers
#   - Install compilation toolchain
#   - Install libraries required to BUILD Asterisk / DAHDI from source
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


log_success "---------------- – -------------------------------"
  log_info "Stage 03: Build environment preparation started"
log_success "---------------- – -------------------------------"




# -----------------------------------------------------------------------------
# Validate kernel headers (MANDATORY for DAHDI)
# -----------------------------------------------------------------------------
KERNEL_VERSION="$(uname -r)"
INSTALLED_KERNEL="$(rpm -q kernel | sort -V | tail -1 | sed 's/kernel-//')"

if [[ "${KERNEL_VERSION}" != "${INSTALLED_KERNEL}" ]]; then
  fatal "Running kernel (${KERNEL_VERSION}) does not match latest installed (${INSTALLED_KERNEL}). Reboot required."
fi

log_info "Detected running kernel: ${KERNEL_VERSION}"

dnf -y install \
  kernel-devel-"${KERNEL_VERSION}" \
  kernel-headers-"${KERNEL_VERSION}" \
  || fatal "Kernel headers not found for ${KERNEL_VERSION}"

# -----------------------------------------------------------------------------
# Core compilation toolchain
# -----------------------------------------------------------------------------
log_info "Installing core compilation toolchain"

dnf -y groupinstall "Development Tools"

dnf -y install \
  gcc gcc-c++ make \
  autoconf automake libtool \
  patch bison flex \
  pkgconf-pkg-config \
  git wget curl

# -----------------------------------------------------------------------------
# Asterisk / DAHDI build dependencies (EL9-correct)
# -----------------------------------------------------------------------------
log_info "Installing Asterisk / DAHDI build dependencies"

dnf -y install \
  ncurses-devel \
  libedit-devel \
  libuuid-devel \
  libxml2-devel \
  sqlite-devel \
  jansson-devel \
  openssl-devel \
  elfutils-libelf-devel \
  libpcap-devel \
  pciutils-devel \
  zlib-devel

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
log_info "Validating build toolchain"

for cmd in gcc make ld pkg-config git; do
  require_command "$cmd"
done


log_success "---------------- – -------------------------------"
  log_success "Stage 03 completed – build environment ready"
log_success "---------------- – -------------------------------"
