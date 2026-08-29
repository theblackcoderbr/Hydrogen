#!/usr/bin/env bash

if [[ "${HYDROGEN_TEST_ENVIRONMENT:-}" != "nix-shell" ]]; then
    echo "ERROR: Hydrogen tests must run inside the pinned Nix environment." >&2
    echo "Run: nix-shell --pure --run './scripts/check.sh'" >&2
    exit 1
fi
