#!/usr/bin/env bash
set -euo pipefail

# Hold a release PR to its title and summary rules.
#
# Usage:
#   validate-release-pr.sh <scheme> <title> <body> <last_tag>
#
# The title must carry a version one allowed step from last_tag (see
# lib/version.sh), and the body must carry a hand-written summary above the
# changelog marker (see lib/summary.sh): the summary is what the release
# publishes.
#
# Exit codes:
#   0 — the PR is a valid release PR
#   1 — it is not (`::error::` lines say why)
#   2 — usage error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/version.sh
source "${SCRIPT_DIR}/lib/version.sh"
# shellcheck source=scripts/lib/summary.sh
source "${SCRIPT_DIR}/lib/summary.sh"

main() {
  if [ "$#" -ne 4 ]; then
    echo "Usage: validate-release-pr.sh <scheme> <title> <body> <last_tag>" >&2
    return 2
  fi

  local scheme="$1" title="$2" body="$3" last_tag="$4"
  local version status=0

  if version=$(version_from_title "$scheme" "$title"); then
    if check_transition "$scheme" "$last_tag" "$version"; then
      echo "OK: ${last_tag:-no tag} -> v${version}"
    else
      status=1
    fi
  else
    status=1
  fi

  if summary_is_unwritten "$(summary_region "$body")"; then
    printf "::error::The release PR has no release summary. Write it above the '%s' marker in the PR body and delete the '%s' comment: that text becomes the GitHub Release body.\n" \
      "$(changelog_marker)" "$(summary_sentinel)"
    status=1
  else
    echo "OK: the release PR carries a summary."
  fi

  return "$status"
}

main "$@"
