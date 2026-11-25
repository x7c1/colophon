---
status: completed
pipeline_phase: null
plan: null
base_ref: null
perspectives: null
max_refine_rounds: 3
retries_remaining: 1
check_command: bash tests/run.sh && shellcheck -x scripts/*.sh scripts/lib/*.sh scripts/writers/*.sh tests/*.sh && actionlint
assignee: null
branch: task/1125-1701-open-the-release-pr-as-a-draft
created_at: '2026-11-25T08:01:32Z'
updated_at: '2026-11-25T08:10:47Z'
---

# feat: keep the release PR a draft until someone decides to release

## Overview

Today the release PR opens ready for review, so an open release PR does not
tell whether anyone has decided to release it. Its validate check also fails
as long as the summary is the placeholder, even though nobody has decided to
release yet.

Make the draft state carry that decision:

- The release PR is a draft until a person decides to release. Marking it
  ready for review is that decision.
- Every refresh of the release PR (`scripts/create-release-pr.sh`, run on a
  push to the default branch, a title edit, or `workflow_dispatch`) leaves it
  a draft. A new PR is opened with `gh pr create --draft`. An open release PR
  that is ready for review is converted back to a draft with
  `gh pr ready <number> --undo`, because the decision was made on content the
  refresh has replaced. Convert it **before** the force push, so the
  `synchronize` event of the push already sees a draft.
- While the release PR is a draft, the checks do not judge it:
  - `validate-release-pr.yml` passes without checking the title and summary
    when `github.event.pull_request.draft` is true (like the existing skip for
    PRs that are not release PRs: the job succeeds, so it can stay a required
    check). An unedited summary on a draft is not an error.
  - Callers skip their own CI jobs on a draft release PR. colophon cannot do
    this for them, so `docs/usage.md` shows how: a job condition that skips
    when the PR is a draft and carries the `release` label, and
    `ready_for_review` added to the `pull_request` types of both the validate
    workflow and CI, so that marking the PR ready runs everything on it. Other
    draft PRs are not affected. An aggregate job (such as `all-green`) that
    accepts `skipped` keeps passing.
- Apply the same to colophon's own workflows: `self-validate.yml` adds
  `ready_for_review`, and `ci.yml` skips `test` and `lint` on a draft release
  PR and runs them on `ready_for_review`.

Update `docs/usage.md` and `README.md` wherever they describe the flow:

- "How a release goes": the PR opens as a draft; mark it ready for review when
  you decide to release; any refresh turns it back into a draft, so decide
  again on the new content.
- The caller examples and the setup list: `ready_for_review` in the trigger
  types, and the CI skip for a draft release PR.
- "Tokens": with `GITHUB_TOKEN`, marking the PR ready for review is done by a
  person, so it starts CI and the validate check; replace the advice to close
  and reopen the PR.
- Draft PRs need a public repository or a plan that supports them; say so
  where the requirements are listed.

## Acceptance criteria

### Automated (pipeline-verified)

- [x] `tests/create-release-pr.test.sh`: when no release PR is open, the script calls `gh pr create` with `--draft`
- [x] `tests/create-release-pr.test.sh`: when an open release PR is ready for review, the script converts it to a draft with `gh pr ready <number> --undo` before it pushes the branch; when the open release PR is already a draft, it does not call `gh pr ready`
- [x] `tests/validate-release-pr.test.sh` or a workflow-level test: the validate workflow skips the title and summary check on a draft release PR and still runs it on a release PR that is ready for review
- [x] `self-validate.yml` and `ci.yml` list `ready_for_review` in their `pull_request` types, and the jobs of `ci.yml` other than `all-green` skip on a draft PR labelled `release`
- [x] shellcheck and actionlint pass

### Before merge (verified outside the check command)

- [x] `docs/usage.md` and `README.md` describe the draft flow, the conversion back to a draft on refresh, the caller-side CI skip with `ready_for_review`, the updated Tokens advice, and the draft PR requirement, with no remaining text that says the release PR opens ready for review or that tells the reader to close and reopen it
