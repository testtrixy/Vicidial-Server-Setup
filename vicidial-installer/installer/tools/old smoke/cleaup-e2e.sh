#!/usr/bin/env bash
set -euo pipefail

DB="asterisk"

mysql "${DB}" -e "
DELETE FROM vicidial_campaigns WHERE campaign_id='TESTCAMP';
DELETE FROM vicidial_lists WHERE list_id='1001';
DELETE FROM vicidial_list WHERE phone_number='1234567890';
DELETE FROM vicidial_users WHERE user='6666';
DELETE FROM phones WHERE extension='101';
DELETE FROM servers WHERE server_id='DIALER1';
DELETE FROM vicidial_carriers WHERE carrier_id='LOOPBACK';
"

echo "Smoke test data removed"
