#!/usr/bin/env bash
# Assertions shared by the tests. Each test file sources this, makes its
# assertions, and ends with `finish`, which exits non-zero on any failure.

failures=0

pass() {
  printf 'ok   - %s\n' "$1"
}

fail() {
  printf 'FAIL - %s\n' "$1"
  printf '%s\n' "$2"
  failures=$((failures + 1))
}

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$name"
  else
    fail "$name" "  expected: $(printf '%q' "$expected")
  actual:   $(printf '%q' "$actual")"
  fi
}

# Run a command and compare its exit status.
assert_status() {
  local name="$1" expected="$2"
  shift 2
  local actual
  "$@" >/dev/null 2>&1
  actual=$?
  if [ "$expected" -eq "$actual" ]; then
    pass "$name"
  else
    fail "$name" "  expected exit ${expected}, got ${actual}: $*"
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "  $(printf '%q' "$needle") not found in $(printf '%q' "$haystack")"
  fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "  unexpectedly found $(printf '%q' "$needle") in $(printf '%q' "$haystack")"
  fi
}

finish() {
  if [ "$failures" -gt 0 ]; then
    printf '%d failure(s)\n' "$failures"
    exit 1
  fi
}
