#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Preflight checks"

dnf -y install epel-release
dnf -y install \
  curl wget tar unzip git \
  net-tools lsof vim \
  policycoreutils-python-utils \
  chrony

systemctl enable --now chronyd

log INFO "Preflight complete"
