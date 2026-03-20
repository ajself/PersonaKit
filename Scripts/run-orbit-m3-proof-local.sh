#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/run-orbit-m3-proof-local.sh [--transport-runs <count>] [--live-db-runs <count>]

Description:
  Run the current local M3 Orbit proof bundle by executing the bounded
  persistent-transport confidence ring and the local temp-Postgres live-db
  proof harness in one command.

Options:
  --transport-runs <count>  Transport proof repetitions. Default: 3.
  --live-db-runs <count>    Live-db proof repetitions. Default: 3.
  -h, --help                Show help.
EOF
}

die() {
  printf "run-orbit-m3-proof-local: %s\n" "$*" >&2
  exit 1
}

transport_runs="${ORBIT_M3_TRANSPORT_PROOF_RUNS:-3}"
live_db_runs="${ORBIT_M3_LIVE_DB_PROOF_RUNS:-3}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --transport-runs)
      [[ $# -ge 2 ]] || die "Missing value for --transport-runs."
      transport_runs="$2"
      shift 2
      ;;
    --live-db-runs)
      [[ $# -ge 2 ]] || die "Missing value for --live-db-runs."
      live_db_runs="$2"
      shift 2
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

[[ "$transport_runs" =~ ^[1-9][0-9]*$ ]] || die "--transport-runs must be a positive integer."
[[ "$live_db_runs" =~ ^[1-9][0-9]*$ ]] || die "--live-db-runs must be a positive integer."

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

printf "Running local Orbit M3 proof bundle\n"
printf "  transport runs: %s\n" "$transport_runs"
printf "  live-db runs:   %s\n" "$live_db_runs"

./Scripts/run-orbit-transport-proof.sh --runs "$transport_runs"
./Scripts/run-orbit-live-db-proof.sh --local-temp-postgres --runs "$live_db_runs"

printf "\nLocal Orbit M3 proof bundle completed successfully.\n"
