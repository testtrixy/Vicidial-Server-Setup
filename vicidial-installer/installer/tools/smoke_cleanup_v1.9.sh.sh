#!/usr/bin/env bash
DB="asterisk"
SERVER_IP="$(hostname -I | awk '{print $1}')"

mysql "${DB}" -e "
DELETE FROM vicidial_conferences WHERE server_ip='${SERVER_IP}';
DELETE FROM vicidial_vicidial_conferences WHERE server_ip='${SERVER_IP}';
DELETE FROM vicidial_server_carriers WHERE server_ip='${SERVER_IP}';
DELETE FROM vicidial_carriers WHERE carrier_id='LOOPBACK';
DELETE FROM vicidial_list WHERE list_id='1001';
DELETE FROM vicidial_lists WHERE list_id='1001';
DELETE FROM vicidial_campaigns WHERE campaign_id='TESTCAMP';
DELETE FROM vicidial_users WHERE user='6666';
DELETE FROM phones WHERE extension='101';
DELETE FROM servers WHERE server_ip='${SERVER_IP}' AND server_description='Smoke Test';
"
