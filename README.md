# ghasha

A small composite GitHub Action that computes commit and ref identifiers and
exposes them as environment variables and step outputs so downstream steps
can reference them uniformly across event types.

## Outputs

| Name        | Value                                                                                     |
| ----------- | ----------------------------------------------------------------------------------------- |
| `SHA`       | `github.event.pull_request.head.sha` on `pull_request`/`pull_request_target`; `github.sha` otherwise |
| `SHORT_SHA` | first `length` characters of `SHA` (default `8`)                                          |
| `BRANCH`    | branch name on push/PR; tag name on tag push; target branch on `merge_group`              |
| `IS_TAG`    | `"true"` when the workflow is running on a tag ref, otherwise `"false"`                   |

All four are written to both `$GITHUB_ENV` (env vars for later steps) and
`$GITHUB_OUTPUT` (step outputs).

## Inputs

| Name     | Default | Description                                              |
| -------- | ------- | -------------------------------------------------------- |
| `length` | `8`     | Number of characters to keep in `SHORT_SHA`. Positive integer. |

## Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: ghasha
        uses: begoon/ghasha@v1
        # with:
        #   length: 12

      - name: use env vars
        run: echo "sha=$SHA short=$SHORT_SHA branch=$BRANCH is_tag=$IS_TAG"

      - name: use step outputs
        run: |
          echo "sha=${{ steps.ghasha.outputs.sha }}"
          echo "short_sha=${{ steps.ghasha.outputs.short_sha }}"
          echo "branch=${{ steps.ghasha.outputs.branch }}"
          echo "is_tag=${{ steps.ghasha.outputs.is_tag }}"
```

## Event matrix

| Event                                | `SHA`                                  | `BRANCH`                                | `IS_TAG` |
| ------------------------------------ | -------------------------------------- | --------------------------------------- | -------- |
| `push` (branch)                      | `github.sha`                           | branch name (e.g. `main`)               | `false`  |
| `push` (tag)                         | `github.sha`                           | tag name (e.g. `v1.2.3`)                | `true`   |
| `pull_request` / `pull_request_target` | `pull_request.head.sha`              | source branch (`GITHUB_HEAD_REF`)       | `false`  |
| `merge_group`                        | `github.sha` (queue merge commit)      | target branch (queue's `base_ref`)      | `false`  |
| `workflow_dispatch`, `schedule`, …   | `github.sha`                           | `github.ref_name`                       | per ref  |

The key correctness point: on `pull_request`, `github.sha` is the synthetic
merge commit, not the PR head. `ghasha` returns the PR head, which is
usually what you want for image tags, traceability, and provenance.

## Why not just use `git` on the checkout?

A reasonable first instinct is to skip an action entirely and run something
like `git rev-parse HEAD` and `git rev-parse --abbrev-ref HEAD` in a step.
That doesn't actually give you what you want on GitHub Actions:

- **PR runs check out a synthetic merge commit, not the PR head.** On
  `pull_request`, `actions/checkout` checks out a temporary merge commit of
  the PR head into the base branch. `git rev-parse HEAD` returns *that*
  merge SHA — not the commit the contributor pushed. It also changes every
  time the base branch moves, so it is useless as a stable identifier for
  image tags, traceability, or provenance. `pull_request.head.sha` is the
  stable PR-head value, and only the event payload has it.
- **HEAD is detached, so the branch name isn't recoverable from git.**
  `actions/checkout` checks out a SHA, leaving you on a detached HEAD.
  `git rev-parse --abbrev-ref HEAD` returns the literal string `HEAD`, and
  `git branch --show-current` returns empty. The branch name lives in
  `GITHUB_HEAD_REF` / `GITHUB_REF` / `github.ref_name`, not in git's local
  state.
- **`merge_group` is the same story.** The queue creates a synthetic ref
  (`refs/heads/gh-readonly-queue/<base>/pr-N-<sha>`) and checks out the
  resulting merge commit. `git` can't tell you which branch the queue is
  targeting; `github.event.merge_group.base_ref` can.
- **Tag pushes look like detached HEAD too.** `git` won't tell you the tag
  name unless you run `git describe --exact-match`, which fails on
  unannotated tags and requires `fetch-depth: 0`. `github.ref_name` just
  has it.
- **Requires a checkout you may not need.** Many workflows (linting on
  metadata, label/comment automation, deployment of a prebuilt artifact)
  don't otherwise need the source tree. `ghasha` reads the event context,
  so it works without `actions/checkout` and without a network round-trip
  to clone.
- **Shallow clones bite the git-based fallbacks.** Even when `git` would
  technically work, the default `fetch-depth: 1` breaks `git describe`,
  `git log`, and any lookup that needs more than the tip commit. The event
  context has no such dependency.

In short: the values are already in the event payload and the
`GITHUB_*` env vars that the runner injects. Reading them is correct,
fast, and free of checkout assumptions; deriving them from `git` is a
reconstruction that loses information the runner already has.

## Notes

- `BRANCH` on a tag push intentionally returns the tag name (matches
  `github.ref_name`) rather than empty, so it can be used directly as an
  image tag. Use `IS_TAG` to disambiguate when it matters.
- `SHORT_SHA` is computed by truncation, not `git rev-parse`. No checkout
  required.
