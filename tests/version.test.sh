#!/usr/bin/env bash
# The version string lives in five manifests and again in the changelog, and
# nothing kept them in step. A release that bumps four of the five ships a
# plugin whose reported version disagrees with the marketplace entry that
# installed it — visible to users, invisible in review.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "version:"

# Reads a dotted path out of a JSON file. Array indices are plain integers:
# JS object access on an array accepts them.
read_json() {
  node -e '
    const o = require(process.argv[1]);
    let v = o;
    for (const k of process.argv[2].split(".")) v = v == null ? v : v[k];
    console.log(v == null ? "" : v);
  ' "$1" "$2" 2>/dev/null
}

MANIFESTS=(
  "package.json|version"
  ".claude-plugin/plugin.json|version"
  ".claude-plugin/marketplace.json|plugins.0.version"
  ".codex-plugin/plugin.json|version"
  ".agents/plugins/marketplace.json|plugins.0.version"
)

# Shared SemVer grammar (semver.org grammar, ERE form) so the manifest check
# and the changelog-heading check can never drift apart the way they did
# before: a prerelease/build version like 0.2.0-beta.1 must match both.
SEMVER_CORE='(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
SEMVER_PRERELEASE='(-((0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?'
SEMVER_BUILD='(\+([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?'
SEMVER_RE="^${SEMVER_CORE}${SEMVER_PRERELEASE}${SEMVER_BUILD}\$"

REF=$(read_json "$ROOT/package.json" version)
if [[ "$REF" =~ $SEMVER_RE ]]; then
  PASS=$((PASS + 1)); printf '  ok   package.json carries a semver version (%s)\n' "$REF"
else
  FAIL=$((FAIL + 1)); printf '  FAIL package.json version is not semver: %s\n' "${REF:-<missing>}"
fi

for entry in "${MANIFESTS[@]}"; do
  file=${entry%%|*}
  path=${entry#*|}
  got=$(read_json "$ROOT/$file" "$path")
  if [ "$got" = "$REF" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s is %s\n' "$file" "$REF"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %s has %s, package.json has %s\n' "$file" "${got:-<missing>}" "$REF"
  fi
done

# The changelog's newest RELEASED heading, ignoring [Unreleased]. Before the
# first release there is none, and that is not a failure — it is the state the
# repository is in until a version is cut. Uses the same SEMVER_* grammar as
# REF above, so a prerelease/build heading like [0.2.0-beta.1] is recognized
# instead of silently falling through to "no release heading found".
CL=$(grep -oE "^## \[${SEMVER_CORE}${SEMVER_PRERELEASE}${SEMVER_BUILD}\]" "$ROOT/CHANGELOG.md" | head -1 | tr -d '#[] ')
if [ -z "$CL" ]; then
  printf '  note CHANGELOG.md has no released version heading yet; nothing to compare\n'
elif [ "$CL" = "$REF" ]; then
  PASS=$((PASS + 1)); printf '  ok   CHANGELOG.md newest release is %s\n' "$CL"
else
  FAIL=$((FAIL + 1))
  printf '  FAIL CHANGELOG.md newest release is %s, manifests say %s\n' "$CL" "$REF"
fi

summary "version"
