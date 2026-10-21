#!/usr/bin/env bash
set -euo pipefail

# Decide whether a commit on main is a release, and which.
#
# A commit is a release when it is the merge of a PR labelled `release`
# whose title carries the version. Prints key=value lines and appends them
# to GITHUB_OUTPUT when set:
#
#   released  - true | false
#   version   - the version, e.g. 8.0.0 (released only)
#   tag       - v<version> (released only)
#   pr-number - the merged release PR (released only)
#
# Fails when the release PR carries no summary, before anything is tagged.
#
# Environment variables:
#   GH_TOKEN, GITHUB_REPOSITORY - see lib/github.sh.
#   COLOPHON_SCHEME             - semver | integer (required).
#   HEAD_SHA                    - the commit CI judged (required).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/version.sh
source "${SCRIPT_DIR}/lib/version.sh"
# shellcheck source=scripts/lib/summary.sh
source "${SCRIPT_DIR}/lib/summary.sh"
# shellcheck source=scripts/lib/github.sh
source "${SCRIPT_DIR}/lib/github.sh"

main() {
  local scheme="${COLOPHON_SCHEME:?COLOPHON_SCHEME is required}"
  local sha="${HEAD_SHA:?HEAD_SHA is required}"
  local pr_number title version body

  pr_number=$(find_release_pr_for_commit "$sha")
  if [ -z "$pr_number" ]; then
    echo "${sha} is not the merge of a release PR; nothing to release."
    output released false
    return 0
  fi

  title=$(gh pr view "$pr_number" --json title --jq '.title')
  version=$(version_from_title "$scheme" "$title")

  # Fetched in a statement of its own so a failed call aborts rather than
  # reading as an unwritten summary.
  body=$(gh pr view "$pr_number" --json body --jq '.body')
  if summary_is_unwritten "$(summary_region "$body")"; then
    printf "::error::Release PR #%s carries no release summary. Write it above the '%s' marker in the PR body and delete the '%s' comment, then re-run this workflow.\n" \
      "$pr_number" "$(changelog_marker)" "$(summary_sentinel)"
    return 1
  fi

  echo "${sha} releases v${version} (PR #${pr_number})."
  output released true
  output version "$version"
  output tag "v${version}"
  output pr-number "$pr_number"
}

output() {
  printf '%s=%s\n' "$1" "$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"
  fi
}

main "$@"
