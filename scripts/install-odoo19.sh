#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: Docker is required. Install Docker Engine and try again.\n' >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    printf 'Error: Docker Compose v2 is required (docker compose).\n' >&2
    exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${PROJECT_DIR}/.env.example" "${ENV_FILE}"
fi

set_env() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "${ENV_FILE}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
    fi
}

for key in POSTGRES_PASSWORD ODOO_ADMIN_PASSWORD; do
    current_value="$(sed -n "s/^${key}=//p" "${ENV_FILE}" | head -n 1)"
    if [[ -z "${current_value}" || "${current_value}" == replace-with-* ]]; then
        if ! command -v openssl >/dev/null 2>&1; then
            printf 'Error: OpenSSL is required to generate a secure %s.\n' "${key}" >&2
            exit 1
        fi
        set_env "${key}" "$(openssl rand -hex 24)"
    fi
done

mkdir -p "${PROJECT_DIR}/postgresql"
chmod 600 "${ENV_FILE}"
chmod +x "${PROJECT_DIR}/entrypoint.sh"
chmod 700 "${PROJECT_DIR}/postgresql"

docker compose --project-directory "${PROJECT_DIR}" -f "${PROJECT_DIR}/docker-compose.yml" pull
docker compose --project-directory "${PROJECT_DIR}" -f "${PROJECT_DIR}/docker-compose.yml" up -d

printf '\nOdoo 19 is starting.\n'
printf 'Project: %s\n' "${PROJECT_DIR}"
printf 'URL:     http://localhost:%s\n' "$(sed -n 's/^ODOO_HTTP_PORT=//p' "${ENV_FILE}" | head -n 1)"
printf 'Check:   docker compose -f %s/docker-compose.yml ps\n' "${PROJECT_DIR}"
