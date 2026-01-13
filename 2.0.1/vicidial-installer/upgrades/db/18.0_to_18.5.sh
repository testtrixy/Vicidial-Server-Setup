#!/usr/bin/env bash
set -e

rollback() {
  echo "ROLLBACK NOT IMPLEMENTED"
}
trap rollback ERR

echo "Running DB migrations"
mysql asterisk < upgrades/db/001_add_indexes.sql

echo "Reloading Asterisk"
asterisk -rx "core reload"

mysql asterisk -e \
 "INSERT INTO schema_version (version) VALUES ('18.5')"
