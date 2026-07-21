#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'Python 3.12 or newer is required.\n' >&2
  exit 1
fi
if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)'; then
  printf 'Python 3.12 or newer is required.\n' >&2
  exit 1
fi

runtime_port="${DISCOVERY_PORT:-${PORT:-8080}}"
if [[ ! "$runtime_port" =~ ^[0-9]+$ ]] || [ "$runtime_port" -lt 1 ] || [ "$runtime_port" -gt 65535 ]; then
  printf 'DISCOVERY_PORT must be an integer between 1 and 65535.\n' >&2
  exit 1
fi

export DISCOVERY_DATABASE="${DISCOVERY_DATABASE:-${DB_PATH:-var/discovery.db}}"
export DISCOVERY_HOST="${DISCOVERY_HOST:-127.0.0.1}"
export DISCOVERY_PORT="$runtime_port"

# The acceptance harness supplies a unique disposable DB_PATH. Normal startup
# remains readiness-only and refuses an uninitialized database.
if [ "${NODE_ENV:-}" = test ] && [ -n "${DB_PATH:-}" ] && [ "$DISCOVERY_DATABASE" = "$DB_PATH" ] && [ ! -e "$DISCOVERY_DATABASE" ]; then
  python3 -m discovery init-db
fi

exec ./bin/start
