#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")"&&pwd)";ENV_FILE="$PROJECT_DIR/.env"
load_env_file(){ local line key value;while IFS= read -r line||[ -n "$line" ];do [[ "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]]&&continue;line="${line#export }";key="${line%%=*}";value="${line#*=}";key="${key//[[:space:]]/}";[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]||continue;[ -n "${!key+x}" ]&&continue;if [[ "$value" == \"*\" && "$value" == *\" ]];then value="${value:1:${#value}-2}";elif [[ "$value" == \'*\' && "$value" == *\' ]];then value="${value:1:${#value}-2}";fi;export "$key=$value";done < "$ENV_FILE"; }
[ -f "$ENV_FILE" ]||{ echo "Missing required file: $ENV_FILE" >&2;exit 1; };load_env_file
: "${BACKEND_PORT:?BACKEND_PORT is required}";: "${FRONTEND_PORT:?FRONTEND_PORT is required}";: "${DATABASE_URL:?DATABASE_URL is required}"
: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required}";: "${OPENROUTER_MODEL:?OPENROUTER_MODEL is required}";: "${OPENROUTER_BASE_URL:?OPENROUTER_BASE_URL is required}"
for assigned_port in "$BACKEND_PORT" "$FRONTEND_PORT";do lsof -nP -iTCP:"$assigned_port" -sTCP:LISTEN >/dev/null 2>&1&&{ echo "Assigned port $assigned_port is occupied" >&2;exit 1; };done

python3 -c 'import sys;raise SystemExit(0 if sys.version_info >= (3,12) else 1)'||{ echo "Python 3.12 or newer is required" >&2;exit 1; }
export RUNTIME_PROJECT_NAME=SOLRProject RUNTIME_AI_ENDPOINT=/api/ai/discovery-assistant RUNTIME_AI_FEATURE=discovery-assistant
export RUNTIME_AI_SYSTEM_PROMPT='You are a search discovery operations assistant. Recommend safe query, indexing, and relevance steps while distinguishing evidence from assumptions.'
export DISCOVERY_HOST=127.0.0.1 DISCOVERY_PORT="$FRONTEND_PORT" DISCOVERY_DATABASE="${DISCOVERY_DATABASE:-$PROJECT_DIR/var/runtime-discovery.db}"
mkdir -p "$PROJECT_DIR/var"
node "$PROJECT_DIR/runtime/setup.mjs"
(cd "$PROJECT_DIR"&&python3 -m discovery init-db)
CHILD_PIDS=()
(cd "$PROJECT_DIR"&&exec node runtime/api.mjs)&CHILD_PIDS+=("$!")
(cd "$PROJECT_DIR"&&exec ./bin/start)&CHILD_PIDS+=("$!")
cleanup(){ trap - EXIT INT TERM;for pid in "${CHILD_PIDS[@]}";do kill "$pid" 2>/dev/null||true;done;for pid in "${CHILD_PIDS[@]}";do wait "$pid" 2>/dev/null||true;done; }
trap cleanup EXIT INT TERM
wait "${CHILD_PIDS[@]}"
