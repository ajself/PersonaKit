#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/run-orbit-m3-proof.sh [--transport-runs <count>] [--live-db-runs <count>] [--local-temp-postgres]

Description:
  Run the current Orbit M3 proof bundle by executing the transport soak lane and
  the live Postgres proof harness in one command. By default, the live-db leg
  expects ORBIT_PG_HOST / ORBIT_PG_PORT / ORBIT_PG_USER / ORBIT_PG_PASSWORD /
  ORBIT_PG_DATABASE to already be configured. Use --local-temp-postgres to boot
  a temporary local Postgres instance instead.

Options:
  --transport-runs <count>  Transport soak repetitions. Default: 10.
  --live-db-runs <count>    Live-db proof repetitions. Default: 3.
  --local-temp-postgres     Boot a temporary local Postgres instance in /tmp
                            for the live-db proof leg.
  -h, --help                Show help.
EOF
}

die() {
  printf "run-orbit-m3-proof: %s\n" "$*" >&2
  exit 1
}

transport_runs="${ORBIT_M3_TRANSPORT_SOAK_RUNS:-10}"
live_db_runs="${ORBIT_M3_LIVE_DB_PROOF_RUNS:-3}"
use_local_temp_postgres=0

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

[[ "$transport_runs" =~ ^[1-9][0-9]*$ ]] || die "--transport-runs must be a positive integer."
[[ "$live_db_runs" =~ ^[1-9][0-9]*$ ]] || die "--live-db-runs must be a positive integer."

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

printf "Running Orbit M3 proof bundle\n"
printf "  transport runs: %s\n" "$transport_runs"
printf "  live-db runs:   %s\n" "$live_db_runs"
printf "  live-db mode:   %s\n" "$([[ "$use_local_temp_postgres" == "1" ]] && printf "local-temp-postgres" || printf "configured-environment")"

./Scripts/run-orbit-transport-soak-local.sh --runs "$transport_runs"

live_db_args=("--runs" "$live_db_runs")
if [[ "$use_local_temp_postgres" == "1" ]]; then
  live_db_args=("--local-temp-postgres" "${live_db_args[@]}")
fi

./Scripts/run-orbit-live-db-proof.sh "${live_db_args[@]}"

printf "\nOrbit M3 proof bundle completed successfully.\n"
