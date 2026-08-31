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

# Same second, both classes. Every other case in this file is decided by the
# primary key alone, so the databaseId tie-break is reachable only here. Both
# keys are server-assigned and GitHub's comment ids are monotonic, so the pair is
# creation order rather than an arbitrary tie-break. The invariant is "the row
# posted later wins, whatever its class" — not "the marker wins".
#
# VERDICT=pending prints neither marker_head= nor round=, and the two rows share
# a timestamp, so trigger= cannot say which won. Each fixture therefore carries a
# verdict, and the marker keys report the winner. The foreign bot below is the
# second discriminator: bot= filters it out, and a compat baseline — which
# carries no bot= at all — would disable the filter and adopt it as the newest.
o=$(r same-second-trigger)
expect "same second: the later row wins"        "$o" "VERDICT=review"
expect "  the marker was posted second"         "$o" "marker_head=9f8e7d6c"
expect "  so it carries its round"              "$o" "round=4"
expect "  and its reviewer"                     "$o" "reviewer=codex"
expect "  the bot filter is live"               "$o" "review_id=950"
refute "  the compat row did not anchor"        "$o" "marker_head=none"
refute "  and did not disable the filter"       "$o" "copilot-pull-request-reviewer"

# The mirror: same second, compat posted second. It really is the newest trigger,
# so it wins and binds no head — step 9 then aborts on marker_head=none rather
# than adopting the verdict. Failing closed here is the correct outcome, not a
# gap. This case passes with the sort removed as well, and is kept anyway: it
# pins that the tie-break orders by id rather than preferring the marker class,
# which is the half the case above cannot show.
o=$(r same-second-trigger-compat)
expect "same second: a later compat also wins" "$o" "VERDICT=review"
expect "  a compat baseline binds no head"      "$o" "marker_head=none"
expect "  and names no reviewer"                "$o" "reviewer=unknown"
refute "  the marker did not win on class"      "$o" "marker_head=9f8e7d6c"

# A re-post carries a marker key the fence has never been told about. The parser
# is a `case` with no default branch, so an unknown key is discarded rather than
# mistaken for a value — which is the whole reason `attempt=` could be added
# without editing a fence, and with it without costing every user a re-approval.
# No other fixture carries a marker with anything but the four documented keys,
# so nothing else exercises an unknown key at all.
o=$(r retry-marker)
expect "an unknown marker key is ignored"       "$o" "VERDICT=review"
expect "  reviewer still parses"                "$o" "reviewer=codex"
expect "  head still binds"                     "$o" "marker_head=1a2b3c4d"
expect "  round is not displaced by it"         "$o" "round=3"
refute "  and the key itself is not echoed"     "$o" "attempt="

# The re-post itself: two triggers on the same HEAD, same round, one round apart.
# The second is the baseline, and the verdict after it belongs to this round.
#
# The round assertion below pins only that the fence reads `round=` off the
# winning marker rather than off the one it re-posts. It does NOT pin that a
# re-post leaves the round alone: both triggers carry `round=3` because this
# fixture was hand-written that way, and the fence has no round-counting logic
# to get wrong. That rule — a re-post must not advance the round, or a reviewer
# that drops one comment silently halves `--max-rounds` — lives in step 7's
# prose, which this harness does not execute. Nothing here can catch its
# violation, and saying so is worth more than a comment that implies otherwise.
o=$(r retry-baseline)
expect "the re-post becomes the baseline"       "$o" "trigger=2026-08-19T10:31:00Z"
refute "  not the trigger it re-posts"          "$o" "trigger=2026-08-19T10:00:00Z"
expect "  round comes off the winning marker"   "$o" "round=3"
expect "  and the verdict after it is adopted"  "$o" "review_id=333"

# The cost of re-posting, pinned rather than left as prose. The fence polls and
# then sleeps 30 seconds, so a signal landing between the expiring chunk's last
# poll and the new trigger is older than the new baseline and is dropped. This
# is the too-new row of the table in docs/design-notes.md. For a clean verdict
# and for a rate limit it is a liveness cost and it is accepted: the behaviour
# it replaces is an abort, which loses the same signal and the round with it.
# For the two abort-class comments it is a safety cost that nothing offsets,
# which is why a two-trigger round reports that a signal may have been orphaned.
# DO NOT "fix" this case by walking the baseline back to the older trigger —
# that is the refinement design-notes rejects, and it turns a liveness bug into
# a safety one.
o=$(r retry-gap)
expect "a signal inside the gap is not adopted" "$o" "VERDICT=pending"
refute "  the clean comment is not read"        "$o" "VERDICT=comment"
expect "  the baseline is the re-post"          "$o" "trigger=2026-08-19T10:31:00Z"

# Two answers to one round, both naming the current commit. The fence returns
# the newer review and says nothing at all about the older one — there is no
# EXTRA= for a second review, only for a comment. That is measured here rather
# than assumed, because it is the whole reason step 10 stops trusting a single
# review_id= on a round that fired twice: the filter there is an equality test,
# so the review this fence does not name has its findings dropped for good.
# No step-9 row can catch it on its own — both reviews carry the same, current
# commit — which is why step 9 instead gates every clean finish on that sweep.
o=$(r retry-both-answered)
expect "two answers -> the newer review wins"   "$o" "review_id=820"
refute "  the older answer is never mentioned"  "$o" "810"
refute "  and there is no EXTRA= to carry it"   "$o" "EXTRA="

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
