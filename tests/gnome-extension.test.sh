#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/writers/gnome-extension.sh.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"

WRITER="${TESTS_DIR}/../scripts/writers/gnome-extension.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

metadata() {
  cat >"${WORK}/metadata.json" <<EOF
{
  "uuid": "example@example.com",
  "name": "Example",
  "shell-version": ["50"],
  "version": $1
}
EOF
}

metadata 7
"$WRITER" semver 8.0.0 "${WORK}/metadata.json"
assert_eq "semver sets version-name" "8.0.0" "$(jq -r '."version-name"' "${WORK}/metadata.json")"
assert_eq "semver bumps the integer" "8" "$(jq -r '.version' "${WORK}/metadata.json")"
assert_eq "semver keeps other fields" "example@example.com" "$(jq -r '.uuid' "${WORK}/metadata.json")"

metadata 9
"$WRITER" semver 8.0.1 "${WORK}/metadata.json"
assert_eq "semver patch still bumps the integer" "10" "$(jq -r '.version' "${WORK}/metadata.json")"

metadata 0
"$WRITER" integer 1 "${WORK}/metadata.json"
assert_eq "integer writes the version" "1" "$(jq -r '.version' "${WORK}/metadata.json")"
assert_eq "integer leaves version-name unset" "null" "$(jq -r '."version-name"' "${WORK}/metadata.json")"

assert_status "missing file" 1 "$WRITER" semver 8.0.0 "${WORK}/missing.json"
assert_status "unknown scheme" 1 "$WRITER" calver 2026.10 "${WORK}/metadata.json"
assert_status "usage" 2 "$WRITER" semver 8.0.0

printf '{"version": "seven"}\n' >"${WORK}/metadata.json"
assert_status "non-integer version" 1 "$WRITER" semver 8.0.0 "${WORK}/metadata.json"

finish
