#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

INSTANCE_NAME="${1:?Usage: backup.sh <instance-name> [backup-directory]}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_ROOT="${2:-${PROJECT_DIR}/backups}"
ODOO_CONTAINER="odoo19-${INSTANCE_NAME}"
DB_CONTAINER="${ODOO_CONTAINER}-db"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${INSTANCE_NAME}"
BACKUP_FILE="${BACKUP_DIR}/odoo19_${INSTANCE_NAME}_${TIMESTAMP}.tar.gz"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -f "${TEMP_DIR}/database.sql" "${TEMP_DIR}/filestore.tar.gz"
    rmdir "${TEMP_DIR}"
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || {
    printf 'Error: Docker is required.\n' >&2
    exit 1
}

docker inspect "${DB_CONTAINER}" >/dev/null 2>&1 || {
    printf 'Error: database container not found: %s\n' "${DB_CONTAINER}" >&2
    exit 1
}
docker inspect "${ODOO_CONTAINER}" >/dev/null 2>&1 || {
    printf 'Error: Odoo container not found: %s\n' "${ODOO_CONTAINER}" >&2
    exit 1
}

mkdir -p "${BACKUP_DIR}"
docker exec "${DB_CONTAINER}" sh -c 'pg_dumpall -U "$POSTGRES_USER"' > "${TEMP_DIR}/database.sql"

if docker exec "${ODOO_CONTAINER}" test -d /var/lib/odoo/filestore; then
    docker exec "${ODOO_CONTAINER}" tar -C /var/lib/odoo -czf - filestore > "${TEMP_DIR}/filestore.tar.gz"
fi

tar -czf "${BACKUP_FILE}" -C "${TEMP_DIR}" .

find "${BACKUP_DIR}" -maxdepth 1 -type f -name "odoo19_${INSTANCE_NAME}_*.tar.gz" -printf '%T@ %p\n' \
    | sort -rn \
    | tail -n +6 \
    | cut -d ' ' -f 2- \
    | while IFS= read -r old_backup; do
        [[ -z "${old_backup}" ]] || rm -f -- "${old_backup}"
    done

printf 'Backup saved: %s\n' "${BACKUP_FILE}"
