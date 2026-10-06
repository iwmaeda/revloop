#!/usr/bin/env bash
# The version must agree across package.json, the four plugin manifests,
# package-lock.json and the newest released heading in CHANGELOG.md.
# Only the lockfile's root `version` is compared: npm writes it and
# `packages[""].version` in the same pass.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "version:"

# Reads a dotted path out of a JSON file. Array indices are plain integers.
# Exit 0: a value, empty if the path is absent. 3: no file. 2: invalid JSON. 4: other.
read_json() {
  node -e '
    let o;
    try { o = require(process.argv[1]); }
    catch (e) {
      if (e && e.code === "MODULE_NOT_FOUND") process.exit(3);
      process.exit(e instanceof SyntaxError ? 2 : 4);
    }
    let v = o;
    for (const k of process.argv[2].split(".")) v = v == null ? v : v[k];
    console.log(v == null ? "" : v);
  ' "$1" "$2" 2>/dev/null
}

read_status_words() { # read_status_words <rc>
  case $1 in
    3) printf '<absent> — there is no such file' ;;
    2) printf '<unreadable> — it is not valid JSON' ;;
    *) printf '<unreadable> — reading it failed some other way; stderr is discarded' ;;
  esac
}

# Each row is file | dotted path | remedy. A remedy may not contain "|".
MANIFESTS=(
  "package.json|version|edit this file"
  ".claude-plugin/plugin.json|version|edit this file"
  ".claude-plugin/marketplace.json|plugins.0.version|edit this file"
  ".codex-plugin/plugin.json|version|edit this file"
  ".agents/plugins/marketplace.json|plugins.0.version|edit this file"
  "package-lock.json|version|run npm install --package-lock-only; do not edit it"
)

parse_row() { # parse_row <entry> ; sets ROW_FILE ROW_PATH ROW_REMEDY
  local extra
  IFS='|' read -r ROW_FILE ROW_PATH ROW_REMEDY extra <<< "$1"
  [ -n "$ROW_FILE" ] && [ -n "$ROW_PATH" ] && [ -n "$ROW_REMEDY" ] && [ -z "$extra" ]
}

# Compares one dotted path against a reference and prints one result line.
# Callers classify on the return status, so rewording a message moves no count.
check_version() { # check_version <label> <abs-path> <dotted-path> <remedy> <reference>
  local label="$1" file="$2" path="$3" remedy="$4" REF="$5" got rc
  got=$(read_json "$file" "$path"); rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAIL %s %s %s\n' "$label" "$path" "$(read_status_words "$rc")"
    return 1
  fi
  # An empty reference would equal an empty read and report agreement.
  if [ -z "$REF" ]; then
    printf 'FAIL %s %s not compared — package.json yielded no version to compare against\n' "$label" "$path"
    return 1
  fi
  if [ "$got" = "$REF" ]; then
    printf 'ok   %s %s is %s\n' "$label" "$path" "$REF"
    return 0
  fi
  printf 'FAIL %s %s has %s, package.json has %s — %s\n' \
    "$label" "$path" "${got:-<missing>}" "$REF" "$remedy"
  return 1
}

# SemVer grammar as ERE, shared by the manifest check and the changelog heading.
SEMVER_CORE='(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
SEMVER_PRERELEASE='(-((0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?'
SEMVER_BUILD='(\+([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?'
SEMVER_RE="^${SEMVER_CORE}${SEMVER_PRERELEASE}${SEMVER_BUILD}\$"

REF=$(read_json "$ROOT/package.json" version); REF_RC=$?
if [ "$REF_RC" -ne 0 ]; then
  FAIL=$((FAIL + 1)); REF=''
  printf '  FAIL package.json %s; nothing below has a reference\n' "$(read_status_words "$REF_RC")"
elif [[ "$REF" =~ $SEMVER_RE ]]; then
  PASS=$((PASS + 1)); printf '  ok   package.json carries a semver version (%s)\n' "$REF"
else
  FAIL=$((FAIL + 1)); printf '  FAIL package.json version is not semver: %s\n' "${REF:-<missing>}"
fi

for entry in "${MANIFESTS[@]}"; do
  if ! parse_row "$entry"; then
    FAIL=$((FAIL + 1))
    printf '  FAIL malformed MANIFESTS row — three fields, and no "|" inside one: %s\n' "$entry"
    continue
  fi
  if line=$(check_version "$ROW_FILE" "$ROOT/$ROW_FILE" "$ROW_PATH" "$ROW_REMEDY" "$REF"); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
  printf '  %s\n' "$line"
done

# --- self-checks: the branches of check_version that agreeing manifests never reach ---
# A fixture needs a .json name: `require` picks its parser from the extension.
STALE_DIR=$(mktemp -d)
# Unset, every fixture path below would resolve under the filesystem root.
if [ -z "$STALE_DIR" ] || [ ! -d "$STALE_DIR" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL could not create a temporary directory; no self-check ran\n'
  summary "version"
  exit
fi
trap 'rm -rf "$STALE_DIR"' EXIT
printf '{"name":"revloop","version":"0.0.0-stale","lockfileVersion":3}\n' > "$STALE_DIR/package-lock.json"
printf 'this is not JSON\n' > "$STALE_DIR/broken.json"

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

# Runs check_version, classifies on its return status and leaves the line in SELF_LINE.
classify() { # classify <label> <expected verdict: ok|fail> <check_version args...>
  local name="$1" want="$2" line rc
  shift 2
  # `rc=$?` must stay on the same line as the assignment it reads.
  line=$(check_version "$@"); rc=$?
  SELF_LINE="$line"
  local verdict=ok; [ "$rc" -eq 0 ] || verdict=fail
  if [ "$verdict" = "$want" ]; then
    pass "$name"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       got: %s\n' "$name" "$line"
  fi
}

classify "a disagreeing version is classified as a failure" fail \
  'synthetic lockfile' "$STALE_DIR/package-lock.json" version 'regenerate it' "$REF"
expect "and the line names the version it found" "$SELF_LINE" '0.0.0-stale'
expect "and the line names the remedy for that file" "$SELF_LINE" 'regenerate it'

classify "an absent path is classified as a failure" fail \
  'synthetic lockfile' "$STALE_DIR/package-lock.json" nosuchkey 'regenerate it' "$REF"
expect "and reads as missing rather than as a version" "$SELF_LINE" '<missing>'

classify "a file that is not JSON is classified as a failure" fail \
  'synthetic lockfile' "$STALE_DIR/broken.json" version 'regenerate it' "$REF"
expect "and reads as unreadable rather than as missing" "$SELF_LINE" '<unreadable>'
expect "and says which unreadable it is, not the catch-all" "$SELF_LINE" 'it is not valid JSON'

classify "an absent file is classified as a failure" fail \
  'synthetic lockfile' "$STALE_DIR/gone.json" version 'regenerate it' "$REF"
expect "and reads as absent rather than as unparseable" "$SELF_LINE" '<absent>'

# An empty reference and an empty read: "" = "" must not count as agreement.
classify "an empty reference is classified as a failure, not as agreement" fail \
  'synthetic lockfile' "$STALE_DIR/package-lock.json" nosuchkey 'regenerate it' ''
expect "and names the reference as what is missing" "$SELF_LINE" 'package.json yielded no version'

classify "an agreeing version is classified as agreement" ok \
  'this package.json' "$ROOT/package.json" version 'edit this file' "$REF"

# The lockfile's remedy is asserted as a literal copy, so a typo in the row fails.
LOCK_REMEDY='run npm install --package-lock-only; do not edit it'
expect "the lockfile row still carries the remedy that forbids a hand edit" \
  "${MANIFESTS[*]}" "$LOCK_REMEDY"
classify "and a disagreeing lockfile is classified as a failure" fail \
  'synthetic lockfile' "$STALE_DIR/package-lock.json" version "$LOCK_REMEDY" "$REF"
expect "and its line carries that remedy through to the reader" "$SELF_LINE" "$LOCK_REMEDY"

# Exit 4: a file that exists and cannot be opened. Root can open it, so root skips.
if [ "$(id -u)" -ne 0 ]; then
  printf '{"version":"0.0.0-stale"}\n' > "$STALE_DIR/locked.json"
  chmod 000 "$STALE_DIR/locked.json"
  classify "a file that cannot be opened is classified as a failure" fail \
    'synthetic lockfile' "$STALE_DIR/locked.json" version "$LOCK_REMEDY" "$REF"
  refute "and is not reported as a syntax error it was never read for" "$SELF_LINE" 'not valid JSON'
  chmod 644 "$STALE_DIR/locked.json"
else
  printf '  SKIP running as root, so a file that cannot be opened cannot be built:\n'
  printf '       2 of the checks below this line did not run\n'
fi

# parse_row's rejecting branch. Every real row is well formed.
for bad in 'a.json|version' 'a.json' '|version|edit this file' 'a.json||edit this file' \
  'a.json|version|do not use | inside a remedy'; do
  if parse_row "$bad"; then
    fail "a malformed row was accepted: $bad"
  else
    pass "a malformed row is rejected: $bad"
  fi
done
if parse_row 'a.json|version|edit this file'; then
  pass "a well-formed row is accepted"
else
  fail "a well-formed row was rejected"
fi

# The changelog's newest released heading, ignoring [Unreleased]. None yet is not a failure.
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
