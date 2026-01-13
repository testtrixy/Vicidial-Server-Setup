REQUIRED=(asterisk mariadb-server perl httpd cronie)

for pkg in "${REQUIRED[@]}"; do
  rpm -q "$pkg" >/dev/null
done
