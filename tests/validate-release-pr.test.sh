#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/validate-release-pr.sh.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"

VALIDATE="${TESTS_DIR}/../scripts/validate-release-pr.sh"
MARKER='<!-- changelog:auto -->'
WRITTEN=$(printf '%s\n' '## Summary' '' 'Snaps faster.' '' "$MARKER" '' '- fix: x')
UNWRITTEN=$(printf '%s\n' '## Summary' '' '<!-- release-summary:todo -->' '' "$MARKER")

assert_status "valid semver release PR" 0 "$VALIDATE" semver "Release v8.0.0" "$WRITTEN" v7
assert_status "valid integer release PR" 0 "$VALIDATE" integer "Release v8" "$WRITTEN" v7
assert_status "skipped version" 1 "$VALIDATE" semver "Release v9.0.0" "$WRITTEN" v7
assert_status "malformed title" 1 "$VALIDATE" semver "Release 8.0.0" "$WRITTEN" v7
assert_status "unwritten summary" 1 "$VALIDATE" semver "Release v8.0.0" "$UNWRITTEN" v7
assert_status "missing marker" 1 "$VALIDATE" semver "Release v8.0.0" "no marker" v7
assert_status "usage" 2 "$VALIDATE" semver "Release v8.0.0"

output=$("$VALIDATE" semver "Release v9.0.0" "$UNWRITTEN" v7 2>&1)
assert_contains "reports the title" "$output" "Disallowed version transition"
assert_contains "reports the summary too" "$output" "no release summary"

finish
