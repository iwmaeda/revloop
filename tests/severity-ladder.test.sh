#!/usr/bin/env bash
# The canonical severity ladder is written out in nine places. This pins them
# to one.
#
# `critical > high > medium > low` is revloop's own vocabulary rather than any
# reviewer's, and it is spelled in full in the schema's enum, in both procedures,
# in the two READMEs, in `reviewers/README.md`, in `docs/configuration.md`, in
# `docs/design-notes.md` and in `CHANGELOG.md`. Copies drift -- the reason
# `permissions.test.sh` exists is that one already had, twice -- and nothing
# compared these to each other.
#
# ONE OF THE NINE IS NOT PROSE. Step 10 of `commands/review-loop.md` carries the
# ladder inside the grader's prompt, so a drift there does not merely misdescribe
# the loop: it tells a subprocess to rank findings on a ladder the schema will
# not accept back, and every rung it returns then trips the rung check as a
# broken grader. That copy is asserted by name below rather than left to the
# sweep, because it is the one whose divergence is a runtime failure.
#
# THE SCHEMA IS THE SOURCE. Its enum is the only copy a machine reads, so the
# expected spelling is derived from it rather than written here -- a constant in
# this file would be a tenth copy, and the guard would then pin the copies to
# each other and not to the thing that validates.
#
# WHAT THE SWEEP MATCHES is any `>`-separated chain of lowercase words, and it
# requires every one to be the ladder. That is broader than "find the ladder and
# compare it", deliberately: a renamed rung, a reordered one, and a dropped one
# all still look like a chain, and all three would be invisible to a search for
# the ladder's own text. The corpus holds no other chain of this shape, which is
# measured rather than assumed -- the count assertion below is what keeps it
# measured after an edit.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "severity-ladder:"

SCHEMA="$ROOT/schema/revloop.schema.json"

# The severityMap value enum, read as data. Anchored to the four canonical words
# rather than to a line number or a key path: the schema holds six enums and the
# other five are unrelated vocabularies, so the match is on content.
ENUM_LINE=$(grep -F '"enum": ["critical"' "$SCHEMA" || true)
ENUM=$(printf '%s' "$ENUM_LINE" | grep -oE '"[a-z]+"' | tr -d '"' | tail -n +2)
LADDER=$(printf '%s' "$ENUM" | paste -sd'|' - | sed 's/|/ > /g')

# Asserted before anything derived from it is used: an extraction that found
# nothing yields an empty LADDER, and `grep -vxF ""` then calls every chain
# stray -- loud, but for the wrong reason and naming the wrong file.
RUNGS=$(printf '%s\n' "$ENUM" | grep -c . || true)
if [ -n "$ENUM_LINE" ] && [ "$RUNGS" -eq 4 ]; then
  PASS=$((PASS + 1)); printf '  ok   the schema carries a four-rung enum\n'
else
  FAIL=$((FAIL + 1)); printf '  FAIL enum extraction found %s rungs, not 4\n' "$RUNGS"
fi
expect "and it reads most severe first" "$LADDER" "critical > high > medium > low"

# Every chain in the corpus, whatever it says. Fences included: the grader's
# prompt is one, and it is the copy that matters most.
CHAINS=$(grep -rhoE '\b[a-z][a-z-]* > [a-z][a-z-]*( > [a-z][a-z-]*)*' \
  --include='*.md' --include='*.json' "$ROOT" 2>/dev/null | grep -v '/node_modules/' || true)
COUNT=$(printf '%s\n' "$CHAINS" | grep -c . || true)
STRAY=$(printf '%s\n' "$CHAINS" | grep -vxF "$LADDER" | grep . | sed 's/^/STRAY /' || true)

# A broken sweep finds nothing, every chain then matches vacuously, and the
# assertion below goes green over an empty set. The floor is the same guard the
# `allowed-tools` block in permissions.test.sh states, for the same reason.
if [ "$COUNT" -ge 8 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d ladder spellings were found\n' "$COUNT"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d chains found; the sweep is broken\n' "$COUNT"
fi
refute "every chain spells the schema's ladder" "$STRAY" "STRAY "

# The executable copy, asserted by name. `-p` is what makes it the prompt rather
# than one more sentence about the prompt.
GRADER=$(grep -F 'Rank each finding' "$ROOT/commands/review-loop.md" || true)
expect "the grader's prompt exists"      "$GRADER" 'claude --model'
expect "and it ranks on that ladder"     "$GRADER" "$LADDER"
expect "and it is the prompt, not prose" "$GRADER" ' -p "'

# The sweep is a predicate, and the corpus cannot witness what a predicate fails
# to reject. These are the three ways a copy drifts.
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

summary "severity-ladder"
