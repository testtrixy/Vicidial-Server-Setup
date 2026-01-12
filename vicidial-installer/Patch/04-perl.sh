source "$(dirname "$0")/../lib/common.sh"


perl -MDBI -e1 || fail "DBI missing"
perl -MUnicode::Map -e1 || fail "Unicode::Map missing"


#!/usr/bin/env bash
set -euo pipefail


echo "[04] Perl & legacy CPAN modules"


dnf install -y perl perl-CPAN perl-DBI perl-DBD-MySQL gcc make


if ! command -v cpanm >/dev/null 2>&1; then
curl -L https://cpanmin.us | perl - App::cpanminus
fi


cpanm -f --notest \
DBI DBD::mysql Net::Telnet Time::HiRes Net::Server \
Switch Mail::Sendmail Unicode::Map Jcode \
Spreadsheet::WriteExcel Spreadsheet::ParseExcel OLE::Storage_Lite \
Proc::ProcessTable IO::Scalar LWP::UserAgent



log "Installing VICIdial legacy Perl modules"

LEGACY_MODULES=(
  Unicode::Map
  Jcode
  Spreadsheet::WriteExcel
  Mail::Sendmail
)

for mod in "${LEGACY_MODULES[@]}"; do
  if perl -M"$mod" -e1 >/dev/null 2>&1; then
    ok "Perl module present: $mod"
  else
    cpanm -f --notest "$mod" || die "Failed to install $mod"
  fi
done



echo "[04] Perl modules installed"

log "Self-validation completed for $(basename "$0")"