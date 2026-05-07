# CLAUDE.md

Repo-specific gotchas for future sessions. The README explains *what* the action does and *why*; this file only captures things that are easy to break by accident.

## What this repo is

A composite GitHub Action published as `begoon/ghasha`. The whole action is `action.yml` (composite, single bash step). No build step, no `node_modules`, no `dist/`. Do not introduce a JS/Docker rewrite without an explicit user request.

## The action reads the event payload, not git — this is the point

Every value the action emits is derived from the `github.*` context and `GITHUB_*` env vars that the runner injects, not from `git rev-parse`. The README has a long section explaining why (synthetic merge commit on PR, detached HEAD, shallow clones, no checkout in some workflows, merge_group and tag corner cases). Do not "simplify" any of these to git calls — every individual derivation exists because the git equivalent gives the wrong answer or imposes a checkout dependency.

In particular:

- `pull_request.head.sha` (not `github.sha`) on `pull_request` and `pull_request_target`. `github.sha` on a PR is the synthetic merge commit; using it as an image tag or provenance ID is wrong and unstable.
- `github.ref_name` (not `${GITHUB_REF#refs/heads/}`) for branches/tags on push. The strip-prefix form silently leaves `refs/tags/...` intact on tag pushes — the original buggy behavior this action was created to replace.
- `merge_group.base_ref` for `BRANCH` on merge-queue runs. `GITHUB_REF` on merge_group is `refs/heads/gh-readonly-queue/<base>/pr-N-<sha>` and is not a useful identifier.

## Marketplace constraints

`action.yml` `name:` and `description:` are validated by GitHub Marketplace at publish time:

- `name:` must be unique across all GitHub users, orgs, and existing actions. Plain `ghasha` is taken — the current value `ghasha - SHA and BRANCH` is what we settled on. Keep a qualifier; do not revert to bare `ghasha`.
- `description:` must be < 125 characters. The current value is 93 chars. If you reword it, re-check the length.

If you edit either field, push and try the marketplace publish flow before assuming it's fine — the validation is only enforced there, not at action-runtime.

## Both `$GITHUB_ENV` and `$GITHUB_OUTPUT` are written

Each computed value is exported twice: as an env var (uppercase: `SHA`, `SHORT_SHA`, `BRANCH`, `IS_TAG`) and as a step output (lowercase). Callers may use either style and we should not force them onto one. Do not delete the env-var block "for simplicity" — every existing user reaches for `$SHA` first.

## `length` input is validated as a positive integer

The `length` input is interpolated into bash parameter expansion (`${SHA:0:$LENGTH}`). The regex check `^[1-9][0-9]*$` is not cosmetic — it's the boundary that keeps unsanitized workflow input out of the shell. If you relax it (allow zero, leading zeros, negative, hex), think about what `${SHA:0:$LENGTH}` does with that value before merging.

## Release procedure

1. Land changes on `main`.
2. Add a new section to `CHANGELOG.md` for the version you are about to cut (move items out of `[Unreleased]` if any). Update the link references at the bottom of `CHANGELOG.md`.
3. Commit the changelog: `git commit -m "changelog for vX.Y.Z"`, push.
4. `just release vX.Y.Z` — creates the immutable `vX.Y.Z` tag and re-points the floating `vX` major pointer.
5. Push: `git push origin vX.Y.Z && git push --force origin vX`.

The `--force` is correct **only** for the moving major pointer (`v1`). Never force-push immutable `vX.Y.Z` tags — pinned consumers rely on those being stable.

### Historical exception: v1.0.0

`v1.0.0` was force-moved during initial publish because the first commit failed marketplace validation (name + description). That happened pre-publish with no consumers and is not a precedent. Subsequent immutable tags must stay immutable.

## Editing the Justfile

`tag` is the low-level recipe (any `v`-prefixed name). `release` requires `vX.Y.Z` exactly and additionally moves `vX`. The format check in `release` uses a regex; if you loosen it (e.g. to allow pre-release suffixes like `-rc1`), make sure the major-pointer derivation `${version%%.*}` still produces a sensible value.
