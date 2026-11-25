#!/usr/bin/env bash
set -euo pipefail

# Decide whether the validate workflow checks a PR's title and summary.
#
# Usage:
#   release-pr-gate.sh <title> <draft>
#
# <draft> is the PR's draft flag ("true" or "false"). Prints `skip=true` or
# `skip=false` for $GITHUB_OUTPUT, and why on stderr. The check is skipped,
# and the job passes, for a PR that is not a release PR, and for a release PR
# that is still a draft: nobody has decided to release it yet, so an
# unwritten summary is not an error.
#
# Exit codes:
#   0 — decided
#   2 — usage error

main() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: release-pr-gate.sh <title> <draft>" >&2
    return 2
  fi

  local title="$1" draft="$2"

  if [[ "$title" != "Release v"* ]]; then
    echo "Not a release PR; nothing to check." >&2
    echo "skip=true"
  elif [ "$draft" = "true" ]; then
    echo "The release PR is a draft; it is checked once marked ready for review." >&2
    echo "skip=true"
  else
    echo "skip=false"
  fi
}

main "$@"
