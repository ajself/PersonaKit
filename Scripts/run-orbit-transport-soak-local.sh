#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/run-orbit-transport-soak-local.sh [--runs <count>] [--filter <swift-test-filter>]

Description:
  Run a longer local Orbit transport soak by repeating the focused persistent-
  transport confidence ring enough times to catch reconnect and fallback drift
  before relying on ad hoc manual history.

Options:
  --runs <count>         Number of soak repetitions. Default: 10.
  --filter <filter>      Swift test filter to run.
                         Default: OrbitGatewayNetworkClientTests|OrbitServerBackedRoomTransportPolicyTests|OrbitServerBackedRoomCoordinatorTests
  -h, --help             Show help.
EOF
}

die() {
  printf "run-orbit-transport-soak-local: %s\n" "$*" >&2
  exit 1
}

runs="${ORBIT_M3_TRANSPORT_SOAK_RUNS:-10}"
filter="OrbitGatewayNetworkClientTests|OrbitServerBackedRoomTransportPolicyTests|OrbitServerBackedRoomCoordinatorTests"

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

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

printf "Running local Orbit transport soak with %s repetition(s)\n" "$runs"

./Scripts/run-orbit-transport-proof.sh --runs "$runs" --filter "$filter"

printf "\nLocal Orbit transport soak completed successfully.\n"
