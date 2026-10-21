#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/lib/summary.sh.
#
# The marker and sentinel are spelled out here on purpose, so the tests check
# the split against a fixed string rather than against the script's own
# output.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"
# shellcheck source=scripts/lib/summary.sh
source "${TESTS_DIR}/../scripts/lib/summary.sh"

MARKER='<!-- changelog:auto -->'
SENTINEL='<!-- release-summary:todo -->'

assert_eq "changelog_marker" "$MARKER" "$(changelog_marker)"
assert_eq "summary_sentinel" "$SENTINEL" "$(summary_sentinel)"

# --- summary_region ---------------------------------------------------------

body=$(printf '%s\n' '## Summary' '' 'Snaps faster.' '' "$MARKER" '' '## Features' '- feat: x')
assert_eq "region above the marker" "$(printf '%s\n' '## Summary' '' 'Snaps faster.')" "$(summary_region "$body")"
assert_eq "no marker, no region" "" "$(summary_region 'just text')"
assert_eq "nothing above the marker" "" "$(summary_region "$(printf '\n\n%s\n- x' "$MARKER")")"

twice=$(printf '%s\n' 'Top' "$MARKER" 'middle' "$MARKER" 'bottom')
assert_eq "splits at the first marker" "Top" "$(summary_region "$twice")"

fenced=$(printf '%s\n' '```' '<!-- not the marker -->' '```' "$MARKER")
assert_contains "keeps code fences" "$(summary_region "$fenced")" '<!-- not the marker -->'

# --- summary_is_unwritten ---------------------------------------------------

assert_status "placeholder is unwritten" 0 summary_is_unwritten "$(summary_placeholder)"
assert_status "empty is unwritten" 0 summary_is_unwritten ""
assert_status "comments only is unwritten" 0 summary_is_unwritten "<!-- a -->
<!-- multi
line -->"
assert_status "sentinel with text is unwritten" 0 summary_is_unwritten "Text
${SENTINEL}"
assert_status "text is written" 1 summary_is_unwritten "## Summary

Snaps faster."

# --- rewrite_compare_link ---------------------------------------------------

branch="release/since-2026-10-22-0430"
body=$(printf '%s\n' "See ...${branch} above" "$MARKER" "- [v7...v8.0.0](https://github.com/o/r/compare/v7...${branch})")
rewritten=$(rewrite_compare_link "$body" "$branch" v8.0.0)
assert_contains "rewrites the link below the marker" "$rewritten" "compare/v7...v8.0.0)"
assert_contains "keeps the summary as written" "$rewritten" "See ...${branch} above"

no_marker="- [v7...v8.0.0](https://github.com/o/r/compare/v7...${branch})"
assert_eq "rewrites a body without the marker" \
  "- [v7...v8.0.0](https://github.com/o/r/compare/v7...v8.0.0)" \
  "$(rewrite_compare_link "$no_marker" "$branch" v8.0.0)"

finish
