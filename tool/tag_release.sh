#!/usr/bin/env sh
# Releases a version: sets it in pubspec.yaml, commits, tags v<version> and
# pushes, which starts .github/workflows/release.yml (store packages, a
# GitHub Release and, with the secrets set, Google Play internal testing
# and TestFlight). Usage: tool/tag_release.sh 1.0.1
set -eu

version=${1:?usage: tool/tag_release.sh <version, e.g. 1.0.1>}
case "$version" in
  *[!0-9.]*|.*|*.|*..*) echo "Version must look like 1.2.3" >&2; exit 1 ;;
esac
cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first." >&2
  exit 1
fi
if git rev-parse "v$version" >/dev/null 2>&1; then
  echo "Tag v$version already exists." >&2
  exit 1
fi

# The build number (+N) is set by the CI from its run number.
sed -i.bak "s/^version: .*/version: $version+1/" pubspec.yaml && rm pubspec.yaml.bak
git add pubspec.yaml
git commit -m "release: v$version"
git tag -a "v$version" -m "LumiFX $version"
git push origin HEAD "v$version"
echo "Pushed v$version: follow the Release workflow in GitHub › Actions."
