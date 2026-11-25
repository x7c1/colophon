#!/usr/bin/env bash
set -uo pipefail

# Tests for scripts/create-release-pr.sh against a local bare remote and a
# fake `gh` that answers from files and records what it was asked to do.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/assert.sh
source "${TESTS_DIR}/assert.sh"

SCRIPT="${TESTS_DIR}/../scripts/create-release-pr.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- fake gh ----------------------------------------------------------------
#
# State lives in $FAKE: open-pr (number or empty), title, head, body, is-draft
# (true, false, or "fail" to make the read fail). Calls to `pr create` and
# `pr edit` are appended to $FAKE/calls with their body. `pr ready` calls and
# pushes to the remote (from its pre-receive hook) are appended to
# $FAKE/events in the order they happen.

FAKE="${WORK}/fake"
mkdir -p "${FAKE}/bin"
cat >"${FAKE}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
field() { cat "${FAKE}/$1" 2>/dev/null || true; }
case "$1 $2" in
  "repo view") echo "https://github.com/o/r" ;;
  "pr list") field open-pr ;;
  "label create") ;;
  "pr view")
    case "$*" in
      *"--json title"*) field title ;;
      *"--json headRefName"*) field head ;;
      *"--json body"*) field body ;;
      *"--json isDraft"*)
        if [ "$(field is-draft)" = fail ]; then
          echo "fake gh: cannot read isDraft" >&2
          exit 1
        fi
        field is-draft
        ;;
    esac
    ;;
  "pr ready")
    shift 2
    echo "ready $*" >>"${FAKE}/events"
    ;;
  "pr create" | "pr edit")
    shift 2
    body=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --title) echo "title=$2" >>"${FAKE}/calls"; shift 2 ;;
        --head) echo "head=$2" >>"${FAKE}/calls"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --draft) echo "draft" >>"${FAKE}/calls"; shift ;;
        *) shift ;;
      esac
    done
    printf '%s\n' "$body" >"${FAKE}/last-body"
    echo "called" >>"${FAKE}/calls"
    ;;
  *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "${FAKE}/bin/gh"
export FAKE PATH="${FAKE}/bin:${PATH}" GH_TOKEN=fake

# --- repository -------------------------------------------------------------

git init -q --bare "${WORK}/remote.git"
cat >"${WORK}/remote.git/hooks/pre-receive" <<'EOF'
#!/usr/bin/env bash
while read -r _old _new ref; do
  echo "push ${ref}" >>"${FAKE}/events"
done
EOF
chmod +x "${WORK}/remote.git/hooks/pre-receive"
git init -q -b main "${WORK}/repo"
cd "${WORK}/repo" || exit 1
git config user.name test
git config user.email test@example.com
git remote add origin "${WORK}/remote.git"
printf '{\n  "uuid": "x@y",\n  "version": 7\n}\n' >metadata.json
git add metadata.json
git commit -q -m "feat: first"
git tag v7
git commit -q --allow-empty -m "fix: second (#3)"
git push -q origin main --tags

run() {
  COLOPHON_SCHEME=semver COLOPHON_WRITER=gnome-extension COLOPHON_VERSION_FILE=metadata.json \
    bash "$SCRIPT" >"${WORK}/out" 2>&1
}

remote_metadata() {
  git --git-dir="${WORK}/remote.git" show "$1:metadata.json"
}

# --- no open release PR: open one -------------------------------------------

: >"${FAKE}/open-pr"
run
assert_eq "opens a PR" "0" "$?"
calls=$(cat "${FAKE}/calls")
assert_contains "title is the default next version" "$calls" "title=Release v7.0.1"
branch=$(sed -n 's/^head=//p' "${FAKE}/calls")
assert_contains "branch is a release branch" "$branch" "release/since-"
assert_contains "opens the PR as a draft" "$calls" "draft"
assert_eq "writes version-name on the branch" "7.0.1" "$(remote_metadata "$branch" | jq -r '."version-name"')"
assert_eq "bumps the integer on the branch" "8" "$(remote_metadata "$branch" | jq -r '.version')"
assert_eq "leaves main alone" "7" "$(remote_metadata main | jq -r '.version')"
body=$(cat "${FAKE}/last-body")
assert_contains "body has the placeholder" "$body" "<!-- release-summary:todo -->"
assert_contains "body has the changelog" "$body" "- fix: second ([#3](https://github.com/o/r/pull/3))"
assert_contains "body links the comparison" "$body" "compare/v7...${branch})"

# --- open PR promoted to 8.0.0 with a summary: keep both ---------------------

echo 42 >"${FAKE}/open-pr"
echo "Release v8.0.0" >"${FAKE}/title"
echo "$branch" >"${FAKE}/head"
printf '%s\n' '## Summary' '' 'Paid release.' '' '<!-- changelog:auto -->' '' 'old' >"${FAKE}/body"
echo false >"${FAKE}/is-draft"
: >"${FAKE}/calls"
git checkout -q main
git commit -q --allow-empty -m "feat: third"
git push -q origin main
: >"${FAKE}/events"
run
assert_eq "updates the PR" "0" "$?"
assert_eq "turns the ready PR back into a draft before the push" \
  "$(printf '%s\n' 'ready 42 --undo' "push refs/heads/${branch}")" "$(cat "${FAKE}/events")"
assert_not_contains "does not create another PR" "$(cat "${FAKE}/calls")" "head="
assert_eq "keeps the promoted version" "8.0.0" "$(remote_metadata "$branch" | jq -r '."version-name"')"
assert_eq "integer is main's + 1" "8" "$(remote_metadata "$branch" | jq -r '.version')"
body=$(cat "${FAKE}/last-body")
assert_contains "keeps the summary" "$body" "Paid release."
assert_contains "refreshes the changelog" "$body" "- feat: third"
assert_contains "separates the changelog from the link" "$body" "$(printf '\n\n## Changelog')"
assert_eq "branch is rebuilt on main" \
  "$(git rev-parse main)" "$(git --git-dir="${WORK}/remote.git" rev-parse "${branch}~1")"

# --- open PR already a draft: leave it ----------------------------------------

echo true >"${FAKE}/is-draft"
: >"${FAKE}/events"
run
assert_eq "updates the draft PR" "0" "$?"
assert_not_contains "does not call pr ready on a draft" "$(cat "${FAKE}/events")" "ready"

# --- draft state unreadable: stop before touching the PR ---------------------

echo fail >"${FAKE}/is-draft"
: >"${FAKE}/events"
: >"${FAKE}/calls"
run
assert_eq "fails when the draft state cannot be read" "1" "$?"
assert_eq "neither pushes nor edits" "" "$(cat "${FAKE}/events" "${FAKE}/calls")"
echo true >"${FAKE}/is-draft"

# --- a title that skips a version fails --------------------------------------

echo "Release v9.0.0" >"${FAKE}/title"
run
assert_eq "rejects a skipped version" "1" "$?"
assert_contains "says why" "$(cat "${WORK}/out")" "Disallowed version transition"

finish
