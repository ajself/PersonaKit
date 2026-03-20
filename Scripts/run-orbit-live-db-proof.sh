#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/run-orbit-live-db-proof.sh [--runs <count>] [--filter <swift-test-filter>] [--local-temp-postgres]

Description:
  Re-run the Orbit live Postgres proof harness against the database described by
  ORBIT_PG_HOST / ORBIT_PG_PORT / ORBIT_PG_USER / ORBIT_PG_PASSWORD /
  ORBIT_PG_DATABASE. Use --local-temp-postgres to boot a temporary local
  Postgres instance in /tmp and wire those variables automatically.

Options:
  --runs <count>         Number of repeated proof runs. Default: 3.
  --filter <filter>      Swift test filter to run. Default: OrbitPostgresRuntimeStoreIntegrationTests.
  --local-temp-postgres  Boot a temporary local Postgres instance in /tmp and
                         run the proof harness against it.
  -h, --help             Show help.
EOF
}

die() {
  printf "run-orbit-live-db-proof: %s\n" "$*" >&2
  exit 1
}

runs="${ORBIT_M3_LIVE_DB_PROOF_RUNS:-3}"
filter="OrbitPostgresRuntimeStoreIntegrationTests"
use_local_temp_postgres=0
local_tmp_base=""
local_data_dir=""
local_log_file=""
local_port=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      [[ $# -ge 2 ]] || die "Missing value for --runs."
      runs="$2"
      shift 2
      ;;
    --filter)
      [[ $# -ge 2 ]] || die "Missing value for --filter."
      filter="$2"
      shift 2
      ;;
    --local-temp-postgres)
      use_local_temp_postgres=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ "$runs" =~ ^[1-9][0-9]*$ ]] || die "--runs must be a positive integer."

cleanup() {
  if [[ -n "$local_data_dir" ]]; then
    pg_ctl -D "$local_data_dir" -m immediate stop >/dev/null 2>&1 || true
  fi

  if [[ -n "$local_tmp_base" ]]; then
    rm -rf "$local_tmp_base"
  fi
}

pick_free_port() {
  python3 -c 'import socket; sock = socket.socket(); sock.bind(("127.0.0.1", 0)); print(sock.getsockname()[1]); sock.close()'
}

start_local_temp_postgres() {
  command -v initdb >/dev/null 2>&1 || die "Missing required command: initdb"
  command -v pg_ctl >/dev/null 2>&1 || die "Missing required command: pg_ctl"
  command -v psql >/dev/null 2>&1 || die "Missing required command: psql"
  command -v python3 >/dev/null 2>&1 || die "Missing required command: python3"

  local_tmp_base="$(mktemp -d /tmp/orbit-live-db-proof.XXXXXX)"
  local_data_dir="$local_tmp_base/data"
  local_log_file="$local_tmp_base/postgres.log"
  local_port="${ORBIT_M3_LOCAL_PG_PORT:-$(pick_free_port)}"

  trap cleanup EXIT

  initdb -D "$local_data_dir" --username postgres --auth=trust --no-locale >/dev/null
  pg_ctl \
    -D "$local_data_dir" \
    -l "$local_log_file" \
    -o "-F -c shared_memory_type=mmap -h 127.0.0.1 -p $local_port" \
    -w \
    start >/dev/null || {
      cat "$local_log_file" >&2
      die "Failed to start temporary local Postgres."
    }

  psql \
    -h 127.0.0.1 \
    -p "$local_port" \
    -U postgres \
    -d postgres \
    -c "CREATE DATABASE orbit_runtime;" >/dev/null

  export ORBIT_PG_HOST="127.0.0.1"
  export ORBIT_PG_PORT="$local_port"
  export ORBIT_PG_USER="postgres"
  export ORBIT_PG_PASSWORD="orbit"
  export ORBIT_PG_DATABASE="orbit_runtime"

  printf "Booted temporary local Postgres on port %s\n" "$local_port"
}

require_runtime_store_env() {
  local required_env_vars=(
    ORBIT_PG_HOST
    ORBIT_PG_USER
    ORBIT_PG_PASSWORD
    ORBIT_PG_DATABASE
  )

  local env_var
  for env_var in "${required_env_vars[@]}"; do
    [[ -n "${!env_var:-}" ]] || die "Missing required environment variable: $env_var"
  done
}

if [[ "$use_local_temp_postgres" == "1" ]]; then
  start_local_temp_postgres
else
  require_runtime_store_env
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

printf "Running Orbit live Postgres proof %s time(s) with filter %s\n" "$runs" "$filter"

for run_number in $(seq 1 "$runs"); do
  printf "\n[%s/%s] swift test --filter %s\n" "$run_number" "$runs" "$filter"
  swift test --filter "$filter"
done

printf "\nOrbit live Postgres proof completed successfully.\n"
