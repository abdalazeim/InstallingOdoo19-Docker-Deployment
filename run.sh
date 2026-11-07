#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY_URL="https://github.com/abdalazeim/InstallingOdoo19-Docker-Deployment.git"
DESTINATION=""
ODOO_PORT=""
CHAT_PORT=""

usage() {
    cat <<'EOF'
Usage:
  bash run.sh --destination <directory> --port <odoo-port> --chat <chat-port>

Example:
  bash run.sh --destination odoo-live --port 10019 --chat 20019
EOF
}

while (($#)); do
    case "$1" in
        --destination)
            (($# >= 2)) || { usage >&2; exit 2; }
            DESTINATION="$2"
            shift 2
            ;;
        --port)
            (($# >= 2)) || { usage >&2; exit 2; }
            ODOO_PORT="$2"
            shift 2
            ;;
        --chat)
            (($# >= 2)) || { usage >&2; exit 2; }
            CHAT_PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "${DESTINATION}" || -z "${ODOO_PORT}" || -z "${CHAT_PORT}" ]]; then
    usage >&2
    exit 2
fi

validate_port() {
    local name="$1"
    local value="$2"
    if [[ ! "${value}" =~ ^[0-9]+$ ]] || ((10#${value} < 1 || 10#${value} > 65535)); then
        printf 'Error: %s must be a port number between 1 and 65535.\n' "${name}" >&2
        exit 2
    fi
}

validate_port "--port" "${ODOO_PORT}"
validate_port "--chat" "${CHAT_PORT}"

if [[ "${DESTINATION}" == "/" || "${DESTINATION}" == "." || "${DESTINATION}" == ".." ]]; then
    printf 'Error: destination must be a new project directory, not %s.\n' "${DESTINATION}" >&2
    exit 2
fi

if ! command -v git >/dev/null 2>&1; then
    printf 'Error: Git is required. Install Git and try again.\n' >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    printf 'Error: Docker Engine and Docker Compose v2 are required.\n' >&2
    exit 1
fi

if [[ -e "${DESTINATION}" ]]; then
    printf 'Error: destination already exists: %s\n' "${DESTINATION}" >&2
    exit 1
fi

INSTANCE_NAME="${DESTINATION##*/}"
INSTANCE_SLUG="$(printf '%s' "${INSTANCE_NAME}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//')"

if [[ -z "${INSTANCE_SLUG}" ]]; then
    printf 'Error: destination must include letters or numbers.\n' >&2
    exit 2
fi

printf 'Cloning Odoo 19 deployment into %s...\n' "${DESTINATION}"
git clone --depth 1 "${REPOSITORY_URL}" "${DESTINATION}"

PROJECT_DIR="${DESTINATION}"
cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"

set_env() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "${PROJECT_DIR}/.env"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${PROJECT_DIR}/.env"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${PROJECT_DIR}/.env"
    fi
}

set_env "ODOO_HTTP_PORT" "${ODOO_PORT}"
set_env "ODOO_CHAT_PORT" "${CHAT_PORT}"
set_env "ODOO_NETWORK" "odoo19_${INSTANCE_SLUG}_internal"
set_env "ODOO_CONTAINER_NAME" "odoo19-${INSTANCE_SLUG}"
set_env "ODOO_DB_CONTAINER_NAME" "odoo19-${INSTANCE_SLUG}-db"
set_env "ODOO_DATA_VOLUME" "odoo19_${INSTANCE_SLUG}_data"
set_env "ODOO_ROUTER_NAME" "odoo19-${INSTANCE_SLUG}"

"${PROJECT_DIR}/scripts/install-odoo19.sh"
