#!/usr/bin/env bash
# Version arithmetic for release PR titles and tags.
#
# A repository picks one version scheme:
#
#   semver  — titles "Release vX.Y.Z", tags vX.Y.Z. The next version is
#             patch+1 by default; a person may promote the title to minor+1
#             (patch reset) or major+1 (minor and patch reset).
#   integer — titles "Release vN", tags vN. The next version is always N+1.
#
# Under semver, a legacy integer tag vN reads as N.0.0, so a repository that
# released v1..v7 can move to semver with v8.0.0 as a major bump.
#
# Every function here is pure text manipulation — no network, no git — so
# tests/version.test.sh can exercise them offline. Errors are printed as
# `::error::` lines on stderr and reported through a non-zero status.

# Echo "MAJOR MINOR PATCH" for a semver tag (vX.Y.Z, or legacy vN).
semver_from_tag() {
  local tag="$1"
  if [[ "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf '%s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  elif [[ "$tag" =~ ^v([0-9]+)$ ]]; then
    printf '%s 0 0\n' "${BASH_REMATCH[1]}"
  else
    printf "::error::Tag '%s' is neither vX.Y.Z nor vN.\n" "$tag" >&2
    return 1
  fi
}

# Echo N for an integer tag vN.
integer_from_tag() {
  local tag="$1"
  if [[ "$tag" =~ ^v([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf "::error::Tag '%s' is not vN, as the integer scheme requires.\n" "$tag" >&2
    return 1
  fi
}

# The release PR title for a version.
release_title() {
  printf 'Release v%s\n' "$1"
}

# Echo the version a release PR title carries, or fail when the title does
# not match the scheme.
version_from_title() {
  local scheme="$1" title="$2"
  case "$scheme" in
    semver)
      if [[ "$title" =~ ^Release\ v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
      fi
      printf "::error::Release PR title '%s' does not match 'Release vX.Y.Z'.\n" "$title" >&2
      return 1
      ;;
    integer)
      if [[ "$title" =~ ^Release\ v([0-9]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
      fi
      printf "::error::Release PR title '%s' does not match 'Release vN'.\n" "$title" >&2
      return 1
      ;;
    *)
      unknown_scheme "$scheme"
      ;;
  esac
}

# The version a new release PR starts from: patch+1 (semver) or N+1
# (integer) of the last tag. Without a tag, semver starts at 0.1.0 and
# integer at 1.
default_next_version() {
  local scheme="$1" last_tag="$2"
  local parts major minor patch n
  case "$scheme" in
    semver)
      if [ -z "$last_tag" ]; then
        printf '0.1.0\n'
        return 0
      fi
      parts=$(semver_from_tag "$last_tag") || return 1
      read -r major minor patch <<<"$parts"
      printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
      ;;
    integer)
      if [ -z "$last_tag" ]; then
        printf '1\n'
        return 0
      fi
      n=$(integer_from_tag "$last_tag") || return 1
      printf '%s\n' "$((n + 1))"
      ;;
    *)
      unknown_scheme "$scheme"
      ;;
  esac
}

# Succeed when going from last_tag to version is one allowed step. Without
# a tag, the baseline is v0.0.0 (semver) or v0 (integer).
check_transition() {
  local scheme="$1" last_tag="$2" version="$3"
  case "$scheme" in
    semver) check_semver_transition "${last_tag:-v0.0.0}" "$version" ;;
    integer) check_integer_transition "${last_tag:-v0}" "$version" ;;
    *) unknown_scheme "$scheme" ;;
  esac
}

check_semver_transition() {
  local base_tag="$1" version="$2"
  local parts cur_major cur_minor cur_patch new_major new_minor new_patch

  if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf "::error::Version '%s' is not X.Y.Z.\n" "$version" >&2
    return 1
  fi
  new_major="${BASH_REMATCH[1]}"
  new_minor="${BASH_REMATCH[2]}"
  new_patch="${BASH_REMATCH[3]}"

  parts=$(semver_from_tag "$base_tag") || return 1
  read -r cur_major cur_minor cur_patch <<<"$parts"

  if [ "$new_major" -eq "$cur_major" ] && [ "$new_minor" -eq "$cur_minor" ] &&
    [ "$new_patch" -eq "$((cur_patch + 1))" ]; then
    return 0
  fi
  if [ "$new_major" -eq "$cur_major" ] && [ "$new_minor" -eq "$((cur_minor + 1))" ] &&
    [ "$new_patch" -eq 0 ]; then
    return 0
  fi
  if [ "$new_major" -eq "$((cur_major + 1))" ] && [ "$new_minor" -eq 0 ] &&
    [ "$new_patch" -eq 0 ]; then
    return 0
  fi

  printf '::error::Disallowed version transition %s -> v%s. Only patch+1, minor+1 (with patch=0), or major+1 (with minor=0 and patch=0) are accepted.\n' \
    "$base_tag" "$version" >&2
  return 1
}

check_integer_transition() {
  local base_tag="$1" version="$2"
  local current

  if [[ ! "$version" =~ ^[0-9]+$ ]]; then
    printf "::error::Version '%s' is not an integer.\n" "$version" >&2
    return 1
  fi
  current=$(integer_from_tag "$base_tag") || return 1

  if [ "$version" -eq "$((current + 1))" ]; then
    return 0
  fi
  printf '::error::Disallowed version transition %s -> v%s. Only v%s is accepted.\n' \
    "$base_tag" "$version" "$((current + 1))" >&2
  return 1
}

unknown_scheme() {
  printf "::error::Unknown version scheme '%s'; expected 'semver' or 'integer'.\n" "$1" >&2
  return 1
}
