#!/usr/bin/env bash
set -euo pipefail

# Tag the judged commit and publish the GitHub Release, then point the
# release PR's compare link at the tag.
#
# Run from the root of the caller's repository, checked out at HEAD_SHA with
# full history. Re-running is safe: an existing Release is kept and only its
# assets are replaced.
#
# Usage:
#   publish-release.sh [asset ...]
#
# Environment variables:
#   GH_TOKEN, GITHUB_REPOSITORY - see lib/github.sh.
#   HEAD_SHA                    - the commit to tag (required).
#   TAG                         - e.g. v8.0.0 (required).
#   PR_NUMBER                   - the merged release PR (required).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/summary.sh
source "${SCRIPT_DIR}/lib/summary.sh"
# shellcheck source=scripts/lib/github.sh
source "${SCRIPT_DIR}/lib/github.sh"

main() {
  local sha="${HEAD_SHA:?HEAD_SHA is required}"
  local tag="${TAG:?TAG is required}"
  local pr_number="${PR_NUMBER:?PR_NUMBER is required}"
  local notes

  notes="${RUNNER_TEMP:-/tmp}/colophon-release-notes.md"
  write_notes "$pr_number" "$tag" "$sha" >"$notes"

  if gh release view "$tag" >/dev/null 2>&1; then
    echo "Release ${tag} already exists; keeping it."
    if [ "$#" -gt 0 ]; then
      gh release upload "$tag" "$@" --clobber
    fi
  else
    gh release create "$tag" --target "$sha" --title "Release ${tag}" \
      --notes-file "$notes" "$@"
  fi

  rewrite_pr_links "$pr_number" "$tag"
}

# The summary written in the release PR, then links to the full changelog
# and the comparison with the previous release.
write_notes() {
  local pr_number="$1" tag="$2" sha="$3"
  local repo_url body last_tag

  repo_url=$(gh repo view --json url --jq '.url')
  body=$(gh pr view "$pr_number" --json body --jq '.body')
  # The previous release, never the one being cut: on a re-run the new tag
  # may already point at this commit.
  last_tag=$(last_version_tag "$sha" "$tag")

  printf '%s\n\n---\n\n' "$(summary_region "$body")"
  printf -- '- Full changelog: %s/pull/%s\n' "$repo_url" "$pr_number"
  if [ -n "$last_tag" ]; then
    printf -- '- Compare: [%s...%s](%s/compare/%s...%s)\n' \
      "$last_tag" "$tag" "$repo_url" "$last_tag" "$tag"
  fi
}

rewrite_pr_links() {
  local pr_number="$1" tag="$2"
  local branch body

  branch=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName')
  body=$(gh pr view "$pr_number" --json body --jq '.body')
  rewrite_compare_link "$body" "$branch" "$tag" | gh pr edit "$pr_number" --body-file -
}

main "$@"
