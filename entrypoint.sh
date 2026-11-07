#!/bin/sh
set -eu
umask 077

: "${HOST:=db}"
: "${PORT:=5432}"
: "${USER:?USER must be set}"
: "${PASSWORD:?PASSWORD must be set}"
: "${ODOO_ADMIN_PASSWORD:?ODOO_ADMIN_PASSWORD must be set}"
: "${ODOO_PROXY_MODE:=False}"

python3 - <<'PY'
import os
from pathlib import Path

source = Path("/etc/odoo/odoo.conf").read_text(encoding="utf-8")
values = {
    "${ODOO_ADMIN_PASSWORD}": os.environ["ODOO_ADMIN_PASSWORD"],
    "${POSTGRES_USER}": os.environ["USER"],
    "${POSTGRES_PASSWORD}": os.environ["PASSWORD"],
    "${ODOO_PROXY_MODE}": os.environ.get("ODOO_PROXY_MODE", "False"),
}
for placeholder, value in values.items():
    if "\n" in value or "\r" in value:
        raise SystemExit(f"Invalid newline in value for {placeholder}")
    source = source.replace(placeholder, value)

unresolved = [placeholder for placeholder in values if placeholder in source]
if unresolved:
    raise SystemExit(f"Unresolved Odoo configuration values: {', '.join(unresolved)}")

config = Path("/tmp/odoo.conf")
config.write_text(source, encoding="utf-8")
config.chmod(0o600)
PY

python3 - <<'PY'
import os
import socket
import time

host = os.environ.get("HOST", "db")
port = int(os.environ.get("PORT", "5432"))
for _ in range(60):
    try:
        with socket.create_connection((host, port), timeout=2):
            break
    except OSError:
        time.sleep(1)
else:
    raise SystemExit(f"Timed out waiting for PostgreSQL at {host}:{port}")
PY

exec odoo "$@"
