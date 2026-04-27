# github-actions-workflows

General purpose reusable GitHub Action workflows and composite actions.

## Versioning and Release Process

Each reusable workflow and composite action in this repository is versioned and released **independently** using [Release Please](https://github.com/googleapis/release-please). The next version of each component is determined automatically from the [Conventional Commits](https://www.conventionalcommits.org/) in pull request titles that touched the component's files.

### Components

1.  The `Prepare release` GitHub Action workflow (`.github/workflows/release-please.yaml`):

    *   Runs `release-please-action` on every push to `main`. Release Please analyzes commit messages since the last release and groups pending version bumps into a single, rolling release pull request.
    *   The release PR lists one entry per component that has unreleased changes, each with its proposed new version and changelog excerpt.
    *   Merging the release PR creates the exact version tag for each released component (e.g. `build_container_image/v1.2.3`) and writes the aggregated entries into the repo-root `CHANGELOG.md`.
    *   After the exact tags are created, the same workflow fast-forwards the per-component **floating tags** - the major float `<component>/vX` and the minor float `<component>/vX.Y` - so they point at the same commit. Consumers pinned to a float automatically pick up the new release on their next run.

2.  The `Lint Pull Request Title` GitHub Action workflow (`.github/workflows/lint-pr-title.yaml`):

    *   Runs on every pull request and uses the `amannn/action-semantic-pull-request` action to validate that the pull request title follows the Conventional Commits format.
    *   This repository squash-merges all pull requests, so the PR title becomes the squash commit's subject line. The lint gate therefore ensures that Release Please can parse every commit merged into `main`.

### Pull Request Title Format

The Conventional Commits preset expects pull request titles to be in the following format:

    <type>(<scope>): <subject>

*   Type: Describes the category of the commit. Examples include:
    *   `feat`: A new feature (triggers a minor version bump).
    *   `fix`: A bug fix (triggers a patch version bump).
    *   `perf`: A code change that improves performance (triggers a patch version bump).
    *   `refactor`: A code change that neither fixes a bug nor adds a feature (triggers a patch version bump unless it is a BREAKING CHANGE).
    *   `docs`: Documentation-only changes.
    *   `chore`: Routine maintenance (e.g. CI tweaks, dependency bumps).
*   Scope: An optional part that provides additional context about what was changed (e.g. module, component).
*   Subject: A brief description of the changes.

A commit whose files fall within a component's tracked paths always produces at least a patch bump for that component, regardless of type. Types like `chore` and `docs` are hidden from the visible `CHANGELOG.md` but still participate in version calculation.

### Handling Breaking Changes

To indicate a breaking change, the exclamation mark `!` should be used immediately after the type (or type and scope):

*   `feat!:`
*   `fix!:`
*   `refactor!:`

A breaking commit bumps the affected components to a new major version. Consumers pinned to the previous major float (e.g. `@build_container_image/v1`) stay frozen on the old major line — picking up the new major requires re-pinning to the new float explicitly.

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

### Adding a New Reusable Workflow or Composite Action

When introducing a new component, it must be registered with Release Please so that it is versioned and tagged independently like the existing ones.

1.  **Create the workflow or action file.**

    *   Reusable workflow: place the YAML file at `.github/workflows/<name>.yml`.
    *   Composite action: create the directory `actions/<name>/` and add its `action.yml` (plus any supporting files).
    *   `<name>` must be unique across **all** workflows and actions — the two share a flat tag namespace.

2.  **Register the component in `.github/release-please-config.json`** by adding a new entry under `packages`.

    *   For a reusable workflow:

        ```json
        ".github/workflows/<name>": {
          "component": "<name>",
          "include-paths": [".github/workflows/<name>.yml"]
        }
        ```

        The package key is a virtual path (no directory is created on disk); `include-paths` scopes change detection to the single YAML file.

    *   For a composite action:

        ```json
        "actions/<name>": {
          "component": "<name>"
        }
        ```

        The package key is the action's real directory; `include-paths` is not needed because any file under that directory is attributed to the component.

3.  **Seed the initial version in `.github/release-please-manifest.json`** using the same key chosen in the previous step:

    ```json
    "<path-used-above>": "1.0.0"
    ```

4.  **Open the pull request with a Conventional Commit title**, for example `feat: add <name> reusable workflow`.

5.  **After merging the pull request, bootstrap the initial tags** for the new component. They must exist before consumers can reference it and before Release Please runs cleanly for the new entry:

    ```bash
    git fetch origin main
    SHA=$(git rev-parse origin/main)
    NAME="<name>"
    git tag "${NAME}/v1.0.0" "${SHA}"
    git tag "${NAME}/v1.0"   "${SHA}"
    git tag "${NAME}/v1"     "${SHA}"
    git push origin "${NAME}/v1.0.0" "${NAME}/v1.0" "${NAME}/v1"
    ```

    > If Release Please happens to run between the merge and this bootstrap (it triggers on every push to `main`), it may open a stray release pull request proposing an inflated first version for the new component, because it has no tag to use as a baseline. Simply close that pull request — the next Release Please run, once the bootstrap tags exist, will be a no-op for the new component.
