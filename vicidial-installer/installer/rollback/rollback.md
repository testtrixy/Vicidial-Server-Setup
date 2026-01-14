Rollback scripts are executed explicitly per stage.

Example:
  ./rollback/rollback-02-web-db.sh

Each rollback script:
- Undoes only its own stage
- Uses common logging
- Removes its own marker
- Is safe to re-run
