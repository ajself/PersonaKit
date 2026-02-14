#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="$repo_root/.swift-format"

if [[ ! -f "$configuration" ]]; then
  echo "Missing swift-format configuration: $configuration" >&2
  exit 1
fi

exec swift-format format --configuration "$configuration" "$@"
