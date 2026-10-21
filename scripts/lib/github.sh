#!/usr/bin/env bash
# Lookups against the GitHub API and the repository's tags.
#
# Environment variables:
#   GH_TOKEN          - token for the GitHub CLI (required).
#   GITHUB_REPOSITORY - owner/repo (set by GitHub Actions).

RELEASE_LABEL="release"

# The number of the open release PR, or nothing.
find_open_release_pr() {
  gh pr list --label "$RELEASE_LABEL" --state open --json number --jq '.[0].number // empty'
}

# The number of the merged release PR whose merge produced the commit, or
# nothing. A release is the squash of a PR labelled `release`, so the PR
# is found from the commit rather than from any version file.
find_release_pr_for_commit() {
  local sha="$1"
  gh api "repos/${GITHUB_REPOSITORY}/commits/${sha}/pulls" \
    --jq "[.[] | select(.merged_at != null) | select(any(.labels[]; .name == \"${RELEASE_LABEL}\"))] | .[0].number // empty"
}

ensure_release_label() {
  gh label create "$RELEASE_LABEL" --description "Release PR" --color 0E8A16 2>/dev/null || true
}

# The latest version tag reachable from a commit (HEAD by default), ignoring
# the excluded tag. Tags that are not vN or vX.Y.Z are skipped.
last_version_tag() {
  local commit="${1:-HEAD}" exclude="${2:-}"
  local args=(describe --tags --abbrev=0 --match 'v[0-9]*')
  if [ -n "$exclude" ]; then
    args+=(--exclude "$exclude")
  fi
  git "${args[@]}" "$commit" 2>/dev/null || true
}
