#!/bin/bash
# Skrypt do tworzenia brakujących skryptów backupowych

RETENTION_DAYS=7

create_script() {
    local name=$1
    local container=$2
    local db_name=$3
    local db_user=$4
    local backups_dir=$5
    
    cat > "/usr/local/bin/pg_backup_${name}.sh" << 'SCRIPTEOF'
#!/usr/bin/env bash
# PostgreSQL backup script
set -e

CONTAINER="CONTAINER_VAR"
DB_NAME="DB_NAME_VAR"
DB_USER="DB_USER_VAR"
BACKUPS_DIR="BACKUPS_DIR_VAR"
RETENTION_DAYS=7

STAMP=$(date +%F_%H-%M)
BACKUP_FILE="${BACKUPS_DIR}/${DB_NAME}_${STAMP}.sql"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Container ${CONTAINER} is not running. Skipping backup."
  exit 1
fi

# Create backup
echo "Creating backup: ${BACKUP_FILE}"
docker exec -t "${CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" > "${BACKUP_FILE}"

# Compress backup
if [ -f "${BACKUP_FILE}" ]; then
  gzip "${BACKUP_FILE}"
  echo "Backup created: ${BACKUP_FILE}.gz"
else
  echo "ERROR: Backup file not created!"
  exit 1
fi

# Remove old backups
find "${BACKUPS_DIR}" -type f -name "${DB_NAME}_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
echo "Removed backups older than ${RETENTION_DAYS} days"
SCRIPTEOF

    sed -i "s|CONTAINER_VAR|${container}|g" "/usr/local/bin/pg_backup_${name}.sh"
    sed -i "s|DB_NAME_VAR|${db_name}|g" "/usr/local/bin/pg_backup_${name}.sh"
    sed -i "s|DB_USER_VAR|${db_user}|g" "/usr/local/bin/pg_backup_${name}.sh"
    sed -i "s|BACKUPS_DIR_VAR|${backups_dir}|g" "/usr/local/bin/pg_backup_${name}.sh"
    chmod +x "/usr/local/bin/pg_backup_${name}.sh"
    echo "✓ Utworzono: pg_backup_${name}.sh"
}

# Tworzenie brakujących skryptów
create_script "nc_matterhorn1" "nc-postgres-1" "matterhorn1" "pawel" "/srv/backups/postgres/nc"
create_script "nc_MPD" "nc-postgres-1" "MPD" "pawel" "/srv/backups/postgres/nc"
create_script "nc_web_agent" "nc-postgres-1" "web_agent" "pawel" "/srv/backups/postgres/nc"
create_script "test_zzz_matterhorn1" "nc-postgres-test" "zzz_matterhorn1" "pawel" "/srv/postgres/test/backups"
create_script "test_zzz_default" "nc-postgres-test" "zzz_default" "pawel" "/srv/postgres/test/backups"
create_script "test_zzz_MPD" "nc-postgres-test" "zzz_MPD" "pawel" "/srv/postgres/test/backups"
create_script "test_zzz_web_agent" "nc-postgres-test" "zzz_web_agent" "pawel" "/srv/postgres/test/backups"

echo ""
echo "✅ Wszystkie skrypty utworzone!"

