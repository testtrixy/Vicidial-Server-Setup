#!/bin/bash
log() { echo -e "\e[32m[$(date +'%Y-%m-%d %H:%M:%S')] $1\e[0m"; }
error_exit() { echo -e "\e[31m[ERROR] $1\e[0m"; exit 1; }
