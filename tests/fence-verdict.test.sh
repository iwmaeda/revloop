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

# The rate limit, as a PRIMARY line rather than as EXTRA=. Until this fixture
# the pattern only ever appeared on the EXTRA= of review-and-comment, so the
# shape step 9's two rate-limit rows actually read was pinned nowhere. It also
# pins two constraints on what a rateLimitPatterns entry may contain, both of
# which the fence imposes and neither of which is obvious from the schema: the
# body's first line has every `=` rewritten to `-`, and it is cut at 110
# characters. A pattern carrying either would match nothing, forever, silently.
#
# THE TWO CONSTRAINTS INTERACT, AND THE OBVIOUS ASSERTION FOR THE FIRST IS
# VACUOUS. This body's `=` sits at `?tab=code-review`, which the 110-character
# cut lands inside: the output ends `?tab-co`. So a refute on `tab=code-review`
# passes whether the gsub is present, correct or deleted -- truncation removes
# the needle before the rewrite could matter, and the assertion pins nothing.
# The pair below is inside the window instead, so deleting the gsub fails it.
# `body-keys` further down does not have this problem: its whole body fits.
o=$(r rate-limit-comment)
expect "a rate limit is a primary comment"      "$o" "VERDICT=comment"
expect "  it carries the comment id"            "$o" "cid=444"
expect "  the pattern's prefix survives"        "$o" "body=You have reached your Codex usage limits"
expect "  the marker still binds a head"        "$o" "marker_head=65d73ddd"
expect "  and the round it was posted for"      "$o" "round=21"
expect "  the body's = became a -"              "$o" "tab-co"
refute "  and the = itself did not survive"     "$o" "tab=co"
refute "  and the body is cut at 110"           "$o" "for details."

# The re-take: a second marker at the SAME head= with a HIGHER round=, opened
# because the reviewer declined the first one. It must take the baseline, and
# the rate-limit comment it steps past must not be re-adopted as the new
# round's verdict — which is the too-old row of design-notes' table, reached
# here by a path no other fixture takes.
#
# WHAT THESE THREE CANNOT SHOW. Step 9's two rate-limit rows read the SAME
# BYTES: the fence's output for a rate limit is identical whether this run
# posted the trigger or inherited it, because the fence has no idea which run
# is reading it. The discriminator is within-run state — did step 7 of this run
# return a TRIGGER= id — and this harness executes no step-9 prose, so nothing
# here can catch a run that takes the wrong row. Nor can anything here catch a
# re-take that fails to advance the round, that skips --max-rounds, or that
# re-takes twice: the two markers below carry round=21 and round=22 because the
# fixture was hand-written that way, and the fence has no round-counting logic
# to get wrong. Those rules live in step 7 and step 9's prose. Saying so is
# worth more than a comment that implies otherwise.
o=$(r rate-limit-retake)
expect "the re-take becomes the baseline"       "$o" "trigger=2026-08-31T10:20:00Z"
refute "  not the trigger it re-takes"          "$o" "trigger=2026-08-31T10:00:00Z"
expect "  and nothing has answered it yet"      "$o" "VERDICT=pending"
refute "  the older rate limit is not adopted"  "$o" "VERDICT=comment"
refute "  and its body is not reported"         "$o" "You have reached"

# The same pull request one answer later. Only a verdict line carries round=,
# so this is the only fixture that can show the number comes off the RE-TAKE's
# marker rather than off the round it re-took.
o=$(r rate-limit-retake-answered)
expect "a verdict carries the re-take's round"  "$o" "round=22"
refute "  not the round it re-took"             "$o" "round=21"
expect "  the head binding is unchanged"        "$o" "marker_head=65d73ddd"
expect "  and the review after it is adopted"   "$o" "review_id=950"

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
# No EXTRA= refute here either, and for the same reason as the one below: this
# fixture carries no comment row, EXTRA= is only ever sourced from one, and a
# refute on an unreachable branch passes whatever the fence does. What the label
# used to gesture at -- that the older review does not come back as EXTRA -- is
# not a thing the fence can do at all: EXTRA= carries a comment and never a
# review. The refute above, on the older review_id, is the one that pins it.

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

# The lost baseline, in the shape step 9's two marker_head=none rows are written
# against. This first fixture is the line iwmaeda/schoolpath#115 actually
# produced on 2026-09-12, with the ids kept and the marker's head= changed to a
# value HEAD cannot share -- the refute below is the point of that change.
#
# A hand-typed `@codex review` newer than the round-8 marker takes the baseline,
# the compat row carries no marker payload, and the parser's defaults survive:
# reviewer=unknown, round=unknown, marker_head=none. The reviewer then answered
# that trigger with a review of the checked-out commit, which is the input the
# adoption row exists for.
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

# The same line with a bot nobody configured. A compat baseline carries no bot=,
# and an empty bot= disables the fence's filter -- so this line is producible,
# and the configured-login test is the only thing between it and the adoption.
o=$(r foreign-baseline-foreign-bot)
expect "a foreign bot answers the same way"     "$o" "VERDICT=review"
expect "  still an unbound baseline"            "$o" "marker_head=none"
expect "  and the login is the discriminator"   "$o" "login=copilot-pull-request-reviewer"

# A clean comment under the same baseline. It carries a login and a cid and NO
# commit= at all, which is why only a review may be adopted: there is nothing
# here to compare against HEAD, and adopting it is design-notes' too-old row.
#
# THIS LINE NOW OPENS THE SELECTION, and it did not when the fixture was
# written. Step 9 declined a wider gate on the arithmetic that a comment is
# printed only when the fence's review set came back empty, so nothing could be
# hiding behind it -- which ignores that `reviews(last:15)` truncates BEFORE the
# Bot and non-DISMISSED filters run. `jq/window-full-of-humans` is the input
# that falsifies it: fifteen human and dismissed reviews empty the review set
# and produce exactly the rows below, with an adoptable review sitting on the
# pull request outside the window. Returned as a P2 (iwmaeda/revloop#31,
# 2026-09). What the gate keys on is now the marker_head=none STATE, not the
# form of the line -- so this fixture's line and the reaction below are the two
# that changed meaning without changing a byte.
o=$(r foreign-baseline-comment)
expect "a comment under a lost baseline"        "$o" "VERDICT=comment"
expect "  binds no head either"                 "$o" "marker_head=none"
expect "  and is addressable by id"             "$o" "cid=5600599999"
refute "  but carries no commit binding"        "$o" "commit="

# The stale half: the same shape, a review of some other commit. The fence's
# output differs from the adoptable case in exactly one field.
#
# TWO step-9 rows are now written against this one line, and the fence cannot
# tell them apart. `commit=a5eb3169` is eight characters of a commit whose
# RELATION to HEAD this line does not carry: an ancestor of HEAD takes the
# foreign-baseline-retake row, and a commit that is absent locally or has
# diverged keeps the abort. The discriminator is `git merge-base --is-ancestor`
# against the REST review list -- a call and a comparison this fence makes
# neither of -- so no assertion here can reach either row. What this fixture
# owns is the input both are written against.
o=$(r foreign-baseline-stale-review)
expect "a stale review under the same baseline" "$o" "VERDICT=review"
expect "  unbound baseline, as before"          "$o" "marker_head=none"
expect "  and a commit that is not HEAD's"      "$o" "commit=a5eb3169"

# Two reviews drawn by one hand-typed trigger, a day apart. The fence names only
# the newest, which is why step 10 sweeps an adopted round instead of reading
# review_id= -- the older one is on the pull request and unnamed here.
o=$(r foreign-baseline-two-reviews)
expect "the newest review wins"                 "$o" "review_id=5155000000"
refute "  the older one is not named"           "$o" "review_id=5153256704"
# No EXTRA= refute here, and its absence is the point. This fixture carries no
# comment row, so the fence's EXTRA= branch is unreachable for this input and a
# refute on it would pass whatever the fence did -- including if the behaviour it
# named broke. The distinction worth keeping: a refute is a guard when the input
# reaches the branch and the branch declines to emit the token, and it is vacuous
# when the input cannot reach the branch at all. The EXTRA=/adoption interaction
# is pinned by `foreign-baseline-review-extra`, which has the comment row.

# Two bots, and the configured one spoke FIRST. A compat baseline empties bot=,
# so the fence's review filter admits every bot and `tail -1` keeps the newest --
# which is the other bot's. The reviewer's review of this very commit is on the
# pull request and is not on this line, so a step-9 gate that tested the primary
# line's login refused the adoption and aborted, on this run and on every rerun
# after it: the abort never reaches step 7's re-take, so the compat trigger stays
# newest and so does the foreign review. The refute below IS the finding.
o=$(r foreign-baseline-reviewer-then-foreign-bot)
expect "the newest review wins, not the reviewer's" "$o" "VERDICT=review"
expect "  still an unbound baseline"                "$o" "marker_head=none"
expect "  the line is the other bot's"              "$o" "login=copilot-pull-request-reviewer"
expect "  and names the other bot's review"         "$o" "review_id=5153299999"
refute "  the reviewer's review is not named"       "$o" "review_id=5153256704"

# The lower bound, from the side that shows it. The review shares the compat
# trigger's own second, and the fence selects with `$2>t` -- strictly -- so it
# is not selected at all and the comment behind it becomes the primary line.
# Step 9's adoption selection keeps that same strict bound deliberately: at the
# measured latency nothing answers a trigger in the second it was posted, so a
# same-second review was drawn by an EARLIER trigger, and admitting it would
# adopt a previous round's review at an unchanged HEAD. This fixture is what
# pins the bound the selection mirrors.
o=$(r foreign-baseline-same-second-review)
expect "a same-second review is not selected"      "$o" "VERDICT=comment"
expect "  the comment behind it is primary"        "$o" "cid=5600599999"
expect "  under the same unbound baseline"         "$o" "marker_head=none"
refute "  the review never reaches the line"       "$o" "VERDICT=review"
refute "  and its id is nowhere on it"             "$o" "5153256704"

# A thumbs-up on the hand-typed trigger. The compat generator emits a reaction
# count like any other TRIG row, so this line is producible -- and it carries
# neither login= nor commit=, which is the whole reason a reaction cannot be
# adopted however clean it looks.
#
# It still opens the selection, and the two facts are not in tension: what is
# adopted comes out of the REST review list, and all the line has to supply is
# the trigger= every verdict form carries. A reaction is printed only when both
# of the fence's sets came back empty, and BOTH can be emptied by the window
# rather than by the pull request -- see `jq/window-full-of-humans`.
o=$(r foreign-baseline-reaction)
expect "a reaction under a lost baseline"      "$o" "VERDICT=reaction"
expect "  binds no head"                       "$o" "marker_head=none"
expect "  and names the trigger it answers"    "$o" "id=5600570017"
refute "  it carries no login"                 "$o" "login="
refute "  and no commit binding"               "$o" "commit="

# The adoptable shape with a second bot talking on the same pull request. The
# compat baseline empties bot=, so the comment filter admits ANY bot -- and the
# EXTRA= that results is authored by one nobody configured. The primary line is
# the reviewer's here; the EXTRA is not, and step 9 says what that costs --
# nothing, because it decides no verdict. What the step does with it is compare
# login= FIRST and only then match the fetched body, which is an ordering this
# line cannot show either.
o=$(r foreign-baseline-review-extra)
expect "the primary line is still adoptable"   "$o" "VERDICT=review"
expect "  by the configured reviewer"          "$o" "login=chatgpt-codex-connector"
expect "  at the commit in hand"               "$o" "commit=000cac73"
expect "  and a second bot rides along"        "$o" "EXTRA=comment"
expect "  authored by nobody configured"       "$o" "login=cloudflare-workers-and-pages"

# WHAT THESE NINE CANNOT SHOW. The fence's output is IDENTICAL for an adoptable
# and a non-adoptable review whenever the short commit= agrees, because the
# discriminator is the forty-character commit_id and the configured login -- and
# the fence emits the first truncated to eight characters and does not read the
# second at all. `foreign-baseline-stale-review` differs from
# `foreign-baseline-review` only because the fixture was written with eight
# different characters; a commit sharing HEAD's prefix produces the same line as
# the adoptable case, and step 9's check (e) is what separates them.
#
# Nor can any of them show the adoption GATE, and that is now structural rather
# than incidental. The gate is a selection over the REST review list -- a call
# this fence never makes -- so no fixture here can make an adoption fire or
# refuse one. What these nine pin is the line that reaches step 9, which is the
# input the gate is written against and the whole of what this harness owns.
# `foreign-baseline-reviewer-then-foreign-bot` is the sharpest of them: it shows
# that the reviewer's review can be absent from the line while present on the
# pull request, which is exactly why the gate may not be a test on the line.
#
# Nor can `foreign-baseline-review-extra` show what step 9 does with that EXTRA=.
# The fence emits it either way; whether a foreign bot's body is matched against
# the configured reviewer's rateLimitPatterns, in which order, and what that match
# may decide, is prose in step 9 and not a field on this line.
#
# Nor can any of them reach the foreign-baseline-retake row, and the reason is
# the same one enlarged. That row fires when the selection at HEAD is empty but
# the same selection relaxed to a STRICT ANCESTOR of HEAD is not, so its two
# discriminators are `git merge-base --is-ancestor` and the REST review list --
# neither of which this fence runs. `foreign-baseline-stale-review` is the line
# it is written against, and that line is byte-identical for an ancestor, a
# diverged commit and one absent locally, which are three different rulings.
#
# Nor can anything here catch an adoption that spends --max-rounds, that numbers
# its replies with an integer instead of adopted-<review_id>, that converges the
# loop, or that merges -- nor a re-take that reads a review instead of
# discarding it, nor a report that omits the discarded review_id=. Those rules
# live in steps 7, 9, 10 and 11, and this harness executes no prose.

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
