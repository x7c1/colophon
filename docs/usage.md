# Usage

Colophon is four reusable workflows. A repository calls them from three small
workflows of its own and pins them by commit SHA.

| Workflow | Called on | Does |
|---|---|---|
| `release-pr.yml` | `push`, `pull_request` (`edited`), `workflow_dispatch` | Opens or refreshes the release PR |
| `validate-release-pr.yml` | `pull_request` | Checks the release PR's title and summary |
| `release-plan.yml` | `workflow_run` of CI | Decides whether the commit CI judged is a release |
| `release-publish.yml` | after `release-plan.yml` | Tags the commit and publishes the GitHub Release |

## How a release goes

1. Every push to the default branch opens or refreshes one PR titled
   `Release v<next>`, labelled `release`. Its branch is the default branch plus
   one commit that writes the version into your files.
2. The next version is the patch after the last tag. To release a minor or
   major instead, edit the PR title (`Release v0.3.4` → `Release v0.4.0`); the
   next refresh keeps it.
3. Write the release summary in the PR body, above the
   `<!-- changelog:auto -->` marker, and delete the
   `<!-- release-summary:todo -->` comment. The summary becomes the GitHub
   Release body; the changelog below the marker is regenerated on every
   refresh.
4. Squash-merge the PR. When CI passes on the merge commit, the commit is
   tagged `v<version>` and the GitHub Release is published.

## Version schemes

| `version-scheme` | Title and tag | Allowed next versions |
|---|---|---|
| `semver` | `Release v1.2.3`, `v1.2.3` | patch+1, minor+1 with patch 0, major+1 with minor and patch 0 |
| `integer` | `Release v8`, `v8` | N+1 only |

Without a tag, `semver` starts at `0.1.0` and `integer` at `1`. Under `semver`,
an earlier integer tag `vN` reads as `N.0.0`, so a repository that released
`v1`…`v7` can move to semver with `v8.0.0` (or `v7.0.1`).

## Version writers

The release PR's commit writes the version into your files with
`version-writer`:

| `version-writer` | Writes |
|---|---|
| `none` | Nothing (the commit is empty) |
| `gnome-extension` | `version-file`, a GNOME Shell extension's `metadata.json`. `integer` sets `version`; `semver` sets `version-name` to the version and adds one to `version`, which extensions.gnome.org requires to grow with every upload |
| `command` | Whatever `version-command` does. It runs in the repository root with the version in `COLOPHON_VERSION` |

## Calling the workflows

Replace `<sha>` with a colophon commit. Let Dependabot (`github-actions`)
propose updates.

```yaml
# .github/workflows/release-pr.yml
name: Release PR
on:
  push:
    branches: [main]
  pull_request:
    types: [edited]
  workflow_dispatch:
jobs:
  release-pr:
    permissions:
      contents: write
      pull-requests: write
    uses: x7c1/colophon/.github/workflows/release-pr.yml@<sha>
    with:
      version-scheme: semver
      version-writer: gnome-extension
      version-file: dist/metadata.json
```

```yaml
# .github/workflows/validate-release-pr.yml
name: Validate Release PR
on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
jobs:
  validate:
    permissions:
      contents: read
    uses: x7c1/colophon/.github/workflows/validate-release-pr.yml@<sha>
    with:
      version-scheme: semver
```

```yaml
# .github/workflows/release.yml
name: Release
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]
jobs:
  plan:
    permissions:
      contents: read
      pull-requests: read
    uses: x7c1/colophon/.github/workflows/release-plan.yml@<sha>
    with:
      version-scheme: semver

  # Optional: build release assets at the planned commit and upload them.
  build:
    needs: plan
    if: needs.plan.outputs.released == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<sha>
        with:
          ref: ${{ needs.plan.outputs.sha }}
      - run: make dist   # your build
      - uses: actions/upload-artifact@<sha>
        with:
          name: release-assets
          path: dist/*.zip

  publish:
    needs: [plan, build]
    if: needs.plan.outputs.released == 'true'
    permissions:
      contents: write
      pull-requests: write
    uses: x7c1/colophon/.github/workflows/release-publish.yml@<sha>
    with:
      tag: ${{ needs.plan.outputs.tag }}
      sha: ${{ needs.plan.outputs.sha }}
      pr-number: ${{ needs.plan.outputs.pr-number }}
      artifact-name: release-assets
```

`release-plan.yml` outputs `released`, `version`, `tag`, `sha`, and
`pr-number`.

## Repository settings

- Allow squash merge; the default commit title (the PR title) is how the
  release PR workflow recognizes a release landing and skips it
- Under Settings › Actions › General, allow GitHub Actions to create pull
  requests when the release PR is opened with `GITHUB_TOKEN`
- Make the `validate` job of the validate workflow a required check

## Tokens

By default the release PR is opened with `GITHUB_TOKEN`. GitHub does not start
other workflows for events caused by that token, so CI and the validate check
do not run on the release PR by themselves: close and reopen the PR before
merging to run them.

To have them run on every refresh, open the release PR as a GitHub App. The
workflow turns the App's private key into a token for the calling repository
only, valid for an hour, so there is no long-lived token to rotate.

1. Create a GitHub App on the account that owns the repositories (Settings ›
   Developer settings › GitHub Apps › New GitHub App):
   - Webhook: inactive
   - Repository permissions: Contents — Read and write, Pull requests — Read
     and write (Metadata — Read-only is added automatically)
   - Where can this GitHub App be installed: Only on this account
2. Note the App's Client ID and generate a private key.
3. Install the App on the repositories that release with colophon (Only
   select repositories).
4. In each repository, add the Client ID as the Actions variable
   `RELEASE_APP_CLIENT_ID` and the private key as the Actions secret
   `RELEASE_APP_PRIVATE_KEY`.
5. Pass them to the release PR workflow:

```yaml
    uses: x7c1/colophon/.github/workflows/release-pr.yml@<sha>
    with:
      version-scheme: semver
      app-client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}
    secrets:
      app-private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

A personal access token with contents and pull-requests write access works
too, passed as the `token` secret, but it has to be replaced when it expires.
