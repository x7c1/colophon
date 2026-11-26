#!/usr/bin/env bash
set -uo pipefail

# Checks that colophon's own workflows and the validate workflow leave a draft
# release PR alone and run on it once it is marked ready for review.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"

WORKFLOWS="${TESTS_DIR}/../.github/workflows"
SKIP_DRAFT_RELEASE="if: \${{ !(github.event_name == 'pull_request' && github.event.pull_request.draft && startsWith(github.head_ref, 'release/')) }}"

# The body of one job in a workflow: its lines up to the next job.
job() {
  awk -v job="  $2:" '
    $0 == job { found = 1; print; next }
    found && /^  [^ #]/ { exit }
    found { print }
  ' "${WORKFLOWS}/$1"
}

assert_contains "self-validate runs on ready_for_review" \
  "$(cat "${WORKFLOWS}/self-validate.yml")" "ready_for_review"
assert_contains "ci runs on ready_for_review" \
  "$(cat "${WORKFLOWS}/ci.yml")" "ready_for_review"
assert_not_contains "ci runs on pushes to main only, not to a release branch" \
  "$(cat "${WORKFLOWS}/ci.yml")" '"**"'
assert_contains "ci test skips a draft release PR" "$(job ci.yml test)" "$SKIP_DRAFT_RELEASE"
assert_contains "ci lint skips a draft release PR" "$(job ci.yml lint)" "$SKIP_DRAFT_RELEASE"
assert_not_contains "ci all-green still runs on a draft release PR" \
  "$(job ci.yml all-green)" "pull_request.draft"
assert_contains "validate passes the draft flag to the gate" \
  "$(job validate-release-pr.yml release-pr)" "PR_DRAFT: \${{ github.event.pull_request.draft }}"
assert_contains "validate gates on the title and the draft flag" \
  "$(job validate-release-pr.yml release-pr)" "release-pr-gate.sh \"\$PR_TITLE\" \"\$PR_DRAFT\""

finish
