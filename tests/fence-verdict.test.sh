#!/usr/bin/env bash
# Runs the wait-verdict fence against the recorded fixtures in
# tests/fixtures/verdict. Every row of the step-9 decision table that the
# fence can produce has a case here.
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

# --- which trigger is the baseline -------------------------------------------
#
# A verdict from before the newest trigger is not this round's.
o=$(r decoy-compat-trigger)
expect "newer trigger -> pending, not stale"    "$o" "VERDICT=pending"
refute "  does not adopt the older verdict"     "$o" "VERDICT=comment"

# A hand-typed trigger older than the marker must not become the baseline.
o=$(r older-compat-trigger)
expect "older hand-typed trigger loses"         "$o" "VERDICT=pending"
expect "  baseline is the newest trigger"       "$o" "trigger=2026-08-25T09:00:00Z"
refute "  not the older hand-typed one"         "$o" "trigger=2026-08-24"
refute "  no verdict from before the marker"    "$o" "VERDICT=review"
refute "  the previous round's commit is gone"  "$o" "commit=a5eb3169"

# One round later. With the marker as baseline, its bot= filter stays active.
o=$(r older-compat-trigger-review)
expect "the round after converges"              "$o" "VERDICT=review"
expect "  on the marker's own baseline"         "$o" "trigger=2026-08-25T09:00:00Z"
expect "  the marker binds a head again"        "$o" "marker_head=9f8e7d6c"
expect "  and carries its round"                "$o" "round=4"
expect "  the reviewer's own review wins"       "$o" "review_id=950"
refute "  not the previous round's"             "$o" "review_id=800"
refute "  the bot filter is live again"         "$o" "copilot-pull-request-reviewer"

# Marker and hand-typed trigger in the same second: the higher comment id
# wins, whatever its class. Only this case and the next reach that tie-break.
o=$(r same-second-trigger)
expect "same second: the later row wins"        "$o" "VERDICT=review"
expect "  the marker was posted second"         "$o" "marker_head=9f8e7d6c"
expect "  so it carries its round"              "$o" "round=4"
expect "  and its reviewer"                     "$o" "reviewer=codex"
expect "  the bot filter is live"               "$o" "review_id=950"
refute "  the compat row did not anchor"        "$o" "marker_head=none"
refute "  and did not disable the filter"       "$o" "copilot-pull-request-reviewer"

# The mirror: the compat trigger is posted second, wins, and binds no head.
o=$(r same-second-trigger-compat)
expect "same second: a later compat also wins" "$o" "VERDICT=review"
expect "  a compat baseline binds no head"      "$o" "marker_head=none"
expect "  and names no reviewer"                "$o" "reviewer=unknown"
refute "  the marker did not win on class"      "$o" "marker_head=9f8e7d6c"

# --- re-posts and re-takes ---------------------------------------------------
#
# The marker parser ignores a key it does not know, here attempt=.
o=$(r retry-marker)
expect "an unknown marker key is ignored"       "$o" "VERDICT=review"
expect "  reviewer still parses"                "$o" "reviewer=codex"
expect "  head still binds"                     "$o" "marker_head=1a2b3c4d"
expect "  round is not displaced by it"         "$o" "round=3"
refute "  and the key itself is not echoed"     "$o" "attempt="

# A re-post: two triggers on the same head and round, and the second is the
# baseline. Both carry round=3 by hand; the fence does not count rounds.
o=$(r retry-baseline)
expect "the re-post becomes the baseline"       "$o" "trigger=2026-08-19T10:31:00Z"
refute "  not the trigger it re-posts"          "$o" "trigger=2026-08-19T10:00:00Z"
expect "  round comes off the winning marker"   "$o" "round=3"
expect "  and the verdict after it is adopted"  "$o" "review_id=333"

# A signal that lands between the last poll and the re-post predates the new
# baseline and is dropped. This is accepted; see docs/design-notes.md.
o=$(r retry-gap)
expect "a signal inside the gap is not adopted" "$o" "VERDICT=pending"
refute "  the clean comment is not read"        "$o" "VERDICT=comment"
expect "  the baseline is the re-post"          "$o" "trigger=2026-08-19T10:31:00Z"

# A rate limit as the primary line. The fence rewrites `=` to `-` in the
# body's first line and cuts it at 110 characters. The cut lands inside
# `?tab=code-review`, so the assertions use the part that survives, `tab-co`.
o=$(r rate-limit-comment)
expect "a rate limit is a primary comment"      "$o" "VERDICT=comment"
expect "  it carries the comment id"            "$o" "cid=444"
expect "  the pattern's prefix survives"        "$o" "body=You have reached your Codex usage limits"
expect "  the marker still binds a head"        "$o" "marker_head=65d73ddd"
expect "  and the round it was posted for"      "$o" "round=21"
expect "  the body's = became a -"              "$o" "tab-co"
refute "  and the = itself did not survive"     "$o" "tab=co"
refute "  and the body is cut at 110"           "$o" "for details."

# A re-take: a second marker at the same head with a higher round. It takes
# the baseline, and the rate limit before it is not adopted again.
o=$(r rate-limit-retake)
expect "the re-take becomes the baseline"       "$o" "trigger=2026-08-31T10:20:00Z"
refute "  not the trigger it re-takes"          "$o" "trigger=2026-08-31T10:00:00Z"
expect "  and nothing has answered it yet"      "$o" "VERDICT=pending"
refute "  the older rate limit is not adopted"  "$o" "VERDICT=comment"
refute "  and its body is not reported"         "$o" "You have reached"

# One answer later. Only a verdict line carries round=, so this is where the
# re-take's round shows.
o=$(r rate-limit-retake-answered)
expect "a verdict carries the re-take's round"  "$o" "round=22"
refute "  not the round it re-took"             "$o" "round=21"
expect "  the head binding is unchanged"        "$o" "marker_head=65d73ddd"
expect "  and the review after it is adopted"   "$o" "review_id=950"

# Two reviews answer one round. The fence names the newer one only; EXTRA=
# carries a comment and never a second review.
o=$(r retry-both-answered)
expect "two answers -> the newer review wins"   "$o" "review_id=820"
refute "  the older answer is never mentioned"  "$o" "810"

# --- signals that are not this round's verdict -------------------------------
#
# The reviewer's status card is a comment that is neither a verdict nor a
# finding, and the fence skips it. Without jq the stub replays rows that never
# held the card, so the drop itself is asserted in tests/jq-program.test.sh.
o=$(r codex-status-card)
expect "a status card alone -> still waiting"   "$o" "VERDICT=pending"
refute "  the card is not a verdict"            "$o" "VERDICT=comment"
refute "  and its marker is never printed"      "$o" "codex-pull-request-review-summary"

o=$(r codex-status-card-clean)
expect "the clean comment beside it wins"       "$o" "VERDICT=comment"
expect "  by the clean comment's own id"        "$o" "cid=600"
refute "  not the card's"                       "$o" "cid=500"
expect "  with the clean phrase as the body"    "$o" "body=Codex Review: Didn't find any major issues. Chef's kiss."

# The marker's bot= drops every other bot at fetch time.
o=$(r foreign-bot)
expect "foreign bots filtered -> pending"       "$o" "VERDICT=pending"
refute "  no copilot verdict"                   "$o" "copilot-pull-request-reviewer"
refute "  no deploy-preview verdict"            "$o" "cloudflare-workers-and-pages"

o=$(r no-trigger)
expect "no trigger, no verdict"                 "$o" "VERDICT=error reason=no-trigger"

o=$(r untriggered-verdict)
expect "verdict without a trigger"              "$o" "VERDICT=error reason=untriggered-verdict"
expect "  carries the bot line"                 "$o" "bot=comment"

o=$(r untriggered-verdict-review)
expect "the newest untriggered signal wins"     "$o" "bot=review 2026-08-19T10:09:00Z"
refute "  not the older comment"                "$o" "bot=comment"

# --- lost baseline -----------------------------------------------------------
#
# A hand-typed trigger newer than the marker takes the baseline. It carries no
# marker payload, so reviewer, round and marker_head keep their defaults.
# These cases pin the fence's line only. Step 9's adoption gate is not run.
o=$(r foreign-baseline-review)
expect "hand-typed trigger takes the baseline"  "$o" "VERDICT=review"
expect "  the baseline is the compat comment"   "$o" "trigger=2026-09-09T10:44:51Z"
expect "  it binds no head"                     "$o" "marker_head=none"
expect "  and names no reviewer"                "$o" "reviewer=unknown"
expect "  and no round"                         "$o" "round=unknown"
expect "  the review is the reviewer's"         "$o" "login=chatgpt-codex-connector"
expect "  and is addressable by id"             "$o" "review_id=5153256704"
expect "  and names the commit it read"         "$o" "commit=000cac73"
refute "  the marker's head did not leak in"    "$o" "marker_head=deadbeef"

# The same line from a bot nobody configured. A compat baseline has no bot=,
# which disables the fence's filter.
o=$(r foreign-baseline-foreign-bot)
expect "a foreign bot answers the same way"     "$o" "VERDICT=review"
expect "  still an unbound baseline"            "$o" "marker_head=none"
expect "  and the login is the discriminator"   "$o" "login=copilot-pull-request-reviewer"

# A clean comment under the same baseline, with no commit= to compare to HEAD.
o=$(r foreign-baseline-comment)
expect "a comment under a lost baseline"        "$o" "VERDICT=comment"
expect "  binds no head either"                 "$o" "marker_head=none"
expect "  and is addressable by id"             "$o" "cid=5600599999"
refute "  but carries no commit binding"        "$o" "commit="

# A review of another commit. Only commit= differs from the adoptable case.
o=$(r foreign-baseline-stale-review)
expect "a stale review under the same baseline" "$o" "VERDICT=review"
expect "  unbound baseline, as before"          "$o" "marker_head=none"
expect "  and a commit that is not HEAD's"      "$o" "commit=a5eb3169"

# Two reviews after one hand-typed trigger. Only the newest is named.
o=$(r foreign-baseline-two-reviews)
expect "the newest review wins"                 "$o" "review_id=5155000000"
refute "  the older one is not named"           "$o" "review_id=5153256704"

# Two bots, the configured one first. The line names the other bot's newer
# review, and the reviewer's own is absent from it.
o=$(r foreign-baseline-reviewer-then-foreign-bot)
expect "the newest review wins, not the reviewer's" "$o" "VERDICT=review"
expect "  still an unbound baseline"                "$o" "marker_head=none"
expect "  the line is the other bot's"              "$o" "login=copilot-pull-request-reviewer"
expect "  and names the other bot's review"         "$o" "review_id=5153299999"
refute "  the reviewer's review is not named"       "$o" "review_id=5153256704"

# A review in the trigger's own second. The fence selects with a strict `>`,
# so the comment behind it becomes the primary line.
o=$(r foreign-baseline-same-second-review)
expect "a same-second review is not selected"      "$o" "VERDICT=comment"
expect "  the comment behind it is primary"        "$o" "cid=5600599999"
expect "  under the same unbound baseline"         "$o" "marker_head=none"
refute "  the review never reaches the line"       "$o" "VERDICT=review"
refute "  and its id is nowhere on it"             "$o" "5153256704"

# A reaction on the hand-typed trigger. It carries neither login= nor commit=.
o=$(r foreign-baseline-reaction)
expect "a reaction under a lost baseline"      "$o" "VERDICT=reaction"
expect "  binds no head"                       "$o" "marker_head=none"
expect "  and names the trigger it answers"    "$o" "id=5600570017"
refute "  it carries no login"                 "$o" "login="
refute "  and no commit binding"               "$o" "commit="

# The adoptable review, plus a comment from an unconfigured bot as EXTRA=.
o=$(r foreign-baseline-review-extra)
expect "the primary line is still adoptable"   "$o" "VERDICT=review"
expect "  by the configured reviewer"          "$o" "login=chatgpt-codex-connector"
expect "  at the commit in hand"               "$o" "commit=000cac73"
expect "  and a second bot rides along"        "$o" "EXTRA=comment"
expect "  authored by nobody configured"       "$o" "login=cloudflare-workers-and-pages"

# --- other forms and setup errors --------------------------------------------
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
