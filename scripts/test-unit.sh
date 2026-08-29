#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/lib/require-test-environment.sh

qml_test_runner="$(command -v qmltestrunner || true)"
if [[ -z "$qml_test_runner" ]]; then
    echo "ERROR: qmltestrunner is missing from the pinned Nix environment." >&2
    exit 1
fi
if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: node is missing from the pinned Nix environment." >&2
    exit 1
fi

QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH="$PWD/hydrogen${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
    "$qml_test_runner" -input tests/qml
node --test tests/unit/*.test.mjs
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/unit/test_sway_bridge.py
