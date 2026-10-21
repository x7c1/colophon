#!/usr/bin/env bash
set -euo pipefail

# Write a release version into a GNOME Shell extension's metadata.json.
#
# Usage:
#   gnome-extension.sh <scheme> <version> <metadata.json>
#
# extensions.gnome.org requires `version` to be an integer that grows with
# every upload, so the two schemes write it differently:
#
#   integer — `version` becomes the release version itself.
#   semver  — `version-name` (shown to users by the Extensions app and
#             extensions.gnome.org) becomes X.Y.Z, and `version` becomes the
#             file's current value + 1.
#
# The release PR rebuilds its branch from main on every run, so "current
# value + 1" is always one more than the latest released integer.

main() {
  if [ "$#" -ne 3 ]; then
    echo "Usage: gnome-extension.sh <scheme> <version> <metadata.json>" >&2
    return 2
  fi

  local scheme="$1" version="$2" file="$3"
  local current updated

  if [ ! -f "$file" ]; then
    printf "::error::GNOME extension metadata '%s' does not exist.\n" "$file" >&2
    return 1
  fi

  current=$(jq -r '.version // 0' "$file")
  if [[ ! "$current" =~ ^[0-9]+$ ]]; then
    printf "::error::%s carries version '%s', which is not an integer.\n" "$file" "$current" >&2
    return 1
  fi

  case "$scheme" in
    integer)
      updated=$(jq --argjson v "$version" '.version = $v' "$file")
      ;;
    semver)
      updated=$(jq --arg name "$version" --argjson v "$((current + 1))" \
        '.version = $v | .["version-name"] = $name' "$file")
      ;;
    *)
      printf "::error::Unknown version scheme '%s'; expected 'semver' or 'integer'.\n" "$scheme" >&2
      return 1
      ;;
  esac

  printf '%s\n' "$updated" >"$file"
}

main "$@"
