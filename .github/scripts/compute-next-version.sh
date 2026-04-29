#!/usr/bin/env bash
#
# Decide whether the given component needs a new semver tag.
#
# Reads:
#   COMPONENT     - component name (e.g. reusable-workflow-1)
#   INCLUDE_PATH  - path filter passed to `git log -- <path>`
#
# Writes (when GITHUB_OUTPUT is set, i.e. running under GitHub Actions):
#   release=true|false
#   tag=<component>/v<new-version>   (only when release=true)
#   version=<new-version>            (only when release=true)

set -euo pipefail

: "${COMPONENT:?COMPONENT must be set}"
: "${INCLUDE_PATH:?INCLUDE_PATH must be set}"

if [ ! -e "$INCLUDE_PATH" ]; then
  echo "INCLUDE_PATH '$INCLUDE_PATH' does not exist" >&2
  exit 1
fi

emit() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1" >> "$GITHUB_OUTPUT"
  fi
}

LATEST_TAG=$(git tag -l "${COMPONENT}/v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -n1 || true)
if [ -z "$LATEST_TAG" ]; then
  CURRENT_VER="0.0.0"
  RANGE="HEAD"
  BUMP="minor"
  echo "No previous tag found for ${COMPONENT}, treating as new component (initial release will be at least 0.1.0)"
else
  CURRENT_VER="${LATEST_TAG#"${COMPONENT}"/v}"
  RANGE="${LATEST_TAG}..HEAD"
  echo "Current version: ${CURRENT_VER} (from tag ${LATEST_TAG})"
fi

mapfile -t SUBJECTS < <(git log "$RANGE" --first-parent --format='%s' -- "$INCLUDE_PATH")
echo "Found ${#SUBJECTS[@]} commits affecting ${INCLUDE_PATH} since ${LATEST_TAG:-<initial>}"

BUMP="${BUMP:-}"
for subject in "${SUBJECTS[@]}"; do
  [ -z "$subject" ] && continue
  echo "  - ${subject}"
  if echo "$subject" | grep -qE '^[a-zA-Z]+(\([^)]+\))?!:'; then
    echo "  → BREAKING CHANGE found in: ${subject}"
    echo "  → Major bump triggered by: ${subject}"
    BUMP="major"
    break
  fi
  TYPE=$(echo "$subject" | sed -E 's/^([a-zA-Z]+).*/\1/')
  case "$TYPE" in
    feat)
      if [ "$BUMP" != "minor" ]; then
        echo "  → Minor bump triggered by: ${subject}"
        BUMP="minor"
      fi
      ;;
    fix|perf|chore|docs|refactor|revert)
      [ -z "$BUMP" ] && BUMP="patch"
      ;;
  esac
done

if [ -z "$BUMP" ]; then
  echo "No release needed for ${COMPONENT} (latest=${LATEST_TAG})"
  emit "release=false"
  exit 0
fi

IFS='.' read -r MAJ MIN PAT <<< "$CURRENT_VER"
case "$BUMP" in
  major) NEW_VER="$((MAJ+1)).0.0" ;;
  minor) NEW_VER="${MAJ}.$((MIN+1)).0" ;;
  patch) NEW_VER="${MAJ}.${MIN}.$((PAT+1))" ;;
esac
NEW_TAG="${COMPONENT}/v${NEW_VER}"
echo "Will release ${NEW_TAG} from ${LATEST_TAG:-<initial>} (bump=${BUMP})"
emit "release=true"
emit "tag=${NEW_TAG}"
emit "version=${NEW_VER}"
