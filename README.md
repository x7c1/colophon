# Colophon

Reusable GitHub Actions workflows that open release PRs, check their version, and publish tagged releases.

## Features

- **Release PR on every push** — keeps a `Release vX.Y.Z` PR up to date with `main`, with a changelog generated from Conventional Commits
- **Draft until you decide** — the release PR stays a draft until you mark it ready for review, and every refresh turns it back into one; checks skip it while it is a draft (draft PRs need a public repository or a plan that supports them)
- **Version in the title** — bumps the patch by default; edit the PR title to release a minor or major instead
- **Title check** — a required check rejects titles that skip a version or break the format, once the release PR is ready for review
- **Tagged releases** — tags the commit that passed CI and publishes the release notes written in the PR
- **Pluggable version files** — writes the version into a GNOME Shell extension's `metadata.json`, or into any file through a command of your own
- **Semver or integer versions** — `v1.2.3` or `v8`, chosen per repository
- **GitHub App tokens** — opens the release PR as your GitHub App so workflows run on every refresh, with a short-lived token scoped to the repository

## Status

Under development toward v0.1. Interfaces may change without notice until v1.0.

## Documentation

- [Usage](docs/usage.md) — calling the workflows, version schemes and writers, repository settings, and tokens

## License

[MIT](LICENSE)
