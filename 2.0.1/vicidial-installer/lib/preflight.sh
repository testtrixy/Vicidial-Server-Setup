preflight() {
  [[ $EUID -ne 0 ]] && echo "Run as root" && exit 1
  [[ -f /etc/redhat-release ]] || exit 1
  grep -q "Rocky Linux release 9" /etc/redhat-release || exit 1
}
