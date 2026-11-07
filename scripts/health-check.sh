#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ODOO_CONTAINER="$(sed -n 's/^ODOO_CONTAINER_NAME=//p' "${PROJECT_DIR}/.env" 2>/dev/null | head -n 1)"
DB_CONTAINER="$(sed -n 's/^ODOO_DB_CONTAINER_NAME=//p' "${PROJECT_DIR}/.env" 2>/dev/null | head -n 1)"
ODOO_CONTAINER="${ODOO_CONTAINER:-odoo19}"
DB_CONTAINER="${DB_CONTAINER:-odoo19-db}"

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

check_running() {
    local container="$1"
    local status
    status="$(docker inspect --format='{{.State.Status}}' "${container}" 2>/dev/null)" \
        || fail "Container not found: ${container}"
    [[ "${status}" == "running" ]] || fail "Container is not running: ${container} (${status})"
    printf '[OK] Container is running: %s\n' "${container}"
}

command -v docker >/dev/null 2>&1 || fail "Docker is required."
check_running "${DB_CONTAINER}"
check_running "${ODOO_CONTAINER}"

if ! docker exec "${DB_CONTAINER}" sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    fail "PostgreSQL is not ready in ${DB_CONTAINER}."
fi
printf '[OK] PostgreSQL is accepting connections.\n'

ODOO_HEALTH="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}}' "${ODOO_CONTAINER}")"
if [[ "${ODOO_HEALTH}" != "healthy" ]]; then
    fail "Odoo health check is ${ODOO_HEALTH} in ${ODOO_CONTAINER}."
fi
printf '[OK] Odoo health check is healthy.\n'
