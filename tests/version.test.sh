#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/lib/version.sh.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"
# shellcheck source=scripts/lib/version.sh
source "${TESTS_DIR}/../scripts/lib/version.sh"

# --- release_title / version_from_title -------------------------------------

assert_eq "release_title" "Release v8.0.0" "$(release_title 8.0.0)"
assert_eq "semver title" "8.0.1" "$(version_from_title semver 'Release v8.0.1')"
assert_eq "integer title" "8" "$(version_from_title integer 'Release v8')"
assert_status "semver rejects an integer title" 1 version_from_title semver "Release v8"
assert_status "integer rejects a semver title" 1 version_from_title integer "Release v8.0.0"
assert_status "semver rejects a suffix" 1 version_from_title semver "Release v8.0.0-rc1"
assert_status "semver rejects a missing v" 1 version_from_title semver "Release 8.0.0"
assert_status "unknown scheme" 1 version_from_title calver "Release v2026.10"

# --- default_next_version ---------------------------------------------------

assert_eq "semver without a tag starts at 0.1.0" "0.1.0" "$(default_next_version semver '')"
assert_eq "semver bumps the patch" "0.3.11" "$(default_next_version semver v0.3.10)"
assert_eq "semver reads a legacy integer tag as N.0.0" "7.0.1" "$(default_next_version semver v7)"
assert_eq "integer without a tag starts at 1" "1" "$(default_next_version integer '')"
assert_eq "integer adds one" "8" "$(default_next_version integer v7)"
assert_status "integer rejects a semver tag" 1 default_next_version integer v1.0.0
assert_status "semver rejects a malformed tag" 1 default_next_version semver release-1

# --- check_transition: semver -----------------------------------------------

assert_status "semver patch+1" 0 check_transition semver v0.3.10 0.3.11
assert_status "semver minor+1" 0 check_transition semver v0.3.10 0.4.0
assert_status "semver major+1" 0 check_transition semver v0.3.10 1.0.0
assert_status "semver first release from v0.0.0" 0 check_transition semver "" 0.1.0
assert_status "semver legacy v7 -> 8.0.0" 0 check_transition semver v7 8.0.0
assert_status "semver legacy v7 -> 7.0.1" 0 check_transition semver v7 7.0.1
assert_status "semver same version" 1 check_transition semver v0.3.10 0.3.10
assert_status "semver skipped patch" 1 check_transition semver v0.3.10 0.3.12
assert_status "semver minor without patch reset" 1 check_transition semver v0.3.10 0.4.1
assert_status "semver major without minor reset" 1 check_transition semver v0.3.10 1.3.0
assert_status "semver downgrade" 1 check_transition semver v0.3.10 0.2.0
assert_status "semver legacy v7 -> 9.0.0" 1 check_transition semver v7 9.0.0
assert_status "semver malformed version" 1 check_transition semver v0.3.10 0.4

# --- check_transition: integer ----------------------------------------------

assert_status "integer +1" 0 check_transition integer v7 8
assert_status "integer first release" 0 check_transition integer "" 1
assert_status "integer skip" 1 check_transition integer v7 9
assert_status "integer same" 1 check_transition integer v7 7
assert_status "integer semver version" 1 check_transition integer v7 8.0.0
assert_status "integer semver tag" 1 check_transition integer v7.0.0 8

finish
