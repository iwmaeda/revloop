#!/usr/bin/env bash
# Runs the jq program from the wait-verdict fence against the raw GraphQL
# payloads in tests/fixtures. Needs a jq binary, pinned in mise.toml.
# gh embeds gojq; the constructs used behave the same in both.
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

# A marked trigger also matches the compat pattern. It must yield one TRIG row.
o=$(run verdict/clean-comment)
expect "a marked trigger yields exactly one TRIG row" "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "1"
expect "  the marker payload is carried through"      "$o" "bot=chatgpt-codex-connector"
expect "  the verdict comment is emitted"             "$o" "comment 2026-08-19T10:04:00Z chatgpt-codex-connector 222"

# The marker payload passes a character whitelist, so a new key has to survive it.
o=$(run verdict/retry-marker)
expect "a new marker key survives the filter"   "$o" "attempt=2"
expect "  alongside the keys it already knew"   "$o" "head=1a2b3c4d round=3"

o=$(run jq/human-decoy)
expect "a human naming a person is not a trigger" "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "1"
refute "  the decoy did not become a baseline"   "$o" "555"

# `=` in a bot body would otherwise let the body forge a machine-readable key.
o=$(run jq/injection)
expect "= is neutralised in a bot body"    "$o" "pr-999"
refute "  no forged pr= survives"          "$o" "pr=999"
refute "  no forged trigger= survives"     "$o" "trigger=2030"
refute "  no forged review_id= survives"   "$o" "review_id=42"

# A preamble is dropped at fetch time, or a re-fired fence would exit on its first iteration.
o=$(run jq/preamble)
refute "a preamble is not emitted as a comment" "$o" "Summary of Changes"
expect "  the trigger is still seen"            "$o" "TRIG"

# Codex's status card is edited in place while the review runs, so it is newer
# than the baseline on every poll. It names the trigger phrase and anchors nothing.
o=$(run verdict/codex-status-card)
refute "a status card is not emitted as a comment" "$o" "codex-pull-request-review-summary"
expect "  the trigger is the only row left"        "$(printf '%s\n' "$o" | grep -c .)" "1"
expect "  and it is the marked one"                "$o" "TRIG 2026-10-06T00:03:23Z 111 0 v=1 reviewer=codex"

o=$(run verdict/codex-status-card-clean)
refute "the card is dropped beside a verdict too"  "$o" "codex-pull-request-review-summary"
expect "  and the clean comment is still emitted"  "$o" "comment 2026-10-06T00:06:20Z chatgpt-codex-connector 600 Codex Review: Didn't find any major issues. Chef's kiss."

# A bot comment carrying the viewer's own eyes reaction is dropped, whatever its body.
o=$(run verdict/marked-comment)
refute "a marked comment is not emitted"           "$o" "comment "
expect "  the trigger is the only row left"        "$(printf '%s\n' "$o" | grep -c .)" "1"

o=$(run verdict/marked-comment-then-clean)
expect "a comment newer than the mark is emitted"  "$o" "comment 2026-10-10T00:03:10Z chatgpt-codex-connector 600 Codex Review"
refute "  and the marked one is not"               "$o" " 500 "

o=$(run verdict/marked-comment-over-rate-limit)
expect "an older comment is emitted under a mark"  "$o" "comment 2026-10-10T00:00:09Z chatgpt-codex-connector 400 You have reached"
refute "  and the marked one is not"               "$o" " 500 "

# Another account's eyes, and the viewer's thumbs-up, are not what the fence
# filters on. The active-marks read in step 9 does count anyone's eyes.
o=$(run verdict/not-the-viewers-reactions)
expect "only the viewer's eyes drop a comment"     "$o" "comment 2026-10-10T00:00:20Z chatgpt-codex-connector 500 Review started."

# A focus holding the literal `revloop:trigger` wins the split, so the marker
# keys are never reached. Pinned: one TRIG row with no head= and no bot=.
o=$(run jq/focus-carrying-marker)
expect "a focus carrying the literal still yields one TRIG" "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "1"
refute "  the row carries no head= for step 9 to bind to"   "$o" "head="
refute "  the row carries no bot= for the filter to use"    "$o" "bot="

o=$(run jq/dismissed-and-multiline)
refute "a DISMISSED review is not a verdict"  "$o" "review "
expect "  a multi-line body collapses to one" "$o" "800 first line of the body"
refute "  the second line is dropped"         "$o" "second line should not appear"

# `reviews(last:15)` truncates on the server; the selects run here on what is left.
# The fixture holds fifteen rows the selects drop. Truncation itself is not tested.
o=$(run jq/window-full-of-humans)
expect "a full window still yields the trigger"   "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "2"
expect "  no review row survives the filters"     "$(printf '%s\n' "$o" | grep -c '^review ')" "0"
expect "  the comment behind them is emitted"     "$o" "comment 2026-09-09T10:52:52Z chatgpt-codex-connector 5600599999"
refute "  no human review leaked through"         "$o" "reviewer-0"
refute "  and no DISMISSED one either"            "$o" "5154100000"

# The generators emit in program order, so a compat row lands after every marker
# row. The shell sorts TRIG rows for that reason. Delete this case if they merge.
o=$(run verdict/older-compat-trigger)
expect "both trigger classes are emitted"      "$(printf '%s\n' "$o" | grep -c '^TRIG ')" "2"
expect "  the newer marker is emitted first"   "$(printf '%s\n' "$o" | grep '^TRIG ' | head -1)" "2026-08-25T09:00:00Z"
expect "  the older compat row lands after it" "$(printf '%s\n' "$o" | grep '^TRIG ' | tail -1)" "compat=1"

summary "jq-program"
