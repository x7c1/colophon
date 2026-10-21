#!/usr/bin/env bash
# The hand-written summary region of a release PR body.
#
# The body is split in two by a marker line: everything above it is written
# by a person and preserved when the PR is regenerated, everything below it
# is rebuilt from `git log`. The summary region becomes the GitHub Release
# body. This file holds the only definition of the marker string.
#
# Every function here is pure text manipulation — no network, no git — so
# tests/summary.test.sh can exercise them offline.

# The marker that separates the human region from the generated changelog.
changelog_marker() {
  printf '%s\n' '<!-- changelog:auto -->'
}

# The sentinel left in a freshly generated body, marking a summary that has
# not been written yet.
summary_sentinel() {
  printf '%s\n' '<!-- release-summary:todo -->'
}

# The starting point for a summary nobody has written yet.
summary_placeholder() {
  cat <<EOF
## Summary

$(summary_sentinel)
_Write the release summary here. It becomes the body of the GitHub Release.
Delete the marker comment above once written._
EOF
}

# Echo everything above the first marker, with trailing whitespace trimmed.
# Echo nothing when the marker is absent: without it there is no telling
# where a summary would end. The split is on the exact marker string, so
# arbitrary Markdown in the human region cannot corrupt it.
summary_region() {
  local body="$1"
  local marker region

  marker=$(changelog_marker)
  if [[ "$body" != *"$marker"* ]]; then
    return 0
  fi

  region="${body%%"$marker"*}"
  region="${region%"${region##*[![:space:]]}"}"

  if [ -z "$region" ]; then
    return 0
  fi
  printf '%s\n' "$region"
}

# Succeed when the summary cannot serve as a release body: empty, blank once
# HTML comments are removed, or still carrying the sentinel.
summary_is_unwritten() {
  local summary="$1"
  local stripped

  if [[ "$summary" == *"$(summary_sentinel)"* ]]; then
    return 0
  fi

  stripped=$(strip_html_comments "$summary")
  [ -z "${stripped//[[:space:]]/}" ]
}

# Remove every complete `<!-- ... -->` comment, including multi-line ones.
strip_html_comments() {
  local text="$1"
  local head tail

  while [[ "$text" == *'<!--'*'-->'* ]]; do
    head="${text%%'<!--'*}"
    tail="${text#*'<!--'}"
    tail="${tail#*'-->'}"
    text="${head}${tail}"
  done
  printf '%s' "$text"
}

# Point the compare link at the tag instead of the (deleted) release branch,
# rewriting only the region below the marker so a summary that mentions the
# branch is left untouched. A body whose marker was deleted is rewritten
# whole.
rewrite_compare_link() {
  local body="$1" branch="$2" tag="$3"
  local marker head tail

  marker=$(changelog_marker)
  if [[ "$body" == *"$marker"* ]]; then
    head="${body%%"$marker"*}${marker}"
    tail="${body#*"$marker"}"
  else
    head=""
    tail="$body"
  fi

  printf '%s%s\n' "$head" "${tail//...${branch}/...${tag}}"
}
