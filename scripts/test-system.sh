#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/lib/require-test-environment.sh

for tool in qs sway swaymsg; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool is missing from the pinned Nix environment." >&2
        exit 1
    fi
done

exec ./tests/system/run-headless.sh
