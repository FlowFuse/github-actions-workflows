# github-actions-workflows

General purpose reusable GitHub Action workflows and composite actions.

## Versioning and Release Process

Each reusable workflow and composite action in this repository is versioned and
released **independently** using [Release Please](https://github.com/googleapis/release-please).
The next version of each component is determined automatically from the
[Conventional Commits](https://www.conventionalcommits.org/) in pull request
titles that touched the component's files.

### Components

1.  The `Prepare release` GitHub Action workflow
    (`.github/workflows/release-please.yaml`):

    *   Runs `release-please-action` on every push to `main`. Release Please
        analyzes commit messages since the last release and groups pending
        version bumps into a single, rolling release pull request.
    *   The release PR lists one entry per component that has unreleased
        changes, each with its proposed new version and changelog excerpt.
    *   Merging the release PR creates the exact version tag for each
        released component (e.g. `build_container_image/v1.2.3`) and writes
        the aggregated entries into the repo-root `CHANGELOG.md`.
    *   After the exact tags are created, the same workflow fast-forwards
        the per-component **floating tags** - the major float
        `<component>/vX` and the minor float `<component>/vX.Y` - so they
        point at the same commit. Consumers pinned to a float automatically
        pick up the new release on their next run.

2.  The `Lint Pull Request Title` GitHub Action workflow
    (`.github/workflows/lint-pr-title.yaml`):

    *   Runs on every pull request and uses the
        `amannn/action-semantic-pull-request` action to validate that the
        pull request title follows the Conventional Commits format.
    *   This repository squash-merges all pull requests, so the PR title
        becomes the squash commit's subject line. The lint gate therefore
        ensures that Release Please can parse every commit merged into
        `main`.

### Pull Request Title Format

The Conventional Commits preset expects pull request titles to be in the
following format:

    <type>(<scope>): <subject>

*   Type: Describes the category of the commit. Examples include:
    *   `feat`: A new feature (triggers a minor version bump).
    *   `fix`: A bug fix (triggers a patch version bump).
    *   `perf`: A code change that improves performance (triggers a patch
        version bump).
    *   `refactor`: A code change that neither fixes a bug nor adds a
        feature (triggers a patch version bump unless it is a
        BREAKING CHANGE).
    *   `docs`: Documentation-only changes.
    *   `chore`: Routine maintenance (e.g. CI tweaks, dependency bumps).
*   Scope: An optional part that provides additional context about what
    was changed (e.g. module, component).
*   Subject: A brief description of the changes.

A commit whose files fall within a component's tracked paths always
produces at least a patch bump for that component, regardless of type.
Types like `chore` and `docs` are hidden from the visible `CHANGELOG.md`
but still participate in version calculation.

### Handling Breaking Changes

To indicate a breaking change, the exclamation mark `!` should be used
immediately after the type (or type and scope):

*   `feat!:`
*   `fix!:`
*   `refactor!:`

A breaking commit bumps the affected components to a new major version.
Consumers pinned to the previous major float (e.g.
`@build_container_image/v1`) stay frozen on the old major line — picking
up the new major requires re-pinning to the new float explicitly.

### Tag Scheme

For every release, three tags are produced per affected component:

| Tag                    | Mutability                          | Points at                         |
|------------------------|-------------------------------------|-----------------------------------|
| `<component>/vX.Y.Z`   | immutable                           | The release commit                |
| `<component>/vX.Y`     | moves on patch releases             | Latest patch of `vX.Y.x`          |
| `<component>/vX`       | moves on any non-breaking release   | Latest non-breaking of `vX.x.y`   |

Consumers reference a component by one of these tags:

```yaml
# Major float — auto-updates on every non-breaking release (recommended):
uses: FlowFuse/github-actions-workflows/.github/workflows/build_container_image.yml@build_container_image/v1

# Minor float — auto-updates only on patches:
uses: FlowFuse/github-actions-workflows/.github/workflows/build_container_image.yml@build_container_image/v1.2

# Exact pin — never moves:
uses: FlowFuse/github-actions-workflows/.github/workflows/build_container_image.yml@build_container_image/v1.2.3

# Composite actions use the same pattern:
uses: FlowFuse/github-actions-workflows/actions/npm_test@npm_test/v1
```
