#!/bin/bash
DATABASE="$1"

entry-log DEBUG Adding database to backup list: ${DATABASE}
echo "${DATABASE}" >> "$PSQL_BACKUP_LIST"
