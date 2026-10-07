#!/usr/bin/env bash
# Record the current fence bytes. Run it only together with a CHANGELOG entry:
# a fence change costs every user one re-approval of that command string.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: > "$ROOT/tests/fence-hashes.txt"
for id in $("$ROOT/tests/extract-fences.sh" --list); do
  printf '%s  %s\n' "$("$ROOT/tests/extract-fences.sh" "$id" | sha256sum | cut -d' ' -f1)" "$id" \
    >> "$ROOT/tests/fence-hashes.txt"
done
cat "$ROOT/tests/fence-hashes.txt"
