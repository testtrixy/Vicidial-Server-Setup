#!/usr/bin/env bash

detect_os() {
  source /etc/os-release

  OS_NAME="$ID"
  OS_VERSION="${VERSION_ID%%.*}"

  if [[ "$OS_NAME" != "rocky" && "$OS_NAME" != "almalinux" ]]; then
    log ERROR "Unsupported OS: $OS_NAME"
    exit 1
  fi

  if [[ "$OS_VERSION" -ne 9 ]]; then
    log ERROR "Unsupported OS version: $OS_VERSION"
    exit 1
  fi
}
