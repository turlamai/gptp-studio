#!/usr/bin/env bash
# Fail a release before packaging if the VERSION file, the git tag and the
# product metadata disagree.
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-${GITHUB_REF_NAME:-}}"
if [[ -n "$TAG" ]]; then
  if [[ "$TAG" != v* ]]; then
    echo "error: release tag must start with v: $TAG" >&2
    exit 2
  fi
  TAG_VERSION="${TAG#v}"
  if [[ ! "$TAG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: release version must be x.y.z for desktop bundle metadata: $TAG_VERSION" >&2
    exit 2
  fi
fi

# The VERSION file is the single source of truth; every other declaration
# is checked against it. Without a tag argument the script still verifies
# the checked-in alignment (the form CI and release runs both use).
if [[ ! -f VERSION ]]; then
  echo "error: VERSION file is missing" >&2
  exit 2
fi
VERSION="$(tr -d '[:space:]' < VERSION)"
if [[ -z "$VERSION" ]]; then
  echo "error: VERSION file is empty" >&2
  exit 2
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION '$VERSION' is not x.y.z for desktop bundle metadata" >&2
  exit 2
fi

extract_define_string() {
  local file="$1"
  local name="$2"
  sed -nE "s/^\(define[[:space:]]+$name[[:space:]]+\"([^\"]+)\"\).*$/\1/p" "$file" | head -n 1
}

INFO_VERSION="$(extract_define_string info.rkt version)"
APP_VERSION="$(extract_define_string app/state.rkt app-version)"
RIVET_VERSION="$(sed -nE 's/.*\(version \. "([^"]+)"\).*/\1/p' rivet.rktd | head -n 1)"

fail=0
if [[ -n "${TAG_VERSION:-}" && "$TAG_VERSION" != "$VERSION" ]]; then
  echo "error: tag v$TAG_VERSION does not match VERSION $VERSION" >&2
  fail=1
fi
if [[ "$INFO_VERSION" != "$VERSION" ]]; then
  echo "error: info.rkt version=$INFO_VERSION but VERSION=$VERSION" >&2
  fail=1
fi
if [[ "$APP_VERSION" != "$VERSION" ]]; then
  echo "error: app/state.rkt app-version=$APP_VERSION but VERSION=$VERSION" >&2
  fail=1
fi
if [[ "$RIVET_VERSION" != "$VERSION" ]]; then
  echo "error: rivet.rktd version=$RIVET_VERSION but VERSION=$VERSION" >&2
  fail=1
fi
if ! grep -Eq "^##[[:space:]]+$VERSION([[:space:]]|$)" CHANGELOG.md; then
  echo "error: CHANGELOG.md has no release heading for $VERSION" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "release metadata is inconsistent; update versions/changelog before tagging" >&2
  exit 1
fi

printf 'release version verified: %s\n' "$VERSION"
printf '%s\n' "$VERSION"
