#!/usr/bin/env bash
# Extract a named shell fence OUT of the canonical procedure.
#
# The fences are tested by extraction rather than by copying them into the test
# suite: a copy would be a second source of truth for classification logic, and
# the point of the tests is to pin the interface the procedure's decision table
# consumes, not to restate it.
#
# Usage: tests/extract-fences.sh <fence-id> [procedure-path]
#        tests/extract-fences.sh --list [procedure-path]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${2:-$ROOT/commands/review-loop.md}"

if [ "${1:-}" = "--list" ]; then
  SRC="${2:-$ROOT/commands/review-loop.md}"
  grep -o 'revloop:fence id=[A-Za-z0-9_-]*' "$SRC" | sed 's/.*id=//'
  exit 0
fi

ID="${1:?usage: extract-fences.sh <fence-id> [procedure-path]}"

awk -v id="$ID" '
  index($0, "revloop:fence id=" id " ") || $0 ~ ("revloop:fence id=" id "[ ]*-->") { armed = 1; next }
  armed && !opened {
    line = $0
    sub(/^[ \t]*/, "", line)
    if (line == "```bash") {
      match($0, /^[ \t]*/)
      indent = RLENGTH
      opened = 1
    }
    next
  }
  opened {
    line = $0
    sub(/^[ \t]*/, "", line)
    if (line == "```") { exit }
    print substr($0, indent + 1)
  }
  END { if (!opened) { print "extract-fences: fence not found: " id > "/dev/stderr"; exit 1 } }
' "$SRC"
