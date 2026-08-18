#!/usr/bin/env bash
# Static analysis over the extracted fences and the harness itself.
# The shellcheck binary is not universally installed; CI runners have it, so a
# local skip is announced rather than silent.
#
# Note: a comment whose first word is "shellcheck" is parsed as a directive, so
# lines here are worded to avoid starting that way.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "lint:sh  SKIPPED (shellcheck not installed; CI runs it)"
  exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for id in $("$ROOT/tests/extract-fences.sh" --list); do
  "$ROOT/tests/extract-fences.sh" "$id" > "$TMP/$id.sh"
done

# SC2086 (word splitting) is intentional in the fences: `set -- $ROW` is how the
# space-separated rows are parsed, and `set -f` above it disables globbing.
# SC2016 (no expansion in single quotes) is the point: the GraphQL query and the
# jq program contain $o, $n, $p, and $p.comments, which must reach the server and
# gh's jq engine untouched by the shell.
shellcheck --shell=bash --exclude=SC2086,SC2016 "$TMP"/*.sh
shellcheck -x --shell=bash "$ROOT"/tests/*.sh "$ROOT"/tests/gh-stub "$ROOT"/tests/bin/gh
echo "lint:sh  OK"
