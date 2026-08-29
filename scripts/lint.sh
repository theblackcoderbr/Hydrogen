#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/lib/require-test-environment.sh

qml_lint="$(command -v qmllint || true)"
if [[ -z "$qml_lint" ]]; then
    echo "ERROR: qmllint is missing from the pinned Nix environment." >&2
    exit 1
fi

mapfile -t qml_files < <(find hydrogen -name '*.qml' -type f -print | sort)
QML_IMPORT_PATH="$PWD/hydrogen${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" "$qml_lint" -E -W 0 "${qml_files[@]}"
