#!/usr/bin/env bash
set -euo pipefail

# Open or refresh the one rolling release PR.
#
# Run from the root of the caller's repository, checked out with full
# history and a token that may push branches.
#
# The PR title carries the next version ("Release v0.2.0"). The first run
# after a release opens a PR at the default next version; later runs reuse
# the open PR's title and head branch, so a person can promote the title
# (patch -> minor/major) and the next run keeps it. Every run rebuilds the
# head branch from main and writes the version on top, so the PR always
# reflects main.
#
# Environment variables:
#   GH_TOKEN        - GitHub token (required).
#   COLOPHON_SCHEME - semver | integer (required).
#   COLOPHON_WRITER and friends - see lib/writer.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/version.sh
source "${SCRIPT_DIR}/lib/version.sh"
# shellcheck source=scripts/lib/summary.sh
source "${SCRIPT_DIR}/lib/summary.sh"
# shellcheck source=scripts/lib/changelog.sh
source "${SCRIPT_DIR}/lib/changelog.sh"
# shellcheck source=scripts/lib/github.sh
source "${SCRIPT_DIR}/lib/github.sh"
# shellcheck source=scripts/lib/writer.sh
source "${SCRIPT_DIR}/lib/writer.sh"

main() {
  local scheme="${COLOPHON_SCHEME:?COLOPHON_SCHEME is required}"
  local pr_number last_tag version branch repo_url changelog summary title

  # Everything this script describes is main. On a title edit the checkout
  # is the PR's merge ref instead, so start from origin/main before reading
  # history.
  git fetch origin main --tags
  git checkout --detach origin/main

  pr_number=$(find_open_release_pr)
  last_tag=$(last_version_tag)
  repo_url=$(gh repo view --json url --jq '.url')

  if [ -n "$pr_number" ]; then
    title=$(gh pr view "$pr_number" --json title --jq '.title')
    version=$(version_from_title "$scheme" "$title")
    branch=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName')
    summary=$(preserved_summary "$pr_number")
    echo "Updating release PR #${pr_number} on ${branch} for v${version}"
  else
    version=$(default_next_version "$scheme" "$last_tag")
    branch="release/since-$(date -u +'%Y-%m-%d-%H%M')"
    summary=$(summary_placeholder)
    echo "Opening ${branch} for v${version}"
  fi

  # The same check the validate workflow runs, so this script never
  # publishes a title that check rejects.
  check_transition "$scheme" "$last_tag" "$version"

  changelog=$(generate_changelog "$last_tag" "$repo_url")

  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git checkout -B "$branch" origin/main
  apply_version "$scheme" "$version"
  git add -A
  git commit --allow-empty -m "$(release_title "$version")"

  local body
  body=$(render_pr_body "$branch" "$version" "$last_tag" "$changelog" "$repo_url" "$summary")

  if [ -n "$pr_number" ]; then
    git push origin "$branch" --force
    gh pr edit "$pr_number" --body "$body"
  else
    ensure_release_label
    # A failed earlier run may have left the branch behind.
    git push origin "$branch" --force
    gh pr create --title "$(release_title "$version")" --label "$RELEASE_LABEL" \
      --head "$branch" --body "$body"
  fi
}

# The summary region of the PR's current body, or a fresh placeholder.
preserved_summary() {
  local pr_number="$1"
  local body summary

  # A failed fetch must not read as "no summary yet": the edit below would
  # then replace a hand-written summary with the placeholder.
  if ! body=$(gh pr view "$pr_number" --json body --jq '.body'); then
    echo "::error::Could not read the body of release PR #${pr_number}; refusing to regenerate it." >&2
    return 1
  fi

  summary=$(summary_region "$body")
  if [ -z "$summary" ]; then
    summary_placeholder
    return 0
  fi
  printf '%s\n' "$summary"
}

# The summary, the marker, the changelog, and a compare link against the
# release branch (rewritten to the tag once the release is published).
render_pr_body() {
  local branch="$1" version="$2" last_tag="$3" changelog="$4" repo_url="$5" summary="$6"
  local compare=""

  if [ -n "$last_tag" ]; then
    compare="## Changelog

- [${last_tag}...v${version}](${repo_url}/compare/${last_tag}...${branch})"
  fi

  cat <<EOF
${summary}

$(changelog_marker)

${changelog}

${compare}
EOF
}

main "$@"
