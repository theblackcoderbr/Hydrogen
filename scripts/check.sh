#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/lib/require-test-environment.sh

./scripts/test-unit.sh
./scripts/lint.sh
./scripts/test-system.sh
