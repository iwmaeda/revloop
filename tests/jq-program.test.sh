#!/usr/bin/env bash
# Exercises the jq program inside the wait-verdict fence directly, against raw
# GraphQL payloads. The other suites replay the rows this program is expected to
# produce; this one checks that it actually produces them.
#
# Needs a jq binary — pinned in mise.toml; `mise install` puts it on PATH.
# gh embeds gojq rather than jq, so a difference between the two would show up
# here as a false failure; the constructs used (select, test, contains, split,
# gsub) behave identically in both.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "jq-program:"

if ! command -v jq >/dev/null 2>&1; then
  echo "  note jq not installed; the fence's jq program is not exercised here."
  echo "       (run 'mise install'. Locally the row fixtures still cover the shell.)"
  exit 0
fi

PROG=$("$ROOT/tests/extract-fences.sh" wait-verdict | sed -n "s/^J='\(.*\)'$/\1/p")
if [ -z "$PROG" ]; then
  echo "  FAIL could not lift the jq program out of the fence"
  exit 1
fi

FX="$ROOT/tests/fixtures"
run() { jq -r "$PROG" < "$FX/$1/graphql.json"; }

o=$(run verdict/clean-comment)
expect "a marked trigger yields exactly one TRIG row" "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "1"
expect "  the marker payload is carried through"      "$o" "bot=chatgpt-codex-connector"
expect "  the verdict comment is emitted"             "$o" "comment 2026-08-19T10:04:00Z chatgpt-codex-connector 222"

# revloop's own trigger matches the compatibility pattern too. If both branches
# fired, the comment would emit two TRIG rows with the same timestamp, `tail -1`
# would take the compat one, and the marker — with it the bot filter and the
# runaway check — would be silently discarded.
o=$(run jq/human-decoy)
expect "a human naming a person is not a trigger" "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "1"
refute "  the decoy did not become a baseline"   "$o" "555"

# `=` in a bot body would otherwise let the body forge a machine-readable key.
o=$(run jq/injection)
expect "= is neutralised in a bot body"    "$o" "pr-999"
refute "  no forged pr= survives"          "$o" "pr=999"
refute "  no forged trigger= survives"     "$o" "trigger=2030"
refute "  no forged review_id= survives"   "$o" "review_id=42"

# A non-terminal preamble must be dropped at fetch time. Emitting it makes the
# fence exit on its first iteration every time it is re-fired.
o=$(run jq/preamble)
refute "a preamble is not emitted as a comment" "$o" "Summary of Changes"
expect "  the trigger is still seen"            "$o" "TRIG"

# A focus containing the literal `revloop:trigger` wins the split, so the marker
# keys are never reached. Step 7 forbids composing such a focus; this pins what
# happens if one is composed anyway, which is that the round fails closed: with
# no `head=` the marker reads `marker_head=none` and step 9 aborts. The row is
# still emitted — the trigger is found — so the failure is a lost wait, not a
# lost trigger. The dangerous half is the missing `bot=`: an empty bot disables
# the fence's bot filter, so any other bot on the PR would satisfy the wait.
o=$(run jq/focus-carrying-marker)
expect "a focus carrying the literal still yields one TRIG" "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "1"
refute "  the head key is lost, so step 9 aborts"           "$o" "head="
refute "  the bot key is lost with it"                      "$o" "bot="

o=$(run jq/dismissed-and-multiline)
refute "a DISMISSED review is not a verdict"  "$o" "review "
expect "  a multi-line body collapses to one" "$o" "800 first line of the body"
refute "  the second line is dropped"         "$o" "second line should not appear"

summary "jq-program"
