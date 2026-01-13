#!/usr/bin/env bash
set -e

firewall-cmd --permanent --remove-service=ssh || true

firewall-cmd --permanent --add-port=22/tcp     # SSH
firewall-cmd --permanent --add-port=80/tcp     # HTTP
firewall-cmd --permanent --add-port=443/tcp    # HTTPS
firewall-cmd --permanent --add-port=5060/udp   # SIP
firewall-cmd --permanent --add-port=4569/udp   # IAX2
firewall-cmd --permanent --add-port=5038/tcp   # AMI

firewall-cmd --reload
