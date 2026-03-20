#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/run-orbit-m3-proof-local.sh [--transport-runs <count>] [--live-db-runs <count>]

Description:
  Run the local Orbit M3 proof bundle by delegating to the shared M3 proof
  script with a temporary local Postgres instance for the live-db leg.

Options:
  --transport-runs <count>  Transport repetitions. Default: 3.
  --live-db-runs <count>    Live-db proof repetitions. Default: 3.
  -h, --help                Show help.
EOF
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
done

ORBIT_M3_TRANSPORT_SOAK_RUNS="${ORBIT_M3_TRANSPORT_PROOF_RUNS:-3}" \
  ./Scripts/run-orbit-m3-proof.sh --local-temp-postgres "$@"
