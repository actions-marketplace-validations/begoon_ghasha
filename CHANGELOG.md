# Changelog

All notable changes to this action are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-07

### Added

- Initial release.
- Composite action that computes `SHA`, `SHORT_SHA`, `BRANCH`, and `IS_TAG`, exposed both as `$GITHUB_ENV` env vars and step outputs.
- Event-aware `SHA` resolution: `pull_request.head.sha` on `pull_request` and `pull_request_target` (avoiding the synthetic merge commit that `github.sha` returns on PRs); `github.sha` elsewhere.
- Event-aware `BRANCH` resolution: `GITHUB_HEAD_REF` on PR events; `merge_group.base_ref` (target branch) on merge-queue runs; `github.ref_name` (handles both branches and tags) elsewhere.
- `length` input to control `SHORT_SHA` truncation (default `8`), validated as a positive integer.
- `tag` and `release` recipes in the `Justfile` for creating `v`-prefixed annotated tags and bumping the `vX` major pointer.

[Unreleased]: https://github.com/begoon/ghasha/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/begoon/ghasha/releases/tag/v1.0.0
