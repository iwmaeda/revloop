#!/usr/bin/env bash
# Every written-out severity ladder must match the enum in
# schema/reviewer.schema.json. Sweeps *.md and *.json outside node_modules for
# `a > b` chains and checks the grader prompt in procedures/severity-grading.md
# by name.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "severity-ladder:"

SCHEMA="$ROOT/schema/reviewer.schema.json"

# The severityMap enum, matched on its content: the schema holds four other enums.
ENUM_LINE=$(grep -F '"enum": ["critical"' "$SCHEMA" || true)
ENUM=$(printf '%s' "$ENUM_LINE" | grep -oE '"[a-z]+"' | tr -d '"' | tail -n +2)
LADDER=$(printf '%s' "$ENUM" | paste -sd'|' - | sed 's/|/ > /g')

# Checked first: an empty LADDER would call every chain stray.
RUNGS=$(printf '%s\n' "$ENUM" | grep -c . || true)
if [ -n "$ENUM_LINE" ] && [ "$RUNGS" -eq 4 ]; then
  PASS=$((PASS + 1)); printf '  ok   the schema carries a four-rung enum\n'
else
  FAIL=$((FAIL + 1)); printf '  FAIL enum extraction found %s rungs, not 4\n' "$RUNGS"
fi
expect "and it reads most severe first" "$LADDER" "critical > high > medium > low"

# Every chain in the corpus, fences included. node_modules is excluded by grep
# itself: -h drops file names, so a filter on the output has no path to match.
sweep() { # sweep <dir> -> every chain under it, one per line
  grep -rhoE '\b[a-z][a-z-]* > [a-z][a-z-]*( > [a-z][a-z-]*)*' \
    --include='*.md' --include='*.json' --exclude-dir=node_modules "$1" 2>/dev/null || true
}
CHAINS=$(sweep "$ROOT")
COUNT=$(printf '%s\n' "$CHAINS" | grep -c . || true)
STRAY=$(printf '%s\n' "$CHAINS" | grep -vxF "$LADDER" | grep . | sed 's/^/STRAY /' || true)

# Floor: a broken sweep finds nothing and the refute below passes over an empty set.
if [ "$COUNT" -ge 8 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d ladder spellings were found\n' "$COUNT"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d chains found; the sweep is broken\n' "$COUNT"
fi
refute "every chain spells the schema's ladder" "$STRAY" "STRAY "

# The grader's prompt, by name. The -p argument is what makes it the prompt.
GRADER=$(grep -F 'Rank each finding' "$ROOT/procedures/severity-grading.md" || true)
expect "the grader's prompt exists"      "$GRADER" 'claude --model'
expect "and it ranks on that ladder"     "$GRADER" "$LADDER"
expect "and it is the prompt, not prose" "$GRADER" ' -p "'

# --- the chain matcher against drifted ladders ---
drifted() { # drifted <text> -> STRAY | CLEAN
  local s
  s=$(printf '%s' "$1" | grep -oE '\b[a-z][a-z-]* > [a-z][a-z-]*( > [a-z][a-z-]*)*' | grep -vxF "$LADDER")
  [ -n "$s" ] && echo STRAY || echo CLEAN
}

expect "a reordered ladder is stray"  "$(drifted 'critical > medium > high > low')" STRAY
expect "a renamed rung is stray"      "$(drifted 'critical > high > minor > low')"  STRAY
expect "a dropped rung is stray"      "$(drifted 'critical > high > low')"          STRAY
expect "a lengthened ladder is stray" "$(drifted 'blocker > critical > high > medium > low')" STRAY
expect "the ladder itself is clean"   "$(drifted 'on the ladder critical > high > medium > low.')" CLEAN
expect "prose with no chain is clean" "$(drifted 'the rungs come from severityLevels')" CLEAN

# The node_modules exclusion, on a tree built for it.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/node_modules/pkg"
printf 'on the ladder %s.\n' "$LADDER" > "$TMP/doc.md"
printf 'a > b\n' > "$TMP/node_modules/pkg/README.md"
expect "the sweep reads the tree"            "$(sweep "$TMP")" "$LADDER"
refute "and skips a chain under node_modules" "$(sweep "$TMP")" "a > b"

summary "severity-ladder"
