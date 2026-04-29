# github-actions-workflows

General purpose reusable GitHub Action workflows and composite actions.

## Versioning and Release Process

Each reusable workflow and composite action in this repository is versioned and released **independently**. The next version of each component is determined automatically from the [Conventional Commits](https://www.conventionalcommits.org/) in commit subjects on `main` that touched the component's files.

### Components

1.  The `Release workflows/actions` GitHub Action workflow (`.github/workflows/release.yaml`):

    *   Runs on every push to `main` (and can be triggered manually via `workflow_dispatch`).
    *   Uses a matrix that lists every released component and its tracked path. Each matrix job runs independently, so a release of one component never blocks another.
    *   For each component, it invokes `.github/scripts/compute-next-version.sh`, which:
        *   Validates that the configured path exists.
        *   Looks up the latest exact tag (`<component>/vX.Y.Z`) for that component.
        *   Walks `git log --first-parent` between that tag and `HEAD`, restricted to the component's path, and inspects each commit subject.
        *   Picks the bump level from the highest-priority Conventional Commit type seen (breaking > feat > fix/chore/etc.).
    *   When a release is needed, the workflow creates the immutable `<component>/vX.Y.Z` tag and force-updates the floating `<component>/vX` and `<component>/vX.Y` tags so consumers pinned to a float pick up the new release on their next run.

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
    *   `revert`: Reverts a previous change (triggers a patch version bump).
    *   `docs`: Documentation-only changes (triggers a patch version bump).
    *   `chore`: Routine maintenance, e.g. CI tweaks, dependency bumps (triggers a patch version bump).
*   Scope: An optional part that provides additional context about what was changed (e.g. module, component).
*   Subject: A brief description of the changes.

A commit whose files fall within a component's tracked path always produces at least a patch bump for that component, regardless of type. Commit subjects that don't match a recognised Conventional Commit type are ignored for version calculation.

### Handling Breaking Changes

To indicate a breaking change, the exclamation mark `!` should be used immediately after the type (or type and scope):

*   `feat!:`
*   `fix!:`
*   `refactor!:`

A breaking commit bumps the affected component to a new major version. Consumers pinned to the previous major float (e.g. `@build_container_image/v1`) stay frozen on the old major line — picking up the new major requires re-pinning to the new float explicitly.

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

1.  **Create the workflow or action file.**

    *   Reusable workflow: place the YAML file at `.github/workflows/<name>.yml`.
    *   Composite action: create the directory `actions/<name>/` and add its `action.yml` (plus any supporting files).
    *   `<name>` must be unique across **all** workflows and actions — the two share a flat tag namespace.

2.  **Register the component in `.github/workflows/release.yaml`** by adding a new entry to the `matrix.component` list:

    *   For a reusable workflow:

        ```yaml
        - { name: <name>, path: .github/workflows/<name>.yml }
        ```

    *   For a composite action:

        ```yaml
        - { name: <name>, path: actions/<name> }
        ```

    The `path` must point at a real file or directory in the repository — the release script fails fast if it does not exist.

3.  **Open the pull request with a Conventional Commit title**, for example `feat: add <name> reusable workflow`.

4.  **After the pull request is merged**, the next run of the release workflow on `main` will automatically tag the new component at `<name>/v0.1.0` (and create the matching `v0` and `v0.1` floats). No manual bootstrap of initial tags is required.

    > A new component with no Conventional Commit history yet is still released as `v0.1.0` on first run, so consumers can start referencing it immediately.
