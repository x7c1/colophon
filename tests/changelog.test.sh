#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/lib/changelog.sh.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"
# shellcheck source=scripts/lib/changelog.sh
source "${TESTS_DIR}/../scripts/lib/changelog.sh"

REPO="https://github.com/o/r"

assert_eq "type" "feat" "$(changelog_type_of 'feat: x')"
assert_eq "type with scope" "fix" "$(changelog_type_of 'fix(ui): x')"
assert_eq "breaking type" "feat" "$(changelog_type_of 'feat!: x')"
assert_eq "breaking type with scope" "refactor" "$(changelog_type_of 'refactor(core)!: x')"
assert_eq "unknown type" "other" "$(changelog_type_of 'build: x')"
assert_eq "no type" "other" "$(changelog_type_of 'Update README')"

log=$(printf '%s\n' \
  'abc1234 fix: second (#12)' \
  'abc1235 Update README' \
  'abc1236 feat(ui): first' \
  'abc1237 fix(core): third')
expected=$(printf '%s\n' \
  '## Features' \
  '' \
  '- feat(ui): first' \
  '' \
  '## Bug Fixes' \
  '' \
  "- fix: second ([#12](${REPO}/pull/12))" \
  '- fix(core): third' \
  '' \
  '## Other Changes' \
  '' \
  '- Update README')
assert_eq "groups in a fixed order and links PRs" "$expected" "$(format_changelog "$log" "$REPO")"
assert_eq "empty log" "" "$(format_changelog "" "$REPO")"

finish
