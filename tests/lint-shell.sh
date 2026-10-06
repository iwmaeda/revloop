#!/usr/bin/env bash
# Static analysis over the extracted fences and the harness. The binary is
# pinned in mise.toml, and a run without it announces the skip.
# A comment starting with the word "shellcheck" is parsed as a directive. Avoid that.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "lint:sh  SKIPPED (shellcheck not installed; run 'mise install')"
  exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for id in $("$ROOT/tests/extract-fences.sh" --list); do
  "$ROOT/tests/extract-fences.sh" "$id" > "$TMP/$id.sh"
done

# SC2086: `set -- $ROW` splits the space-separated rows on purpose, under `set -f`.
# SC2016: the GraphQL query and the jq program hold $o, $n and $p, which must
# reach the server and gh's jq engine unexpanded.
shellcheck --shell=bash --exclude=SC2086,SC2016 "$TMP"/*.sh
shellcheck -x --shell=bash "$ROOT"/tests/*.sh "$ROOT"/tests/gh-stub "$ROOT"/tests/bin/gh
echo "lint:sh  OK"
