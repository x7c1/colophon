# Colophon

Reusable GitHub Actions workflows that open release PRs, check their version, and publish tagged releases.

## Features

- **Release PR on every push** — keeps a `Release vX.Y.Z` PR up to date with `main`, with a changelog generated from Conventional Commits
- **Version in the title** — bumps the patch by default; edit the PR title to release a minor or major instead
- **Title check** — a required check rejects titles that skip a version or break the format
- **Tagged releases** — tags the commit that passed CI and publishes the release notes written in the PR
- **Pluggable version files** — writes the version into a GNOME Shell extension's `metadata.json`, or into any file through a command of your own
- **Semver or integer versions** — `v1.2.3` or `v8`, chosen per repository

## Status

Under development toward v0.1. Interfaces may change without notice until v1.0.

## Documentation

- [Usage](docs/usage.md) — calling the workflows, version schemes and writers, repository settings, and tokens

## License

[MIT](LICENSE)
