#!/usr/bin/env bash
set -uo pipefail

# Run every tests/*.test.sh and fail when any of them fails.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0

for test in "${TESTS_DIR}"/*.test.sh; do
  printf '# %s\n' "$(basename "$test")"
  if ! bash "$test"; then
    status=1
  fi
done

exit "$status"
