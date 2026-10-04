#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
environment_file="$repository_root/.env.local"
api_binary="$repository_root/.build/betternb-api-dev"
api_log="$repository_root/.build/betternb-api.log"
app_binary="$repository_root/.build/BetterNB.app/Contents/MacOS/BetterNB"
api_pid=""

cleanup() {
    if [[ -n "$api_pid" ]] && kill -0 "$api_pid" 2>/dev/null; then
        kill "$api_pid" 2>/dev/null || true
        wait "$api_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

cd "$repository_root"

if [[ "${1:-}" == "--local-account" ]]; then
    export BETTERNB_DEV_AUTH_BYPASS=1
    echo "Using the local development account. Auth0 and PostgreSQL are not used."
    ./scripts/build-macos-prototype.sh
    exec "$app_binary"
fi

if [[ ! -f "$environment_file" ]]; then
    echo "Full sign-in needs .env.local. Copy .env.example and set the Auth0 values." >&2
    echo "This script starts PostgreSQL from compose.yaml. Use --local-account only to skip Auth0." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$environment_file"
set +a
unset BETTERNB_DEV_AUTH_BYPASS

required_variables=(
    BETTERNB_DATABASE_URL
    BETTERNB_AUTH0_ISSUER
    BETTERNB_AUTH0_DOMAIN
    BETTERNB_AUTH0_CLIENT_ID
    BETTERNB_AUTH0_AUDIENCE
)
for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]] || [[ "${!variable_name}" == *YOUR_* ]]; then
        echo "Set $variable_name in .env.local before running BetterNB." >&2
        exit 1
    fi
done

ensure_postgres() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is required to start the local PostgreSQL database." >&2
        exit 1
    fi
    if docker exec betternb-postgres pg_isready -U betternb -d betternb >/dev/null 2>&1; then
        return
    fi
    if docker ps -a --format '{{.Names}}' | grep -qx 'betternb-postgres'; then
        docker start betternb-postgres >/dev/null
    else
        docker compose up -d postgres
    fi
    for _ in {1..50}; do
        if docker exec betternb-postgres pg_isready -U betternb -d betternb >/dev/null 2>&1; then
            return
        fi
        sleep 0.2
    done
    echo "PostgreSQL did not become ready." >&2
    exit 1
}

ensure_postgres

export BETTERNB_API_ADDRESS="${BETTERNB_API_ADDRESS:-127.0.0.1:8081}"
export BETTERNB_API_URL="${BETTERNB_API_URL:-http://127.0.0.1:8081}"

mkdir -p "$repository_root/.build"
go build -o "$api_binary" ./cmd/betternb-api
"$api_binary" -address "$BETTERNB_API_ADDRESS" -migrate >"$api_log" 2>&1 &
api_pid=$!

health_url="${BETTERNB_API_URL%/}/healthz"
for _ in {1..50}; do
    if curl --fail --silent --show-error "$health_url" >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$api_pid" 2>/dev/null; then
        echo "The account API failed to start. Log output:" >&2
        tail -n 40 "$api_log" >&2 || true
        exit 1
    fi
    sleep 0.2
done

if ! curl --fail --silent --show-error "$health_url" >/dev/null; then
    echo "The account API did not become ready at $health_url. Log output:" >&2
    tail -n 40 "$api_log" >&2 || true
    exit 1
fi

./scripts/build-macos-prototype.sh
"$app_binary"
