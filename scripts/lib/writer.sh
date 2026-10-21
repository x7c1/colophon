#!/usr/bin/env bash
# Write the release version into the caller's files.
#
# Environment variables:
#   COLOPHON_WRITER          - none | gnome-extension | command
#   COLOPHON_VERSION_FILE    - the file gnome-extension writes
#   COLOPHON_VERSION_COMMAND - the shell command `command` runs, with the
#                              version in COLOPHON_VERSION

WRITERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../writers" && pwd)"

apply_version() {
  local scheme="$1" version="$2"

  case "${COLOPHON_WRITER:-none}" in
    none) ;;
    gnome-extension)
      if [ -z "${COLOPHON_VERSION_FILE:-}" ]; then
        echo "::error::The gnome-extension writer needs version-file (the extension's metadata.json)." >&2
        return 1
      fi
      "${WRITERS_DIR}/gnome-extension.sh" "$scheme" "$version" "$COLOPHON_VERSION_FILE"
      ;;
    command)
      if [ -z "${COLOPHON_VERSION_COMMAND:-}" ]; then
        echo "::error::The command writer needs version-command." >&2
        return 1
      fi
      COLOPHON_VERSION="$version" bash -euo pipefail -c "$COLOPHON_VERSION_COMMAND"
      ;;
    *)
      printf "::error::Unknown version writer '%s'; expected none, gnome-extension, or command.\n" "$COLOPHON_WRITER" >&2
      return 1
      ;;
  esac
}
