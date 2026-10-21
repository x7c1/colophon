#!/usr/bin/env bash
# Changelog grouped by Conventional Commit type.
#
# Usage:
#   source changelog.sh
#   changelog=$(generate_changelog "$last_tag" "$repo_url")
#
# With an empty last_tag (no release yet), the last 20 non-merge commits
# reachable from HEAD are summarized. format_changelog is pure, so
# tests/changelog.test.sh exercises it without a repository.

CHANGELOG_TYPES="feat fix perf refactor style docs chore other"

generate_changelog() {
  local last_tag="$1" repo_url="$2"
  local log

  if [ -n "$last_tag" ]; then
    log=$(git log "${last_tag}..HEAD" --oneline --no-merges)
  else
    log=$(git log --oneline --no-merges -20)
  fi

  format_changelog "$log" "$repo_url"
}

changelog_section_title() {
  case "$1" in
    feat) echo "Features" ;;
    fix) echo "Bug Fixes" ;;
    perf) echo "Performance" ;;
    refactor) echo "Refactoring" ;;
    style) echo "Style" ;;
    docs) echo "Documentation" ;;
    chore) echo "Chores" ;;
    *) echo "Other Changes" ;;
  esac
}

# The Conventional Commit type of a message (`type:` or `type(scope):`, an
# optional `!` included), or "other".
changelog_type_of() {
  local message="$1" type=""
  if [[ "$message" =~ ^([a-z]+)(\([^\)]*\))?!?: ]]; then
    type="${BASH_REMATCH[1]}"
  fi
  case "$type" in
    feat | fix | perf | refactor | style | docs | chore) echo "$type" ;;
    *) echo "other" ;;
  esac
}

# Render `git log --oneline` output as Markdown sections in a fixed order,
# turning `#123` into links to the repository's pull requests.
format_changelog() {
  local log="$1" repo_url="$2"
  local section line message items output=""

  for section in $CHANGELOG_TYPES; do
    items=""
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      message="${line#* }"
      if [ "$(changelog_type_of "$message")" != "$section" ]; then
        continue
      fi
      message=$(printf '%s' "$message" | sed -E "s|#([0-9]+)|[#\1](${repo_url}/pull/\1)|g")
      items+="- ${message}"$'\n'
    done <<<"$log"

    if [ -n "$items" ]; then
      output+="## $(changelog_section_title "$section")"$'\n\n'
      output+="${items}"$'\n'
    fi
  done

  printf '%s' "$output"
}
