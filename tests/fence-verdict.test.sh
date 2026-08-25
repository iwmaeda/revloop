#!/usr/bin/env bash
# Exercises the wait-verdict fence against recorded fixtures. Every row of the
# step-9 decision table that the fence can produce has a case here.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
extract_accelerated wait-verdict "$TMP/f.sh"
FX="$ROOT/tests/fixtures/verdict"
r() { run_fence "$TMP/f.sh" "$FX/$1"; }

echo "wait-verdict:"

o=$(r clean-comment)
expect "clean comment -> VERDICT=comment"       "$o" "VERDICT=comment"
expect "  carries reviewer from the marker"     "$o" "reviewer=codex"
expect "  carries marker_head"                  "$o" "marker_head=1a2b3c4d"
expect "  carries round"                        "$o" "round=1"
expect "  carries the comment id"               "$o" "cid=222"
expect "  body is last and intact"              "$o" "body=Codex Review: Didn't find any major issues. Keep it up!"

o=$(r review-with-findings)
expect "review -> VERDICT=review"               "$o" "VERDICT=review"
expect "  carries review_id"                    "$o" "review_id=333"
expect "  carries commit"                       "$o" "commit=1a2b3c4d"

o=$(r review-and-comment)
expect "review+comment -> review is primary"    "$o" "VERDICT=review"
expect "  rate limit surfaces on EXTRA="        "$o" "EXTRA=comment"
expect "  EXTRA carries the rate-limit body"    "$o" "body=You have reached your Codex usage limits"

# Safety: a newer compatibility trigger must not let a verdict from BEFORE it be
# reported as this round's. Losing liveness here is correct; adopting the stale
# verdict would not be.
o=$(r decoy-compat-trigger)
expect "newer trigger -> pending, not stale"    "$o" "VERDICT=pending"
refute "  does not adopt the older verdict"     "$o" "VERDICT=comment"

# The mirror image of the decoy above, and the case the fixtures did not have: a
# hand-typed trigger OLDER than the marker. The jq program builds one array from
# four generators and array construction preserves generator order, so a compat
# row is emitted after every marker row however old it is. Taking the last row
# therefore picked the newest hand-typed trigger whenever one existed at all, and
# on a pull request driven by hand before revloop was adopted those comments are
# permanent — so the baseline could never move forward.
o=$(r older-compat-trigger)
expect "older hand-typed trigger loses"         "$o" "VERDICT=pending"
expect "  baseline is the newest trigger"       "$o" "trigger=2026-08-25T09:00:00Z"
refute "  not the older hand-typed one"         "$o" "trigger=2026-08-24"
refute "  no verdict from before the marker"    "$o" "VERDICT=review"
refute "  the previous round's commit is gone"  "$o" "commit=a5eb3169"

# The liveness half, one round later on the same pull request. A compat baseline
# carries no bot=, and an empty bot= disables the filter, so this returned a
# foreign bot's review as the reviewer's verdict.
o=$(r older-compat-trigger-review)
expect "the round after converges"              "$o" "VERDICT=review"
expect "  on the marker's own baseline"         "$o" "trigger=2026-08-25T09:00:00Z"
expect "  the marker binds a head again"        "$o" "marker_head=9f8e7d6c"
expect "  and carries its round"                "$o" "round=4"
expect "  the reviewer's own review wins"       "$o" "review_id=950"
refute "  not the previous round's"             "$o" "review_id=800"
refute "  the bot filter is live again"         "$o" "copilot-pull-request-reviewer"

# The marker's bot= discards every other bot on the PR at fetch time.
o=$(r foreign-bot)
expect "foreign bots filtered -> pending"       "$o" "VERDICT=pending"
refute "  no copilot verdict"                   "$o" "copilot-pull-request-reviewer"
refute "  no deploy-preview verdict"            "$o" "cloudflare-workers-and-pages"

o=$(r no-trigger)
expect "no trigger, no verdict"                 "$o" "VERDICT=error reason=no-trigger"

o=$(r untriggered-verdict)
expect "verdict without a trigger"              "$o" "VERDICT=error reason=untriggered-verdict"
expect "  carries the bot line"                 "$o" "bot=comment"

# Two generators again: every review row precedes every comment row, so the last
# row was the newest comment, never the newest signal. Diagnostic only, but the
# same defect — and fixing it separately would cost a second re-approval.
o=$(r untriggered-verdict-review)
expect "the newest untriggered signal wins"     "$o" "bot=review 2026-08-19T10:09:00Z"
refute "  not the older comment"                "$o" "bot=comment"

o=$(r reaction)
expect "thumbs-up -> VERDICT=reaction"          "$o" "VERDICT=reaction"
expect "  carries the trigger id"               "$o" "id=111"

# A bot body containing key-shaped text must not displace a real key.
o=$(r body-keys)
expect "keys survive a key-shaped body"         "$o" "VERDICT=comment pr=7 trigger=2026-08-19T10:00:00Z"
expect "  the real pr= is intact"               "$o" "pr=7"
refute "  the body's fake pr= did not parse"    "$o" "pr=999"

o=$(run_fence_detached "$TMP/f.sh" "$FX/clean-comment")
expect "detached HEAD -> no-branch"             "$o" "VERDICT=error reason=no-branch"
refute "  never reaches a PR"                   "$o" "pr="

o=$(r no-pr);      expect "empty PR list -> no-pr"        "$o" "VERDICT=error reason=no-pr"
o=$(r setup-fail); expect "repo lookup fails -> setup"    "$o" "VERDICT=error reason=api stage=setup"
o=$(r pr-fail);    expect "pr lookup fails -> setup"      "$o" "VERDICT=error reason=api stage=setup"

o=$(ACCEL_BUDGET=30 bash -c '. "$1"; extract_accelerated wait-verdict "$2/f2.sh"; run_fence "$2/f2.sh" "$3/api-fail"' _ "$ROOT/tests/lib.sh" "$TMP" "$FX")
expect "5 consecutive fetch failures -> api"    "$o" "VERDICT=error reason=api pr=7"
refute "  not mislabelled as a setup failure"  "$o" "stage=setup"

summary "wait-verdict"
