#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/run-orbit-transport-proof.sh [--runs <count>] [--filter <swift-test-filter>]

Description:
  Re-run the Orbit persistent-transport confidence ring against the focused
  gateway-network, transport-policy, and coordinator reconnect tests.

Options:
  --runs <count>         Number of repeated proof runs. Default: 5.
  --filter <filter>      Swift test filter to run.
                         Default: OrbitGatewayNetworkClientTests|OrbitServerBackedRoomTransportPolicyTests|OrbitServerBackedRoomCoordinatorTests
  -h, --help             Show help.
EOF
}

die() {
  printf "run-orbit-transport-proof: %s\n" "$*" >&2
  exit 1
}

runs="${ORBIT_M3_TRANSPORT_PROOF_RUNS:-5}"
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

printf "Running Orbit transport proof %s time(s) with filter %s\n" "$runs" "$filter"

for run_number in $(seq 1 "$runs"); do
  printf "\n[%s/%s] swift test --filter %s\n" "$run_number" "$runs" "$filter"
  swift test --filter "$filter"
done

printf "\nOrbit transport proof completed successfully.\n"
