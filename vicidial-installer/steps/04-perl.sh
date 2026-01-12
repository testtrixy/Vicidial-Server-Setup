#!/bin/bash
set -euo pipefail

exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"

# ---------------------------------------------------
# STEP 04: Perl Runtime + Asterisk-Perl (VICIdial Safe)
# ---------------------------------------------------

echo "=================================================="
echo " STEP 04: PERL MODULES & ASTERISK-PERL"
echo "=================================================="

# ---------------------------------------------------
# 1. Install system Perl dependencies (EPEL-safe)
# ---------------------------------------------------
echo "[+] Installing system Perl packages"

yum install -y \
  perl-CPAN \
  perl-YAML \
  perl-libwww-perl \
  perl-DBI \
  perl-DBD-MySQL \
  perl-GD \
  perl-Term-ReadLine-Gnu \
  perl-Env \
  perl-open \
  perl-Digest-SHA \
  perl-App-cpanminus \
  perl-Switch \
  perl-Archive-Zip \
  perl-Proc-ProcessTable \
  perl-IO-Socket-SSL \
  perl-Net-Telnet \
  perl-Net-Ping \
  perl-libnet


  yum install -y \
  perl-LWP-Protocol-https \
  perl-IO-Socket-SSL \
  perl-Net-SSLeay \
  ca-certificates

  echo "[+] Installing CPAN HTTPS support"
  echo "[+] Installing required CPAN modules (this may take time)"
  export PERL_CPANM_OPT="--mirror https://cpan.metacpan.org --mirror-only"

# ---------------------------------------------------
# 2. Configure CPAN non-interactively (fallback safety)
# ---------------------------------------------------
echo "[+] Initializing CPAN config (non-interactive)"

mkdir -p /root/.cpan/CPAN
cat <<'EOF' > /root/.cpan/CPAN/MyConfig.pm
$CPAN::Config = {
  'auto_commit' => q[1],
  'build_dir' => q[/root/.cpan/build],
  'urllist' => [q[http://www.cpan.org/]],
  'prerequisites_policy' => q[follow],
  'build_requires_install_policy' => q[yes],
};
1;
__END__
EOF



echo "[+] Required CPAN Check"
perl -MLWP::Protocol::https -e 1 \
  || { echo "[FATAL] Perl HTTPS support missing"; exit 1; }


# ---------------------------------------------------
# 3. Install critical CPAN modules (forced, legacy-safe)
# ---------------------------------------------------
echo "[+] Installing required CPAN modules (may take time)"

cpanm -f --notest \
  DBI \
  DBD::mysql \
  Net::Telnet \
  Time::HiRes \
  Net::Server \
  Switch \
  Mail::Sendmail \
  Unicode::Map \
  Jcode \
  Spreadsheet::WriteExcel \
  Spreadsheet::ParseExcel \
  Spreadsheet::XLSX \
  OLE::Storage_Lite \
  Proc::ProcessTable \
  IO::Scalar \
  LWP::UserAgent \
  HTML::Entities \
  IO::Socket::SSL \
  String::CRC \
  Net::Address::IP::Local \
  Tk::TableMatrix \
  Crypt::Eksblowfish::Bcrypt \
  || true

# ---------------------------------------------------
# 4. CRITICAL: Compile asterisk-perl-0.08 manually
# ---------------------------------------------------
echo "[+] Compiling asterisk-perl-0.08 (CRITICAL)"

cd /usr/src
if [ ! -d asterisk-perl-0.08 ]; then
  wget -q http://download.vicidial.com/required-apps/asterisk-perl-0.08.tar.gz
  tar xzf asterisk-perl-0.08.tar.gz
fi

cd asterisk-perl-0.08
perl Makefile.PL
make
make install

# ---------------------------------------------------
# 5. Verification (hard fail if broken)
# ---------------------------------------------------
echo "[+] Verifying Asterisk::AGI module"

perl -e 'use Asterisk::AGI; print "Asterisk::AGI OK\n";' \
  || { echo "[FATAL] Asterisk::AGI failed to load"; exit 1; }

echo "[OK] STEP 04 COMPLETED SUCCESSFULLY"
echo "=================================================="
