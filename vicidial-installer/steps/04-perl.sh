#!/bin/bash
echo "=== STEP 04: Perl Modules ==="

yum install -y perl-CPAN perl-YAML perl-libwww-perl perl-DBI perl-DBD-MySQL \
perl-GD perl-Term-ReadLine-Gnu perl-Env perl-open

cd /usr/bin
curl -LOk http://xrl.us/cpanm
chmod +x cpanm

echo "[+] Installing Perl modules via cpanm"
cpanm -f \
DBI DBD::mysql Net::Telnet Time::HiRes Net::Server \
Mail::Sendmail Spreadsheet::ParseExcel Spreadsheet::XLSX \
LWP::UserAgent HTML::Entities IO::Socket::SSL

echo "[OK] Perl modules installed"
