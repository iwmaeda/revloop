# Changelog

All notable changes to this project are documented here.

**Fence changes are called out explicitly.** The shell fences in
[`procedures/remote-loop.md`](procedures/remote-loop.md) are matched by permission rules on their exact
text, so editing one costs every user a single re-approval. See
[`docs/permissions.md`](docs/permissions.md).

**Entries before 0.7.0 name `commands/remote-loop.md` and `commands/local-loop.md`.** Those files moved
to [`procedures/`](procedures/) in 0.7.0 and the historical names are left unlinked rather than
repointed, because an entry should say what was true when it was written.

## [Unreleased]

### The lost-baseline recovery was promised by three places and reachable from none

**The rule was right and the graph was missing an edge.** Step 7 says it twice and step 9's
`marker_head=none` row says it again: when a hand-typed trigger takes the baseline, this run aborts
and **a later run re-takes it with an ordinary trigger in step 7**. Step 7 also says how that later
run may know the baseline is foreign — "**ask the fence**: fire step 8 once and read what it reports",
because a verdict line is the only positive evidence and a `pending` line carries none. But step 8's
answer goes to **step 9**, and step 9's row was an abort with no way back to 7. So the run that
**learns** the baseline is foreign was the run that **had to stop**, and the later run that would act
on it was every run, forever.

**Measured three times, and the third pair is what made it undeniable.** `iwmaeda/revloop#13`
(2026-08) recorded it in this repository's own field notes — "the documented recovery (fire in step 7,
re-run step 8) is unreachable without raising the cap". Then on 2026-09-12, two projects running
`remote-codex-loop` at 0.10.0 aborted without opening a round: `iwmaeda/schoolpath#115`, where review
`5153256704` sat on commit `000cac73` — the commit checked out — and the run's own report said "this
review is unread by this loop and I did not read it"; and `MIRock-jp/hippoblogs#106`, where review
`5153219587` sat on `6d1f8eb0` and the run never even reached step 8. In both, the reviewer had
answered, at the commit in hand, and the loop threw the answer away.

**Now: step 9 adopts the review instead of discarding it**, under a new `foreign-baseline-adopt` row.
A `review` line carrying `marker_head=none` opens the question; what answers it is a **selection over
the review list** — step 10's existing read, kept to the reviews submitted strictly after that line's
`trigger=`, by the resolved reviewer with a trailing `[bot]` stripped from both sides, whose `state`
is not `DISMISSED`, and whose forty-character `commit_id` equals `git rev-parse HEAD`. Adopt if the
selection is non-empty. **The `state` narrows that selection and does not decide the round**: the
fence drops it from the line, but the list read returns one for every review it names, so the
selection makes the one exclusion step 10's sweep also makes — `DISMISSED`, whose author withdrew
it — and everything else a state can say stays step 10's, where its table already fails closed.
It is a row name rather than a `reason=`, because it is not an abort — the split 0.10.0
drew between `reviewer-rate-limited` and `rate-limit-retake`, applied again.

**The gate is a selection and not a test on the fence's line, because a test on the line reintroduced
the defect this section is about.** With a hand-typed trigger holding the baseline the marker carries
no `bot=`, so the fence's filter admits **any** bot and its line names the newest review by anyone. A
second bot that reviews after the configured reviewer therefore takes the line, the login test fails
on it, and the round aborts — **and an abort never reaches step 7's re-take**, so the compatibility
trigger stays newest, that bot's review stays newest, and every later run reproduces the same line and
the same abort. The self-sustaining no-op, one layer down, inside the row written to end it. Returned
as a P2 on `iwmaeda/revloop#31` (2026-09) against the commit that introduced the row.

**Reading is not racing, which is the whole of the safety argument.** The abort is justified by "a
lost baseline usually means somebody is driving the pull request by hand, and racing a person for the
newest comment is the runaway itself" — a rule about what may be **posted**. An adoption posts
nothing, opens no round and spends none of the reviewer's budget. **And what the abort protects is the
trigger's binding, which the adoption does not use**: "the compatibility class anchors a baseline; it
cannot bind a verdict to a commit" is true of the trigger and false of the review. A marker's `oid=`
is what this loop **asked about**; `commit_id` is what the reviewer **looked at**, and the second is
the better of the two whenever only one exists.

**The lower bound is the fence's, and the selection states it rather than inheriting it.** The fence
selects reviews with `$2>t` against the winning trigger; the winning trigger is the compatibility row,
so it is newer than every marker, or a marker would have won — and the `databaseId` tie-break can only
move a same-second marker **below** it. So `review` > winning trigger ≥ newest marker, strictly, and a
previous round's review cannot be adopted **by construction** rather than by a comparison somebody has
to get right. That is the too-old row of `docs/design-notes.md`, closed without a timestamp test. A
selection reading REST rather than the fence's line has to carry that bound itself, so it does:
**strictly after `trigger=`**, the same comparison spelled against a second API. **It is inclusive in
step 10's sweep and strict here, and the difference is whose trigger bounds each.** That sweep is
bounded by a round's own first trigger, where a review sharing its second is a review this loop asked
for; this one is bounded by somebody else's, and at the latency `reviewers/codex.md` measures — 2:46
at the fastest of twenty-seven rounds — a review sharing **its** second was drawn by an earlier
trigger. Admitting it would adopt a previous round's review at an unchanged HEAD, which is the row
above, reopened by the fix meant to respect it.

**The adopted round's scope is `adopted-<review_id>` and deliberately not a number.** An adoption
writes no trigger marker, so step 7's count-plus-one is untouched and the next ordinary trigger takes
the number it would have taken anyway; and a token outside the integer sequence cannot collide with
one. Both numbers that were available are wrong in ways this file has already paid for: reusing the
**newest marker's** `round=` lets an earlier round's reply satisfy step 11's guard and **silently
suppress** the answer this round owes — the invisible direction, and the reason the round is part of
the reply identity at all — while **count-plus-one** gives two different rounds the same scope. It is
also PR-derived, so a session that dies part-way through answering is resumed by a run that computes
the same token and posts no duplicates, which is step 7's own argument about budgets a restart refunds.
**The id is the review each finding came from**, not the round's newest: an adopted round can read
several reviews, and the newest is a value the pull request can change between two runs — a third
review arriving makes a different id newest, the resumed run computes a different token, and every
reply is posted again. A finding's own review never changes.

**An adoption does not spend `--max-rounds`, and charging it would have shipped the fix broken.**
The cap's own justification is that step 7 "is the only place a round is opened" and that when it
fires "the wait, the trigger and the reviewer's budget are all still unspent" — an adoption uses none
of the three. And `MIRock-jp/hippoblogs#106` is precisely a pull request **at** the cap with a standing
unread review, so a charged adoption is refused exactly where it is needed. It stays bounded anyway:
the work an adoption produces has to pass through step 7 to become a new review, and step 7 is capped
as always.

**An adopted round can never converge the loop and never merges.** It has no edge into step 12, so
`rigor-levels.md`'s sufficiency test does not run on it — which is that page's "at every edge into the
report step, **and nowhere else**" honoured rather than bent, because there is no such edge here. The
reason is not bookkeeping: a convergence there would rest on a review that **may be answering a
request nobody in this loop composed**, whose focus is unknown and may be arbitrarily narrow, and
under `--auto --merge` that is a merge on a stranger's question. The round ends by returning to step
7 — through step 3 when there are fixes, straight there when every item was declined or accepted — to post the ordinary
re-take.

**That re-take is the point, and it is what closes the missing edge.** The adoption supplies the
positive evidence step 7 requires **and** consumes the verdict instead of discarding it, so the "later
run" becomes this run. **The narrowing that keeps the racing-a-person argument intact** is that a
same-run re-take is licensed **only** by an adopted review — only once a verdict **bound to the commit
in hand** has been read. Every other shape of lost baseline keeps today's abort: a `comment`, a `reaction`,
a `pending`, and a `review` line whose selection comes back empty — no review of this commit, by this
reviewer, after this trigger. A foreign bot's review on the line is **not** one of those shapes on its
own, which is the whole of the correction above: what decides is what the list holds behind it. So a
run arriving while somebody is still driving the pull request by hand still stops and hands it to
them, and a run whose reviewer has already answered no longer stops beside the answer.

**What the re-take is _not_ licensed by is a claim about whose request drew that review**, and an
earlier spelling of these rows made one. "Submitted after the hand-typed trigger" orders two events;
it does not make the trigger the cause. A marked request of revloop's own can still be outstanding at
the commit in hand when a person's trigger lands, so the adopted review may be the answer to **that**
one while the person's request is still in flight — returned as a P2 on `iwmaeda/revloop#31`
(2026-09), and the same thing step 9 already said about a rate-limit notice arriving as `EXTRA=`.
**The ownership is now printed and never compared.** The report names a `revloop:trigger` marker bound
to the adopted `commit_id` that predates the winning trigger, says the hand-typed request may still be
in flight, and says the re-take may draw a second review of that commit. **Gating on it is declined,
because the gate never clears**: a comment already posted is immutable, so the refusal would repeat on
every later run, and on an adopted round with nothing to fix nothing in the loop can move HEAD to make
the question a different one — the permanent block these rows exist to remove, re-entered by the guard
meant to prevent a race. What pays for that instead is bounded and doubled up: the adopted round may
neither converge nor merge **whoever** asked, and **the round a same-run re-take opens now runs step
10's review sweep** on its single trigger, so a second answer at the same commit is read rather than
dropped for the life of the pull request. The residue is one round, which `--max-rounds` bounds and
the pull request shows.

**Step 10 sweeps an adopted round _instead of_ reading its `review_id=`, bounded by the winning
trigger rather than by a marker.** There is no marker to read a lower bound off, and a hand-typed
trigger can draw more than one review over hours or days while the fence names only the newest — so a
round trusting `review_id=` alone would answer the last of them and leave the rest unread. That is the
orphaned-review shape with somebody else's trigger in place of the re-post. **"Instead" is the word
that was missing, and doing both was a defect.** An adopted review satisfies every filter of that
sweep by construction, so a round that ran the direct read **and** the sweep read one review twice —
and while the fixes are idempotent and step 11's guard stops the replies duplicating, **the findings
reach the grader twice and nothing makes two rungs for one finding agree**: one copy can land above
the acceptance floor and one below, after which the bucket a finding goes into depends on which copy
was read. The bucket record `rigor-levels.md` re-opens under a risen ceiling doubles with it, and so
does every count in the report. Returned as a P2 on `iwmaeda/revloop#31` (2026-09).

### A run at the round cap can still read the pull request

**0.10.0 drew the read/post line for the runaway invariant and drew it nowhere else.** That release
established that the invariant "governs what may be **posted**, never whether the pull request is
**read**", and called the opposite reading a block that "becomes permanent by construction".
`--max-rounds` is the other thing that can refuse a trigger at step 7, and it was still ending the
run: the cap fired before step 8, so a pull request whose marker count had reached the cap could not
read a verdict standing at its own HEAD, could not answer findings already on it, and could not report
a round that was already clean. **Re-running the command was an idempotent no-op abort**, against a
command file that promises re-running it resumes.

**Measured on `MIRock-jp/hippoblogs#106`**: five markers, `--max-rounds` resolving to 5, and two
invocations four days apart producing the same `reason=max-rounds` with nothing posted — while a
review of the checked-out commit sat unread. The run also skipped step 3, so no verify command ran
either; the report named the cap and nothing else.

**Now the cap refuses the trigger, not the run.** At the cap this step posts nothing and carries the
standing `SINCE` into step 8. `reason=max-rounds` — same spelling, one event, one grep — fires when
step 7 is asked to post and the wait produced nothing to read.

**What "one chunk" bounds is a chunk of silence and not a poll, which is the one thing the first
draft of this rule left unsaid.** Two of step 9's rows send a **verdict** back to step 8 — the
mismatched-`trigger=` row, which allows two consecutive re-fires, and the ancestor row, which allows
one — and neither is suspended at the cap. A mismatched or ancestral verdict **exits the fence on its
first poll**, so it burns no wall clock and accrues no chunk; the cap is bounding the wait, and those
re-fires do not wait. Written the other way the rule would have been worse in both directions: it
would abort a capped run on the first foreign comment that happened to land during its poll — a
stranger's timing deciding this run's outcome — while claiming to save a cost the re-fire does not
incur. What the cap still forecloses is reaching `pending` by that path, and the re-post row with it:
at the cap there is no second trigger of any kind.

**The wait is bounded at one chunk, and the bound comes from what the question is.** A capped run is
not waiting for an answer to a trigger of its own; it is asking whether an answer is **already there**,
and step 8 answers that on its first poll — a verdict that exists exits the fence at once, and only
silence costs the full 480 seconds. A `pending` in any flavour aborts immediately: no re-fire, no
re-post, nothing charged against `--timeout`, nothing counted toward the floor of three. **Teaching
the fence a poll-once mode was the alternative and costs every user a re-approval**, which is not
worth eight minutes — and the eight minutes are recoverable, because a slow verdict landing after the
run gave up exits the next invocation's first poll immediately.

**Two states still abort with no wait at all.** When this run has already classified a verdict on the
baseline standing now — whether that baseline is the newest marker or a hand-typed trigger an
adoption read — because nothing new is standing and waiting would re-read the verdict just acted on,
which is the too-old direction. That covers every arrival from step 11 and from the
`rate-limit-retake` row, so both series this step already bounds still stop at the cap rather than
buying a chunk each. **That one is within-run state the fence never sees**, the same class as the
discriminator the rate-limit rows turn on, so no test can pin it and the procedure says so where a
reader will look. And when step 7's marker read exited non-zero, which the existing rule already
covers: an unanswered question is not a licence.

**The abort that does fire now carries a diagnosis**, because `reason=max-rounds` on its own is not
actionable on a pull request that can never gain a round: the cap, its `source`, the marker count it
was measured against, the remedy, and — under this change — what the run did before it met the cap,
since a capped run may now have read, replied and pushed.

**And the cap that fired had been halved without anybody being told.** `thorough` carries the numbers
the two procedures held as builtins and is no longer the default, so a repository that configured no
cap went from 10 to 5 on the pull-request loop at the release that gave the level the number. **The
default is not changed back** — the level owns the cap, and a level that leaves `medium` acceptable
has less left to converge over — but three things now say so: step 1 prints a line naming
`defaults.maxRounds` whenever the cap's `source` is `rigor`, the abort names the same key, and
`docs/configuration.md`'s `Built-in` column no longer prints `10` and `5` with a paragraph underneath
taking them back. **revloop's own `.revloop.json` pins `maxRounds: 10`**, which is why the repository
that shipped the halving is the one that could not see it.

**A rate limit riding beside an adopted review still aborts nothing, and both reasons 0.10.0 gave for
that are now repaired rather than repeated.** The first said the trigger is by definition not one this
run posted, which a garbled own marker falsifies. The second said a reviewer that answered was not out
of quota when it answered, so a notice beside its review is **stale** — but the fence takes the newest
bot comment after the trigger exactly as it takes the newest review, so the notice can be **newer**:
the reviewer answered, and then ran out. Returned as a P2 on `iwmaeda/revloop#31` (2026-09), asking
that the re-take be suppressed on such a notice. **Declined, because the suppression would be keyed to
a comment that never expires**: it stays the newest bot comment, the review stays the primary line, and
the compatibility trigger stays newest **because** the re-take was suppressed — so every later run
suppresses it too and no marker of this loop's reaches the pull request again. Firing the re-take is
what ends the foreign baseline; the reviewer's reply then lands on a trigger this run posted, step 9
aborts `reviewer-rate-limited`, and a later invocation reaches `rate-limit-retake` like any other
rate-limited round. A spent round is bounded, visible and recorded; the block would be silent and
permanent. **The bounded version — suppress once, license the re-take later by looking for this loop's
replies under the adopted review — is named in the step and declined there too**: an adopted review
with no findings posts no replies, so the permanent block survives inside it, and it would make the
reply marker answer a second question about run state one change after `iwmaeda/revloop#29` spent
three rounds getting it to answer exactly one. **What the notice does change is the report**, which now
prints whose notice it is and whether it is newer than the review adopted, comparing `login=` before
matching `rateLimitPatterns` against the fetched body.

**No fence changed and no re-approval is owed.** `tests/fence-hashes.txt` is byte-identical, all four
hashes unmoved, which is the evidence for that sentence rather than memory. `docs/permissions.md` is
unchanged too: the adoption's review list read and the sweep are both step 10's existing call, the
`commit_id` fetch is step 9's own, and the reply POST is step 11's, so no new command string exists to
grant.

**Still unexercised**, and `## Unexercised paths` carries all of it: no run has taken the adoption row
under the procedure, none has adopted a review the fence did not name, none has performed the same-run
re-take, none has fired step 8's single chunk at the cap, and none has reached the adoption row from a
**garbled own marker** rather than from a foreign baseline — the shape a focus carrying the literal
`revloop:trigger` produces, where the repair is right and only the report's wording could be wrong.

**Nine new fixtures pin the fence lines these rows are written against** — including the one
`iwmaeda/schoolpath#115` actually produced — plus a foreign bot's review under the same baseline, a
comment carrying no commit binding, a review of another commit, two reviews drawn by one hand-typed
trigger, a thumbs-up on the hand-typed trigger, an adoptable review riding beside an `EXTRA=`, **the
reviewer's review followed by a foreign bot's**, and **a review sharing the compatibility trigger's
own second**. **Two of them pin shapes nothing had predicted.** The compatibility baseline empties the
fence's `bot=`, so its comment filter admits any bot and the `EXTRA=` beside an adoptable review can
be a deploy bot's — which costs nothing, because that line decides nothing. And its **review** filter
is empty for the same reason, so the primary line can name a second bot's review while the reviewer's
own sits behind it; that fixture's `refute` on the reviewer's `review_id=` is the defect the selection
answers. The last of the nine shows the fence declining a same-second review, which is the bound the
selection mirrors.
**The fixtures cannot pin which of the two `marker_head=none` rows step 9 takes**, and that is now
structural: the discriminators are a forty-character `commit_id` and a configured login taken from a
**REST call the fence never makes**, so no fixture can make an adoption fire or refuse one. What they
pin is the line that reaches step 9. The test file says that where somebody will read it.
**Three rows now**, since the round below added one, and the sentence is corrected in place rather
than left to read as a count the file no longer keeps.

### The adoption's own recovery could be interrupted, and the window's own filter could hide it

**Both are the same no-op, one layer down inside the rows that remove it**, returned as P2s on
`iwmaeda/revloop#31` (2026-09) against the commit that introduced them. **No fence byte moves for
either**: `tests/fence-hashes.txt` is byte-identical, all four hashes unmoved, `docs/permissions.md`
is untouched, and both reads either fix needs are calls the procedure already makes.

**An adopted round that finds something to fix pushes the fixes before it re-takes the baseline.**
The order is step 11 to step 3 to the push, and step 7 posts the re-take after that — so a run that
dies in the gap leaves HEAD on the fix commit while the adopted review is bound to its parent. The
selection requires `commit_id` equal to `git rev-parse HEAD` in full, so it comes back empty, the
`marker_head=none` abort fires, and **an abort never reaches step 7** — the hand-typed trigger stays
newest, that review stays newest, and every later run reproduces the same abort. The fixes are
pushed and the loop can never open a round again.

Step 9 now carries a **`foreign-baseline-retake`** row, decided by the **ancestor-relaxed
selection**: the adoption selection with exactly one condition changed, `commit_id` a **strict
ancestor** of HEAD rather than equal to it. Non-empty and the re-take happens in this run with **no
read in front of it** — the ancestor review's findings are discarded unread and named in the report,
which is the ruling the ancestor row already makes for this loop's own baseline. **What licenses the
trigger is that nothing standing can bind a verdict to HEAD**; that is the adoption row's own
sentence, and it is what keeps the racing-a-person argument intact. It is deliberately **not** the
claim that nobody asked about that commit — a hand-typed trigger binds no commit, so it can never be
said to have asked about one rather than another, and this row carries the same in-flight cost the
adoption row prices. Whether this loop's replies already sit under that review is
**printed and never compared** — a gate on them would make the `revloop:reply` marker answer a second
question about run state, one change after `iwmaeda/revloop#29` spent three rounds getting it to
answer exactly one, and it would rest on an ordering this procedure nowhere states.

**The invariant's exceptions go from four to five**, three of them recovered inside the run, and the
count is corrected in step 7, in `## Notes`, and in `.agents/skills/revloop/SKILL.md`. Only the first
two of the three fire at an unchanged HEAD: the ancestor re-take fires precisely **because** HEAD
moved.

**The second defect is one wrong step in an arithmetic.** Step 9 declined to open its selection on
the `comment` and `reaction` lines, reasoning that the fence prints those only when its review set
came back empty, so the `reviews(last:15)` window could not be hiding a review — a review that falls
out of it needs fifteen newer ones, and all fifteen would be newer than the trigger too. **That
assumes the fifteen are reviews the fence would have kept.** `reviews(last:15)` truncates on the
**server** and `select(.author.__typename=="Bot")` and `select(.state!="DISMISSED")` run **after**
it, so fifteen newer **human or dismissed** reviews fill the window with rows the filters then drop.
The review set is empty, the fence prints a `comment` or a `reaction`, and the adoptable review is
the sixteenth — on the pull request, inside the REST list the selection reads, outside the window the
fence looked in. The gate is now keyed to the `marker_head=none` **state** rather than to the
`review` **line**, so all three verdict forms open it. **What may be adopted has not widened**: only
a review can be, because only a review carries a commit binding.

New fixture `tests/fixtures/jq/window-full-of-humans` puts fifteen human and dismissed reviews
through the fence's own jq program and gets **no `review` row**; its output is byte-identical to
`foreign-baseline-comment`, which is the point — the fence cannot tell such a pull request from one
with no review on it at all. **It cannot show the truncation itself**, because a payload cannot hold
the node the query never fetched, and the test file says so. Widening the window instead was declined
with the cost: it moves fence bytes, so every install owes a re-approval, and it buys a boundary
rather than a proof. **One sub-case stays unrecoverable** and is disclosed in `## Unexercised paths`:
a full window with no bot comment and no reaction returns `pending`, which carries no marker fields,
so the run cannot learn the baseline is foreign at all.

`foreign-baseline-stale-review` now stands for three rulings rather than one — an ancestor, a
diverged commit and one absent locally produce the same line — and `tests/fence-verdict.test.sh` says
that where somebody will read it, alongside a vacuous `refute` removed rather than added.

## [0.10.0] - 2026-09-12

### A rate-limited round is recoverable by a later run

**The bug was an enumeration gap, not a wrong rule.** `## Notes` has always stated the runaway
invariant as "never re-fire the trigger without new commits — **unless nothing of yours can still bind
a verdict**", and a reviewer answering with its quota notice is exactly that: the trigger was
answered, and answered by declining to read the diff. But step 7 enumerated only **two** states that
end the premise — no verdict this run classified, and a newer trigger taking the baseline — and step
9's rate-limit row said "do not retry" with no recovery beside it. Because the remote invariant is
anchored to a marker on the pull request rather than to the session, that left a rate-limited round
**permanently unrecoverable**: re-running after the quota came back aborted again, at an unchanged
HEAD, forever. The only exits were pushing a commit or hand-typing the trigger.

Recorded twice against this repository before it was fixed (`iwmaeda/revloop#13`, 2026-08): a
`rate-limit-abort` at round 21, then, twenty minutes later, "step 7's runaway invariant forbade a
round-22 trigger, so no round was spent". `local-loop.md` had closed the same hole on its side by
declaring its invariant within-run only; the pull-request loop never got the equivalent.

**Now: the run that meets the reply still aborts, and a later run re-takes the trigger.** The
discriminator is who posted the trigger the fence is watching — a run that arrived on a standing
baseline it did not create opens a **new** round with an **ordinary** trigger, no `attempt=`, at the
same HEAD, exactly as the lost-baseline re-take already did. **The bound needs no counter**: after the
re-take the trigger is one this run posted, so a second rate limit takes the abort row. And because a
re-take opens a round, `--max-rounds` already bounds a series of them — a pull request that keeps
answering rate-limited stops at `reason=max-rounds` instead of re-taking forever.

**Two names, and the split between them is deliberate.** The abort is `reviewer-rate-limited`, which
is the token `local-loop.md` already used for the same event — one event, one spelling, one grep
across both loops. The re-take is `rate-limit-retake`, a row name rather than a `reason=`, because it
is not an abort. **The abort names the state the reviewer is in; the re-take names the act this run
took** — the same split as `foreign-baseline` against the lost-baseline re-take.

**One prose fix underneath all of this is worth reading on its own.** Step 7 never said what a run
does when the invariant blocks it, and the measured failure is an agent treating it as a stop: the run
above was refused a trigger, spent no round, and reported the invariant as the blocker and nothing
else. A run that ends there never reaches step 9, which is where the answer to the standing trigger is
classified and where the only recovery from a rate limit lives — so the block is permanent by
construction, whatever the reviewer has since said. The step now says outright that the invariant
governs what may be **posted**, never whether the pull request is **read**. That is a rule the
resumed-run `SINCE` paragraph already assumed rather than a new licence, and it is the load-bearing
half of this change: without it the new row is unreachable and the bug survives its own fix.

**The `EXTRA=` ruling splits the same way and for the opposite reason.** A rate limit riding alongside
a `review` still aborts the run that posted the trigger, but on a standing one it aborts nothing:
that quota block is the round's history, and aborting again strands a real review unread on a pull
request whose HEAD cannot move until somebody reads it. **The re-take never reaches that case** — a
review on the primary line is the reviewer having answered, so the premise was never in question.

**Both READMEs described the recovery as picking the same round back up, and it does not.** The
re-take opens a **new** round: `round=` advances and `--max-rounds` is spent, which is the bound
`docs/design-notes.md` already rested the re-take's safety on — so the two files disagreed about the
same fact from the day this shipped, and the one a user reads first was the one that was wrong.
Returned as a P2 on `iwmaeda/revloop#29` (2026-09) and corrected in both.

**No fence changed and no re-approval is owed.** `tests/fence-hashes.txt` is byte-identical, all four
hashes unmoved, which is the evidence for that sentence rather than memory. Everything here is prose,
three new fixtures, and their assertions.

**Still unexercised**, and `## Unexercised paths` says so: no run has performed the re-take against a
live reviewer. The fixtures pin that a rate limit reaches step 9 as a primary `VERDICT=comment` — a
shape nothing pinned before, since the pattern had only ever appeared on an `EXTRA=` — and that a
re-take marker at an unchanged `head=` with a higher `round=` takes the baseline while the older
rate-limit comment is not re-adopted. **They cannot pin which of the two rate-limit rows step 9
takes**, because the discriminator is within-run state the fence never sees and its output is
byte-identical either way. The test file says that where somebody will read it.

### A re-run now resumes at the standing review instead of re-doing the round

**The preamble already promised this.** "**Every step checks whether it is already done**, so an
interrupted run resumes with the same command" was true of step 2, true of step 6, emergent for steps
4 and 5, and **false of step 3**, which carried no such check at all — while `## When to run it` said
"the command decides which step to resume from" and the command file handed the sentence straight back
to the procedure. Nobody decided. So a run re-invoked on a pull request whose review was already
waiting paid the entire resolved `verify` list, the untracked-file whitespace preflight and a
repository-wide definition sweep — over a `git diff HEAD` and a `git status` that were both empty —
before step 8 made the one call that would have told it a verdict was already there. It then had to
report that "the pass ran and what it changed", which such a pass cannot honestly say.

**Step 3 now checks, on this run's first arrival only.** When the branch has an upstream, the tree is
clean, and **local HEAD equal to the pull request's own head sha** — all three read off step 1's
local-state line — it skips itself, step 4 and step 5 and goes to 6. Nothing is uncommitted, so
step 4 has nothing to stage; nothing is unpushed, so step 5 is `Everything up-to-date`; and the
verify commands are a pre-push gate over a push that is not
happening. `rigor-levels.md` charges sweeps to "every class **this run fixed**", so the sufficiency
test is owed nothing either. **The condition is which edge you arrived on, not what the tree looks
like** — step 11 sends a round back to step 3 _to make the fixes_, and at that moment the tree is
clean and level with its upstream too, so a check written on tree state alone would have skipped the
fix pass and converged having changed nothing.

**What the skip gives up, step 7 takes back.** A first run on a branch pushed by hand arrives in the
same state, and so does a run whose HEAD was pushed from outside the loop onto a branch this loop
already drove; in both, the pre-trigger sweeps are the whole of this loop's "fire with fewer defects"
argument. Step 3 cannot tell either case from a resume — telling them apart means reading the pull
request, and step 7 is the first step allowed to — so step 7 decides it from the marker it already
reads: **if step 3 skipped itself and no marker on the pull request carries a `head=` equal to the
current HEAD, it goes back to 3 before composing a trigger.** A marker naming this commit is the
record that this loop swept it, so neither re-take drags the sweeps back in — both open a round at a
HEAD an earlier marker already names — and the path cannot loop because the return is not a first
arrival.

**That condition was a marker _count_ first, and a count was too narrow.** Zero markers means a pull
request that has had no round at all, so it caught the branch adopted by hand and missed the commit
pushed from outside the loop onto a pull request that already carries markers: clean and level on
first arrival, so step 3 skips; a count that is not zero, so the backstop stays silent; a HEAD no
marker names, so the invariant permits the trigger — and the reviewer reads a commit no verify command
and no sweep has touched. **The justification is what gave it away**: "every later round's change was
swept by the pass that produced it" is true only of a commit this loop produced, which is exactly what
an outside push is not. Returned as a P2 on `iwmaeda/revloop#29` (2026-09), and with it the
concession in `## Unexercised paths` that called the unswept outside push "the same trust every
ordinary round already places in the push that preceded its trigger" — an ordinary round's push is
preceded by step 3, so it was not the same trust.

**Step 11 reads before it writes, which closes the one real idempotency gap.** "Reply to every
finding" had no guard: the list read with `select(.in_reply_to_id==<commentId>)` ran only _after_ the
POST, as a receipt for GitHub returning 404 on a freshly created reply. **A round is not one run.** A
session that answered five of eight findings and died left the next invocation reading the same review
from the same `review_id=` and posting five duplicates — near-identical duplicates, since the reply
opens `Fixed in round <N> (<sha>).` and neither the round nor the sha had moved. That is the argument
step 7 spends a paragraph on for triggers — a budget kept in the session is a budget a restart refunds
— applied to the other thing this loop writes on a pull request, where it had never been made. It
runs first now, and it matches two things: the finding id, and a `revloop:reply` marker carrying this
round's `round=`. **Two drafts of the identity were wrong in the same way before that.** The first
matched id and author, on the argument that `in_reply_to_id` already anchors a reply so no marker was
needed — which answers the wrong half: `in_reply_to_id` says **which finding** a reply is under and
nothing about **what kind of reply it is**, and authorship cannot close that gap because the account
driving this loop is a person who also comments by hand, whose own "I'll look into this" matched both
tests. The second kept the author as a second bound beside the new marker, and that failed the case
the marker was introduced for: the account a run carries is whoever posted the trigger, so a round
Alice opened and Bob resumed compares Bob's own marked replies against Alice, matches nothing, and
posts them again on every resume. Both returned as P2 on `iwmaeda/revloop#29` (2026-09).

**A marked reply is a revloop reply whoever posted it**, which is the right answer for two people
driving one pull request, and it is the trigger side's rule applied to the other artifact: identify
what this loop wrote by a string it wrote, never by who wrote it. The round scope is the second
bound, so a rising-ceiling re-open still gets the reply it is owed. **`AS=` goes with it** — step 7
carried the posting account for exactly one consumer, and with that consumer gone it would be a key
with no consumer.

**That rule was then broken in the commit that stated it**, and it is recorded rather than quietly
repaired: the same change added `pr_ref=` to step 1's new read with nothing anywhere consuming it, and
it could never have had a consumer, since `gh pr list --head` selects on the head ref and the returned
pull request's `.head.ref` is the current branch by construction. Reported as a P2 on
`iwmaeda/revloop#29` (2026-09) and removed.

**Step 1 says where the run stands, and asks GitHub for the half that is GitHub's.** One line — tree
clean or dirty, ahead/behind the upstream, the open pull request — from `-b` added to the `git status`
it already ran, plus a second line comparing local HEAD against `pr_head=`, read from
`repos/{owner}/{repo}/pulls/<n>`. A `git fetch` runs ahead of both. **The object ids are compared in
full and shortened only to print** — every other head comparison here is short-8 because it compares
a value this loop wrote against another it wrote, and this one compares against GitHub's answer.
**Step 11 re-reads `pr_head=` before it may report a convergence**, because step 1 measured it before
a wait that runs to `--timeout` or twice it, and nothing else on the clean path looks at the pull
request's head again: a third party pushing inside that window leaves every later check agreeing, and
the round reports a convergence over a review of the commit it started on. That is
`reason=pr-head-advanced`, and it aborts rather than opening another round — the same ruling a lost
baseline gets, because a loop that answers somebody else's push by triggering again is racing a
person. The matching re-read before the trigger is **declined** and says so: that window ends in step
9's `128` or `1` row, both of which abort already — **on a corrected reason**: only a `review` carries
`commit=`, which the step's own signal table says outright, so a clean `comment` or `reaction` is
covered by the gate rather than by that check.

**The gate is reached by every convergence and was not, for one round.** Step 11 described itself as
the only edge into step 12 while step 9's clean-comment and `reaction` rows said finish and went
straight there — so on the path most likely to report a convergence, neither the new `pr_head=`
re-read nor `rigor-levels.md`'s sufficiency test ran at all. The test had been unreachable on that
path since it was written, despite that page requiring it "at every edge into the report step"; the
re-read inherited the same hole on the day it was added. Both rows now route through the gate.

**Two head comparisons were still truncating GitHub's answer.** The rule that step 1 keeps
`pr_head=` whole was published with a justification that was false of two of the three places it
described — step 9's `commit=` and step 10's two-trigger sweep compare values GitHub produced, not
values this loop wrote, and both had been cut to eight characters first. Step 9 now resolves the
fence's short oid with `git rev-parse --verify <commit>^{commit}`, which widens it **and refuses an
ambiguous prefix instead of choosing between two objects**; step 10 keeps `commit_id` whole. **No
fence byte changed for this**: the fence still emits eight characters, and the caller widens them for
the price of one `git` call rather than costing every user a re-approval.

**And step 11's reply read searched for the marker's literal instead of matching its envelope.** The
step says never to search the body and its own query said `contains("revloop:reply ")`, so an ordinary
reply reading `revloop:reply round=3 is missing` matched, split to a payload with no `-->` to cut at,
produced a whole `round=3` token, and silently suppressed the answer the step owed. It now matches
`<!-- revloop:reply` through a marker-shaped payload to a closing `-->`. A forged envelope is still
indistinguishable from a real one, which is the bound step 7 already accepts for its own marker; prose
quoting the literal no longer is.

All four returned as one P2 on `iwmaeda/revloop#29` (2026-09).

**The next round found that the widening did not widen.** `git rev-parse --verify <short>^{commit}`
resolves a prefix **against the objects this checkout holds**, so on the only case that matters — a
reviewed commit never fetched here, sharing HEAD's eight characters — there is one local match and it
is HEAD: the resolve succeeds and the comparison passes. **A prefix cannot be un-truncated by the side
that did not shorten it.** Step 9 now fetches the full `commit_id` by the `review_id=` the fence
already hands it, which is the same read step 10 performs per review.

**Two more of the same shape came with it.** Step 9's clean-comment and `reaction` rows still read
`finish (clean)` although their next action is a gate that can send the round back or abort it, which
is the reading that let them bypass the gate to begin with; they now say `clean — pending the gate`.
And **every `comment` row was matching patterns against a preview rather than a body**: the fence
emits the first line, `=` rewritten to `-`, cut at 110 characters, while the rows ask to print the
body in full "including any reset time it names" and to match `rateLimitPatterns` against it. A notice
that is long, multi-line, or carries an `=` cannot match, and drops to the generic bot-body abort —
which is not merely the wrong reason but the row **the standing-round re-take is never reached from**,
so the quota recovery becomes unreachable for exactly those reviewers. Codex's own notice fits the
preview, which is why this survived measurement; that is a property of one string, not of the design.
Step 9 now fetches the body by `cid=` and classifies that. All three on `iwmaeda/revloop#29` (2026-09).

**And the last truncated value was the marker's own.** `head=` is eight characters, and four decisions
rested on it: step 7's backstop, the runaway invariant, the re-post's condition (e) and step 9's check
(c). An externally pushed commit sharing an earlier marker's eight characters satisfies all four at
once — the backstop stays silent so the skipped verification is never restored, the invariant reads
HEAD as unchanged so no new trigger is required, check (c) passes, and **the convergence gate cannot
catch it either**, because that gate compares the checkout against the pull request and both are the
new commit. What is stale is the signal's binding, which the gate never looks at.

The marker now carries `oid=`, the full object id, and those four decisions compare it. **`v` stays at
`1`**: `oid=` is an _added_ key, which the marker's own rule says does not move the version — the
fence's `case` skips a key it does not know and the payload filter passes hex through — and `head=`
keeps its meaning exactly, so no reader of the old format misreads the new one. Widening `head=`
instead **would** have moved `v`, and would have made every older install compare a short HEAD against
a forty-character value and abort. A marker written before this change carries no `oid=` and falls
back to `head=`, which is the guarantee those decisions had until now. **It is
printed because
something reads it**: step 3's check turns on exactly those three facts.

**That third fact took three rounds and two false starts, all three returned as P2 on
`iwmaeda/revloop#29` (2026-09), one per round.** The first asked whether a marker named the current
HEAD — a fact about what this loop had swept. The second compared HEAD to its upstream after a fetch,
which a stale ref had been satisfying against the commit already in hand. The third finding killed
that one too: **the upstream is whatever `@{upstream}` names and nothing ties it to the ref backing
the pull request**, so a branch tracking another name or another remote reports `0 ahead, 0 behind`
while the pull request's head is a commit this checkout has never seen. Each time, step 3 skips and
the HEAD comparisons in steps 7, 9 and 10 converge on an old review. **Three spellings of one shape —
a local fact standing in for a fact about the pull request — and what ended it was the direct
question rather than a fourth proxy.**

**The measurement that made the second detour look final was a measurement of the wrong command.**
`headRefOid` genuinely does not exist on `gh pr list` at the 2.4.0 floor — `Unknown JSON field` — and
that was quoted as though the API could not answer, when REST answers at the same floor:
`repos/{owner}/{repo}/pulls/<n>` returns `.head.sha`, inside a prefix this procedure is already
granted. A measurement of one command was read as a fact about the API.

**The fetch stays for the reason left once the skip no longer rests on it**: the printed
`ahead/behind` is how a reader tells "the same commit" from "behind by three", and step 9's
`--is-ancestor` rows need the objects locally to tell a diverged history from an unfetched one. It deliberately says nothing
about the round or whether an answer is waiting, because classifying a bot body outside the wait fence
is the second implementation step 7 forbids in as many words. The `-b` is scoped to step 1; steps 3
and 4 read the same command for **paths**, and a `##` header there is a line that is not a path.

**"Yours" had to become a name the run can compare against.** A reply guard that skips "a reply of
yours" is unimplementable if the run cannot say which account that is, and nothing here may call an
endpoint outside `repos/{owner}/{repo}/`, so the account cannot be asked for directly. Step 7's two
calls now carry it: `AS=` on the trigger post, and `.user.login` as a third column on the marker read.
Between them they always answer it — a run that fired reads its own post, a run the invariant blocked
reads the account that opened the round in flight — so neither path has to carry a value the other
produced. Without it the guard would have had to match on the comment id alone, and a colleague's
reply under a finding would have suppressed this loop's, while the report said the finding was already
handled.

**No fence changed, no re-approval is owed, and no permission moved.** `tests/fence-hashes.txt` and
`docs/permissions.md` are both byte-identical — the latter matters because
`tests/permissions.test.sh` compares every git subcommand in a fenced block against an individually
granted list, which is why the local-state line is a flag on a command already there rather than a
`git rev-list`. Step 11's read is the endpoint and prefix that step already used.

**Both halves are unexercised, and `## Unexercised paths` now carries them.** No run has been
refused a trigger and then waited on the standing one, and no run has resumed into a round whose
findings were partly answered — which is the only state step 11's read is for. The entries say
which direction each fails in, and for step 11 the two directions are not alike: a read that finds
nothing posts the duplicate this change exists to stop, loudly and on the pull request, while a
match that is wrong the other way skips a finding this loop never answered and says it was handled.
The author comparison is what separates them, and it has not been read back from a live pull
request on either of the two paths that produce the name.

**Two resume gaps are named and not closed.** The per-round bucket-and-rung record step 10 mandates
and `rigor-levels.md` consumes has no anchor on the pull request and is lost with the session, which
is also why the rising-ceiling re-open cannot fire on a resumed run. Closing that needs a decision
about where a run's per-round record lives, which is larger than this.

### `smol-toml` is overridden, because the advisory has no upgrade path through `markdownlint-cli2`

**`npm audit fix` could not fix this, and `--force` proposed a downgrade.** GHSA-7w5x-hrqm-74c2 is a
denial of service in `smol-toml` at `<=1.7.0`, reached through `markdownlint-cli2`, which is the only
thing in this tree that depends on it. Patched releases exist — 1.7.1, 1.7.2, 1.8.0 — but
`markdownlint-cli2` pins its dependency to the **exact** string `1.7.0`, and has in every release
from 0.22.0 through the current 0.23.2. So there is no version of `markdownlint-cli2` npm can move to
that satisfies the advisory, and the only remedy it finds is `markdownlint-cli2@0.21.0`: the last
release before TOML config support existed, three minors back, and `isSemVerMajor` against the
declared `^0.23.2`. `npm audit fix` alone therefore changes nothing and reports the advisory again.

**A root `overrides` entry pins `smol-toml` to `^1.7.1` instead.** This is the second advisory in
this repository that `npm audit fix --force` proposed to answer by downgrading — `ajv-cli` and
GHSA-8gh8-hqwg-xf34 was the first — and the same reasoning applies: the pin is the problem, not the
version we are on. `markdownlint-cli2` stays at 0.23.2 and `smol-toml` resolves to 1.8.0, which
declares the same `engines` (`node >= 18`) and the same `exports` shape as 1.7.0, so it is a drop-in
for the one call site — `parsers/toml-parse.mjs`, forty characters around `parse`.

**Both TOML paths were exercised against the override, not assumed.** A `--config cfg.toml` run
applied its rules (`MD013`/`MD041` off, 0 issues on a file that violates both), and a malformed
document — the advisory's own input class — failed fast with a located parse error and exit 2 rather
than hanging. `npm ci` reproduces 1.8.0 from the lockfile, which is what the CI `npm audit` job
installs from; that job is now green again, and `npm run check:all` is unchanged.

**`overrides` is a floor, not a ceiling, and it outlives the fix.** When `markdownlint-cli2` moves
its pin past 1.7.0 the entry becomes redundant rather than wrong, and `^1.7.1` keeps taking later
1.x patches until then. It is worth removing at that point, but nothing breaks if it is not.

## [0.9.0] - 2026-09-07

### A fourth fence: the loop now removes the worktrees it created

**A fence was added and no existing fence changed, and those cost different things.** `wait-verdict`,
`wait-ci` and `merge` are byte-identical and still match `tests/fence-hashes.txt`, so **there is no
re-approval to give** — nothing you already granted was invalidated. The new `worktree-teardown` fence
asks for one approval the first time a run reaches it, like any command string you have not seen
before. `tests/fence-hashes.txt` is regenerated wholesale in document order, so the diff shows one
changed line and three unchanged hashes; if any of the three moved, an existing fence was edited by
accident and this paragraph is wrong.

**The new fence was then amended thirteen times before release, and that is still not a re-approval.**
An approval is keyed to the exact command string, and nobody has ever been prompted for the earlier
bytes: `worktree-teardown` has not appeared in a tagged release, so there is nothing granted to
invalidate. Against the release boundary this remains **one added fence and one first approval**, and
`tests/fence-hashes.txt`'s `worktree-teardown` line moving again while the other three stay
byte-identical is what says so — the count above is read from those hashes rather than from memory,
and it was wrong here by three until it was. `CONTRIBUTING.md` carries the distinction: adding a
fence and editing one are different events, and only the second costs anybody a re-approval.

**The thirteenth amendment closed the fence's own leak, and it is the one defect here that produced a
false success line.** `git worktree remove --force` has a third outcome besides removing and
refusing: when the worktree holds something it cannot delete, git **deregisters it first and then
fails to finish**, exit 255 at `git 2.34.1`, leaving the directory on disk. One subdirectory with its
write bit off is enough, and that is ordinary for a worktree whose stated purpose is building the
project or running its tests. The sweep was driven by `git worktree list` alone, so the round that
failed reported `WORKTREE=stuck` correctly and **every round after it never saw the path again**:
the ledger line was spent by the rewrite and the terminal line read
`WORKTREE=swept removed=0 other=0 ledger=ok` over a directory that was still there, permanently and
with nothing left to report it. That is the leak this fence was written to close, arriving through
the sweep that closes it — the five leftovers that motivated the feature were also directories
nothing had a record of. **A second loop now walks the record rather than the list**: a recorded path
the list no longer carries but which is still on disk is reported `stuck` and keeps its line. It
removes nothing, so neither bound on the `--force` moves.

**The fixture that should have caught it was the reason it was missed.** `stuck` was reached only
with `git worktree lock`, described in the suite as a stand-in for "a permission error or a
filesystem that will not release the directory". A lock is refused **before** git touches anything,
so the registration survives and a second sweep finds the path again; a permission error is refused
**after** the deregistration, so a second sweep never sees it. The substitute differed from the class
it stood for in the exact dimension the sweep depended on, and the stated reason for using it — that
a lock was the only refusal producible deterministically without root — was itself false. Both shapes
are fixtured now, and the second is swept twice, because the second round is where the defect lived.

**Re-measuring the whole table then found two more claims that were wrong.** It said seven lines in
the fence could be deleted with the suite green; `set -f` and the fence's own sentinel capture make
**nine**, and the sentence that all such lines lived in step 3's block rather than in a fence was
false with them. They need no text assertion — every byte of a fence is pinned by
`tests/fence-hashes.txt`, which is what step 3's block does not have — and the section now says that
instead of claiming a coverage it did not have. The ledger-directory read guard's row read **11** and
no mutation reproduces it: the guard entire turns 5, measured against the unchanged suite as well as
this one. 11 is what step 3's usability test turns, one row below.

**The seventh amendment closed a hang, and the review that found it is the reason the guard's name
is now true.** `reason=ledger-not-regular` was written for a symbolic link and named for the
category, and those are not the same set: a **named pipe** is not a link, so it passed `[ -L ]`
untouched and reached `cat`, which blocks on opening a FIFO with no writer. Measured against the
unwidened guard, the fence ran to `timeout` and printed **no `WORKTREE=` line at all** — step 12
never finished, so the report every exit of that procedure owes never happened. Every other route to
"no terminal line" is an interruption from outside; this one was an input the guard was believed to
exclude, and `mkfifo` needs no privilege, so it sat inside the threat model the link already had.
The test is now the file's type, with `[ -L ]` kept as the first half because `[ -e ]` follows a
link and a **dangling** one would otherwise be reported as the wrong refusal. `docs/permissions.md`
already claimed a record that is not a regular file was refused outright; this is what makes that
sentence true rather than aspirational. **The fixture runs under a cap**, because a regression here
wedges the suite instead of reddening it.

**The eighth amendment closed the same class one path component higher, and it is the first defect
here that a review found rather than an argument did.** Codex returned it as a P1 and it reproduced
exactly: with `revloop` **itself** a symbolic link to a directory holding an ordinary
`worktrees.txt`, every test the record guard makes comes back looking healthy — `[ -L "$F" ]` is
false because the **leaf** is not the link, and `[ -f "$F" ]` is true because it **follows the
parent** — so `cat` adopted a file whose location somebody else chose as the authorization list for
an unconditional `--force`. Measured against the unguarded fence: the recorded worktree removed, its
untracked file gone, and `WORKTREE=swept removed=1 other=0 ledger=ok` printed over all of it. The new
`reason=ledger-dir-not-regular` refuses the link itself and never what it resolves to, which is what
keeps a **dangling** one from being misreported as `ledger-unreadable`. The shapes that are not links
still fail closed where they did: a `revloop` that is a regular file or a named pipe makes `cat` fail
with `ENOTDIR` — measured, without blocking — so only the symbolic link ever succeeded at supplying
bytes, and only it needed a refusal of its own.

**The guard has a writing half, because a rule enforced on one side only trades one failure for
another.** `mkdir -p` succeeds on a `revloop` that is already a link, so step 3 would have gone on
appending the run's own worktree paths into the substituted file while the fence refused to read it
— a destroyed worktree exchanged for a leaked one, under a reason naming neither. Step 3 now refuses
any ledger path it cannot write, **before `git worktree add`** so that an unusable one costs the run
no worktree at all.

**A second review round widened that writing half from the link to the whole path, and both shapes it
added were measured failures rather than arguments.** A `revloop` that is a **regular file** or a
**named pipe** passed a link-only test and made `mkdir -p` fail _after_ the worktree existed —
measured, the worktree created and the record absent, which is the leak the placement was meant to
prevent, arriving through a shape the link test did not cover. And a `worktrees.txt` that is a
**named pipe** is the reading side's hang from the other end: `[ -s ]` is false on a FIFO, so the
newline clause short-circuits and `>>` blocks on opening it with no reader — measured, the command
had to be killed, with the worktree already created. **The reader refused that shape and the writer
walked into it**, which is what a rule enforced on one side only produces.

**That round declined the rest of the finding on the threat model, and wrote the reason down.** It
asked for one serialization and no-follow mechanism with identity revalidation across every pathname
test, on the premise of a process that can write inside `$GIT_DIR`. Such a process already has
arbitrary code execution as you — `core.fsmonitor` and `core.sshCommand` in `.git/config`, and
`.git/hooks/*`, are run by ordinary git commands this procedure invokes — so winning the race would
defend a boundary already crossed two files away; and `O_NOFOLLOW` is not reachable from POSIX shell,
`flock` is not POSIX, and `stat`'s inode flags differ between GNU and BSD, so the mechanism would add
a non-portable dependency, **cost every user a re-approval**, and still only narrow the window.
`## Unexercised paths` now records the race as a class nothing covers.

**A third review round moved both sides to validate before they change anything.** Codex returned the
ordering as a P1 and both halves reproduced. On the writing side, a ledger file the run could not
write let `git worktree add` succeed and the append fail — measured, **the worktree created and
unrecorded**, which is the leak the whole step exists to close. On the sweeping side, a read-only
ledger directory produced `WORKTREE=removed` and then `ledger=error` — measured, **the worktree gone
from disk and its line still in the record**, authorized for another sweep. Step 3 now prepares and
proves the ledger — real directory, regular leaf, readable, writable, created if absent — **before**
`git worktree add`, and the fence proves the rewrite possible **before** the removal loop, under
`reason=ledger-unwritable`. A leak the next run sweeps beats a removal whose authorization outlives
it.

**The same round refused a worktree path containing a newline, which is the one shape that leaked
permanently.** `git worktree add` accepts it, the ledger takes it raw, and both the record and
`git worktree list --porcelain` are newline-delimited — so the entry splits, the fence reports
`WORKTREE=stuck` against a truncated prefix, and the real worktree is never removed. Measured, and
`stuck` is the one outcome that **keeps** its ledger line, so the leak was permanent. Refusing it in
step 3 costs nothing: the path is one revloop composes.

**A fifth round took the probe the rest of the way, and found the newline check reading the wrong
string.** The probe still proved only two of the rewrite's three operations — it cleared and created
`$F.new` and never attempted the rename onto `$F` — so a sticky directory holding another user's
record passed it and failed at the rename, after the `--force`. It now does all three, with `cp -p`
so the record's bytes **and mode** come back unchanged; a redirection would recreate it at the umask,
silently relaxing a read-only ledger and destroying the one fixture that separates `mv` from a
truncate in place. **The rename is the single operation here no fixture can fail**: producing "create
succeeds, rename fails" needs a second user or root, so it is listed at 0 in the table rather than
counted as coverage.

**The same round found step 3 checking the path it was given rather than the path it records.**
`rev-parse --show-toplevel` resolves symbolic links, so a `<scratch>` that is a link whose target
contains a newline records a value that splits although the typed path does not — measured, 0
newlines in, 2 out, after which the sweep cannot match the entry, retires it, and reports `swept`
while the worktree stays on disk permanently. **After three rounds of closing one spelling and
meeting the next, step 3 stopped accepting a path at all.** It takes a **name**, checks it is a
single component drawn from `A-Za-z0-9._-` and carrying the family prefix, and **builds** the path
from a parent it canonicalises itself — so no slash can appear in the name, no suffix can attach
to it, and `[ ! -L "$W" ]` runs on a string the step composed rather than one it was handed. The
spellings that got there: a newline in the typed path; a symlinked parent whose target held one; a
parent spelled with two leading slashes, which git records with one and which is **refused** rather
than normalised because POSIX may make `//` a network root; a git directory whose own name ends in a
newline, which `$( )` silently trims — so two checkouts would share one ledger and one sweep could
retire the other's lines, and both step 3 and the fence now capture it with a sentinel; and a
symlinked leaf, which is a separate hole with the same cause: `git worktree add` accepts such a
path and records its target, so a family-named `$W` pointing outside the family was recorded under
a name the fence's filter drops before the membership test, leaving `swept removed=0 other=0
ledger=ok` over a worktree that is never even called `other`; and then that leaf test itself,
defeated by `$W` spelled with a trailing slash, a doubled slash or a `/.` suffix, each of which
makes the test **follow** the link and brought the same leak straight back. The first spelling of
the parent check was itself wrong — `pwd -P` prints a trailing newline, so piping it to `wc -l`
counts 1 for every clean path and refused everything — and the ordinary-scratch control caught it
before it shipped.

**And the temp-path probe now runs on both sides, which closes the leak direction rather than making
the two accepted sets identical.** A directory standing at `$D/worktrees.txt.new` passes every
permission test on the directory and stops the sweep, so step 3 was recording worktrees the fence
would refuse. The answer was not another test but the same one: both sides decide that class by
performing the three operations. **Two differences remain and are deliberate** — a mode-0444 record
in a writable directory is refused by step 3 and swept by the fence, because one appends and the
other renames; and an empty record makes the fence skip the probe entirely, since with nothing
authorized there is no rewrite to prove. An earlier draft of this entry claimed the sets coincide,
which they do not.

**The probe performs the rewrite's own operations, and the first version of it did not.** It asked
`[ -w ]` of the ledger directory, to avoid a side effect: an unlink-and-recreate probe also removes a
symbolic link planted at `$F.new`, so the rewrite's own `rm -f` stops being what that fixture
measures. A fourth review round returned the consequence as a P1 and it reproduced — `[ -w ]` is true
of a writable directory that nonetheless holds a **directory** at `$F.new`, which `rm -f` cannot
clear, so the rewrite failed _after_ `git worktree remove --force` had run and printed
`WORKTREE=removed` then `ledger=error` with the spent path still authorized. **A permission test
answers the question next to the one the fence needs.** It now clears and creates the temp path.

**The same round found the two sides still proving different things, and one direction of that was a
leak.** Step 3 appends, so it needs the record writable; the fence renames, so it needs the
_directory_ writable and nothing on the record. A mode-0555 directory holding a mode-0666 record
therefore passed step 3, recorded a worktree, and was refused by the sweep — **recorded and
unsweepable**. Step 3 now proves the directory writable too. The opposite direction stays and is
correct: a mode-0444 record in a writable directory is refused by step 3 and swept by the fence, the
producer being the stricter of the two and declining to create rather than creating something it
cannot record. The skipped probe on an empty record is likewise not a bypass — with nothing
authorized the loop removes nothing, so there is no rewrite to prove — and both shapes are fixtures.

**The reordering cost real mutation coverage and the table says so rather than absorbing it.** The
rewrite entire fell from 20 red to 18, and three more lines joined the ones that can be deleted
with the suite green — each for its own reason, not a shared one. The rewrite's own `rm -f
"$F.new"` is 0 because the probe clears that path first, and it stays as the second line of
defence against a re-plant in the window **after** the probe, which is the race declined above.
Its `2>/dev/null` is 0 because the fixtures that used to make the rewrite speak now refuse
earlier, and it stays because the fence's output is parsed and a stray `Permission denied` is not
a `WORKTREE=` line. The probe's own `mv` is 0 because the state that fails it needs a sticky
directory holding another user's record — a second user or root — and it stays because it is the
operation the rewrite performs. `mv`-replaced-by-a-truncate is held at 3 only because a fixture
was added to hold it: a mode-0444 record in a writable directory can be renamed over and cannot be
truncated in place, which is the one shape that separates the two without a race.

**Both halves of the writing guard are held by assertions on the procedure's text, and the first one
written was vacuous.** No test in `tests/fence-worktree.test.sh` can reach a command that file does
not run, so the pin is a search of the procedure — and the first literal chosen, `[ ! -L "$D" ]`,
also appears three times in the prose describing the guard, so deleting the guard outright left the
assertion **green**. It now matches a compound clause the command carries and the prose does not.
**A prose assertion satisfied by prose pins nothing**, which is recorded beside the mutation table
rather than only corrected.

**The same round moved one bound from the reader to the writer, which is where it turns out to
belong.** `>>` onto a record whose last line lost its newline glues two absolute paths into a third
that is syntactically valid and matches no worktree — measured, both entries came back
`WORKTREE=other` under `WORKTREE=swept removed=0 other=2 ledger=ok`, with both directories still on
disk: **the run's own worktrees, leaked, under the success token**. The obvious fix is a reading
guard and it is worse than the bug. `M=$(cat "$F")` strips trailing newlines, so an unterminated
record already reads back and sweeps **correctly**, and a fence that refused it would convert a
working state into a refusal that leaks every worktree the run recorded — the exact shape
`reason=inside-worktree` was narrowed to stop producing. Nothing distinguishes the glued record
afterwards either. So step 3 restores the newline **before** it appends, while the two lines are
still two; the fence is unchanged by this half, and `glued-ledger` keeps the unrepaired append as a
fixture so the clause's absence stays measured. **Two fixtures and one prose assertion** hold it,
because the test helper carries a copy of the clause and a copy can drift from what it copies.

**And the membership read lost its pipeline, which is a hardening no fixture can kill.** Under
`set -o pipefail` a record larger than the pipe buffer lets `grep -q` exit on an early match before
`printf` has finished writing; `printf` takes `SIGPIPE` and the pipeline's non-zero status reads as
"not ours", so a path this checkout owns comes back `WORKTREE=other` and is left behind. It needs
roughly 2300 unretired lines in one checkout, which the retirement puts out of reach — so the
here-string is kept for removing the only pipeline in this fence whose status is tested, and because
it costs fewer bytes than what it replaces. It is **one of the seven** lines recorded in
`## Unexercised paths` as deletable with the suite green rather than counted as coverage.

**If you granted git subcommands individually rather than `Bash(git:*)`, add `Bash(git worktree:*)`
before your next run.** That is a hard failure rather than a prompt: the teardown cannot run without
it. The blanket rule in `README.md` and `docs/permissions.md` already covers it.

**Neither procedure had ever mentioned a git worktree, and runs were leaving them behind.** Nothing
told a run to create one, and steps 3 and 10 make it tempting anyway, because "did this failure
predate my change" and "what does the base branch score" are questions about another commit. Five
leftovers were measured across two repositories — `rev36`, `main-wt`, `wt`, `wt-check`, `wt-check2` —
four of them at `/tmp/<name>`, where a later session has neither the path nor a reason to look.

**A run now writes down what it created, in `revloop/worktrees.txt` inside the checkout's own git
directory.** Step 3 gives the command: a worktree goes **under the session scratchpad**, at a path
whose last component begins with **`revloop-wt-`**, with **`--detach`** so a measurement never takes
a branch hostage — and then **its path is appended to the ledger**, which is what makes it this run's.
Step 12 sweeps exactly the recorded ones; `procedures/local-loop.md` step 11 cites that step rather
than copying the fence, since a copy would sit outside the hash pin, outside `lint:sh` and outside
the test. The ledger is **never read as input to a classification** — the only thing it decides is
which directory the sweep may delete.

**The ledger is not a file in your working tree, and for revloop that is the difference between
working and not.** revloop runs against **your** repository, where this repository's `.gitignore` has
no reach, so a record at the checkout's top level would be an untracked file in yours — and measured
at `git 2.34.1`, `.revloop/worktrees.txt` in a repository that does not ignore it is returned by both
`git status --porcelain -uall`, which is the clean-tree requirement the local loop's step 4 depends
on, and `git ls-files -o --exclude-standard`, which is the secret-scan preflight. **The first
measurement worktree of a run would have cost that run its clean tree.** Under the git directory both
return nothing, `git add -A` cannot stage it and `git clean -xdf` does not touch it, so **"never
stage the ledger" stopped being a rule and became a property of where it lives** — and no consumer
repository needs an ignore rule for it. `.revloop/field-notes.md` and `.revloop/grading-input.txt`
**stay in the tree and keep that cost on purpose**: they are artifacts for a person to find, and a
record for a person is worthless where only a fence looks.

**The record is a file because nothing a fence can re-derive is per run, and the attempt is worth
recording.** A fence takes no arguments and shell state does not survive the call that set it, so the
first design put the run's identity in the worktree's **name**: `revloop-wt-$PPID-`, on the reasoning
that the shell expands `$PPID` at run time and the fence's bytes therefore never change. **That is
false on a harness this project supports.** On the Codex path, where each Bash action becomes a shell
call, independent calls can share one app-server as their parent — so two concurrent runs expand
`$PPID` to the same number, land in the same namespace, and each teardown would force-remove the
other's live measurement. A harness's session id is worse, not better: one variable, one entry point,
absent from the other. A written path has no such dependency, and the fence still takes no arguments
— it resolves the ledger from `git rev-parse --absolute-git-dir`.

**Two loops running against one repository are in each other's `git worktree list`, and the ledger is
what separates them.** It sits inside the checkout's own git directory, which is per worktree where
the common one is not — measured at `git 2.34.1`, `--absolute-git-dir` prints `.git` in an ordinary
checkout and `.git/worktrees/<name>` in a linked one, while `--git-common-dir` prints the same path
in both and would have merged the two runs back into one ledger. So two runs write two different
files; the case it does not separate is two runs in **one** checkout, which was already out of reach
because they would share HEAD, the index and the branch. Anything family-named that this checkout's
ledger does not claim is printed as `WORKTREE=other` and walked past. **A leftover from a run that
crashed before its sweep is still in its own checkout's ledger**, so the next run there takes it —
the earlier design abandoned it to nobody, and that trade is now settled the other way.

**A worktree of any other name is never touched, and that is the second bound rather than the first.**
The ledger says a worktree is this run's; the name is what stops a truncated or hand-edited ledger
line from aiming an unconditional `--force` outside the family.
`tests/fence-worktree.test.sh` holds both: it records a worktree of another name and asserts that
recording it was not enough, plants **a second checkout's live measurement** beside one the fence must
remove and asserts it survives with its **directory**, and sweeps from both checkouts in turn.
`revloop-wt-` rather than `revloop-` deliberately: this project is called revloop, and
`../revloop-fix` is a plausible worktree for somebody working on it.

**The obligation is attached to the report rather than to a step**, which is what makes it reach
every exit: every abort in both files reports and finishes, so one rule covers all of them, including
the next abort somebody adds.

**Two terminal lines, and only one is success.** `WORKTREE=swept removed=N other=K ledger=S` when
nothing of this run's was left behind, `WORKTREE=partial removed=N stuck=M other=K ledger=S` when
something was — **the failure token does not contain the success token**, for the reason
`CHECKS_FAILED` is not called `NOT_ALL_PASS`, and `other=` rides on both because `swept` is a claim
about this run rather than about the repository. Six guards name themselves rather than passing
silently: `WORKTREE=error reason=not-a-repo`, because a failed `git worktree list` prints no rows and
would otherwise be read as a clean sweep; `WORKTREE=error reason=inside-worktree`, because a
fence run from inside a measurement worktree would read that worktree's own git directory, find no
ledger, and print a clean sweep over a record it never opened;
`WORKTREE=error reason=ledger-unreadable`, because a record that exists and cannot be read is not an
empty one; `WORKTREE=error reason=ledger-not-regular` and
`WORKTREE=error reason=ledger-dir-not-regular`, because a record — or the directory holding it —
whose location somebody else chose is not one this unconditional `--force` may take its list from;
and `WORKTREE=error reason=ledger-unwritable`, because a record that cannot be rewritten would leave
every path it just removed still authorized.

**An unreadable ledger is refused rather than treated as an absent one.** The read fell back to an
empty value on any failure, and an empty value is not neutral here: every recorded worktree then
falls out as somebody else's, the rewrite is skipped so `ledger=ok` survives, and the terminal line
announces a clean sweep **over a record nothing opened**, with the run's own worktrees still on disk.
Measured at `git 2.34.1` against a ledger at mode `0200`: `WORKTREE=swept removed=0 other=1
ledger=ok`, the worktree present and its untracked file intact. The guard asks
`[ -e "$G/revloop" ]` — about the ledger's **directory** and not the ledger — because permissions are
checked per component: a file test is both unreachable, since a file that exists implies a parent
that does, and blind to a directory whose search bit is gone, which is exactly the state where the
record is present and unreadable at once.

**A swept path stops being authorized, and it used not to.** The record was append-only, so a line
outlived the worktree it was written for and kept that path authorized for the fence's unconditional
`--force` **forever** — and the family name is no second bound in that case, because whatever appears
at that path next is family-named by construction. A later round, another checkout, or a person
creating a worktree where one of the loop's used to be would have had it deleted with its untracked
work in it. The sweep now rewrites the record to **exactly the paths it could not remove**: a removal
spends its line, so does a name refusal, and so does a worktree that left the repository by a route
the loop never walks. Only a `stuck` path keeps one. `ledger=ok` on the terminal line means the
record now holds exactly what that line calls `stuck`; `ledger=error` means the removals happened and
the record did not shrink, so those paths are authorized for one more sweep — nothing is lost, since
the rewrite renames a sibling over the target and a failure leaves the previous record whole.

**And a checkout of your own named `revloop-wt-something` no longer refuses the sweep.**
`reason=inside-worktree` used to read the invoking checkout's last path component alone, which
reserved that name for every checkout anybody might run a loop from — a clone at
`~/src/revloop-wt-client`, or a branch checkout named `revloop-wt-fix`, aborted the whole teardown
and left behind every worktree the run had recorded, which is the leak the fence exists to close. A
measurement worktree is not a name: it is family-named, **linked**, and has **no record of its own**,
because step 3 writes into the git directory of the checkout it runs from and never into the worktree
it just created. The guard asks all three, and `[ -f "$G/gitdir" ]` is the linked test — measured at
`git 2.34.1`, a linked worktree's git directory holds a `gitdir` file and an ordinary checkout's
`.git` does not. **The floor did not move**: that layout arrived with worktrees in 2.5, below the 2.17
`worktree remove` already assumed. The hazard the old guard disarmed on its way past — at
`git 2.34.1`, `remove --force` deletes the worktree the shell is standing in and exits 0 — is now
refused by the loop itself, which never calls `remove` on the path it is standing in and reports it
`stuck`.

**The fence carries no `git worktree prune`, and that is a measurement rather than an omission.**
`remove --force` already deregisters a worktree whose directory is gone (`git 2.34.1`, exit 0), so a
prune would add nothing while reaching past the ledger to every stale registration in the
repository — including one of your own on a drive that happens to be unmounted, and including
another run's.

**Creating a worktree costs a permission prompt every time, and `--auto` cannot suppress it.** The
command carries a path and a commit-ish, so it is a different string on every invocation and cannot
be a fence. `docs/permissions.md` counts it as a fourth string class, and step 3 says to prefer
`git show`, `git diff` and `git log`, which answer most questions about another commit without
leaving the tree you are in.

**The record and its temp file are now written only where the fence controls what is standing
there.** `$F.new` was a fixed name written with a plain `>`, so anything able to write the ledger's
directory could leave a symbolic link at it: the redirection followed the link and truncated whatever
it pointed at, and the rename then left **the record itself** a link to that file — which step 3
appended into and the fence read back as the list of paths its unconditional `--force` may take.
Measured at `git 2.34.1` against the unhardened rewrite, with a link planted at `$F.new`: the target
emptied, `worktrees.txt` a link to it, and `WORKTREE=swept removed=1 other=0 ledger=ok` printed over
all of it — **the false success line this fence's whole design refuses to print.** Three changes
answer it. The temp path is unlinked before it is written, and **the unlink is the first link of the
`&&` chain rather than a statement before it**, because a read-only ledger directory makes the unlink
fail while a write _through_ a link to a file outside that directory still succeeds — so a fence that
unlinked and wrote anyway would truncate the target and report `ledger=error`, naming a failure other
than the one that happened. The write is then `O_EXCL` under `set -C`, which covers the window
between a successful unlink and the redirection. And a record that is not a regular file is refused
before it is read at all: `WORKTREE=error reason=ledger-not-regular`, the sweep does not run, and
nothing is removed — because `[ -e ]` and `[ -f ]` both follow a link, so this is the one condition
neither of the other two read guards can see.

**Adding the unlink retires an argument this file made in the other direction.** The residue a failed
rename leaves at `worktrees.txt.new` was documented as permanent, on the reasoning that an `rm` in a
fence whose entire argument is a bounded `--force` costs more than the file does. That was right
about the residue and wrong about what else a fixed temp name is good for; the leftover is now one
sweep long, as a consequence of the guard rather than its purpose. It also decides the shape:
`set -C` alone would have been the wrong fix, since noclobber refuses an existing **regular** file
too — measured at `bash 5.1.16` — so without the unlink the first failed rename would have wedged
every later rewrite into `ledger=error`.

**And the family name now means one thing in both places it is written.** Step 3 says the last path
component **begins with** `revloop-wt-`; the fence asked for a character after the prefix, so a run
whose `<slug>` came out empty recorded a path the sweep then skipped in silence — not removed, not
named as another's, and its ledger line retired by the rewrite regardless, under a `swept` line. The
pattern is `revloop-wt-*` now. A worktree named `revloop-wt` without the hyphen is still outside the
family, and the pattern's own trailing `-` is what refuses it, as it always was.

**Nothing has run this in a loop.** Both `## Unexercised paths` sections say so, and the honest part
is which half is unmeasured: the sweep is exercised, and **the recording is not** — none of the five
leftovers that motivated this was ever written down anywhere. **It fails open.** A worktree created
without its ledger line is left behind exactly as it is today, under a procedure that now says it
cleans up, and the report cannot mention it because the fence never saw it. **Two loops have never
run against one repository at the same time either** — the separation is measured by hand against a
real repository with two checkouts, and by fixture, but not by the situation it exists for. And **seven**
lines in the fence can be deleted with the suite green: the guard on `git worktree list`, the guard
on `git rev-parse --absolute-git-dir` — since `--show-toplevel` has already succeeded above it —
the rewrite's `set -C`, whose subject is a second process replanting a link between the unlink and
the write, which no fixture races, the membership read's here-string, whose subject is a record
larger than the pipe buffer, and — since the write probe began clearing and creating `$F.new` before
the loop — the rewrite's own `rm -f "$F.new"`, its `2>/dev/null` and the probe's own `mv`, whose
conditions the probe now
reaches first. The last two stay as second lines of defence against a re-plant in the window after
the probe, which is the race declined above. All seven are recorded in `## Unexercised paths` rather
than counted as coverage — and re-measuring the whole suite across **281** assertions and
**thirty-two** throwaway repositories did not change that.

**Three more things the sweep's rewrite does not cover, all written down rather than argued away.**
The retirement is measured by hand against a real repository — a path recorded, swept, retired, then
re-occupied and correctly named `WORKTREE=other` with its untracked file intact — but **no round has
ever recorded a path, spent it, and re-used it**. `ledger=error` is produced by a read-only directory
and `reason=ledger-unreadable` by a `chmod`, which stand in for the full disk, the lost permission or
the ownership change a run would actually hit, and both fixtures skip themselves as root. In a
**linked** checkout whose own name is in the family, an unreadable ledger satisfies the
`inside-worktree` guard first, so that state reports the wrong one of the two reasons — both refuse
and neither removes anything. And the record is read once at the top of the fence and written once at the bottom,
so a line appended in between is discarded — which needs **two runs in one checkout**, a
configuration that already could not work, since they would share HEAD, the index and the branch.

### Also in 0.9.0

- **The amendment count above was read out of `tests/fence-hashes.txt` again before the tag, and it
  was short by one.** That line took fourteen distinct values between 0.8.0 and this release — the
  introduction and thirteen amendments — while the entry said twelve, having been written when
  `a2eda36` was the tip and not moved when `edebd66` landed behind it. The amendment that closed the
  fence's own leak is the thirteenth. The two this entry names by ordinal are unaffected: the seventh
  is still the hang, and the eighth still the ledger directory. **This is the second time the count
  in this entry has been wrong**, the first being by three, which is the argument for reading it at
  the tag rather than at the merge.
- **The suite's own totals were stale in the same way, and the procedure already disagreed with
  them.** The entry said the whole suite was re-measured across 263 assertions and thirty throwaway
  repositories. Both were exact at `a2eda36` — measured again at that commit, the suite reports
  `263 passed` and builds 30 — and `edebd66` took them to **281** and **thirty-two** without moving
  the sentence. `procedures/remote-loop.md`'s `## Unexercised paths` had said thirty-two since that
  commit, so the two files disagreed about a number one of them had counted. **Three numbers in this
  entry were written against the same tip and left behind by the same commit**, which is the pattern
  rather than three separate slips.
- **`docs/install.md` derived the `git` floor from "the one command every fence depends on"**, and
  the fourth fence depends on none of it. `worktree-teardown` runs `git rev-parse --absolute-git-dir`,
  `git rev-parse --show-toplevel`, `git worktree list --porcelain` and `git worktree remove --force`,
  and no `git branch --show-current`. **The floor does not move**: the highest of those is
  `git worktree remove` at 2.17, below the 2.22 the other three fences set — so what was false was
  the derivation and not the number, and the page now says which fences share the command and which
  one does not. Found by reading the package rather than by a test.

## [0.8.0] - 2026-09-04

**No fence changed, so there is no re-approval to give.** The three shell fences in
`procedures/remote-loop.md` are byte-identical and still match `tests/fence-hashes.txt`.

**This is a breaking release, and the default behaviour changed. Retype your invocation.**
`--accept-at` is gone, with no deprecation window; `--rigor <level>` decides when the loop may stop;
**and the default is `standard`, not the strictest level.**

| Was                  | Now                                                                                |
| -------------------- | ---------------------------------------------------------------------------------- |
| no acceptance flag   | **`--rigor thorough`** — the default is now `standard`, which is not the same      |
| `--accept-at high`   | `--rigor minimal`                                                                  |
| `--accept-at medium` | `--rigor standard`, which is also the default                                      |
| `--accept-at P2`     | `--rigor minimal` — both shipped maps send `P2` to `high`                          |
| `--accept-at P3`     | `--rigor standard`                                                                 |
| `--accept-at low`    | `--rigor thorough` (stricter, recommended) or `--rigor standard` (one rung looser) |

### The default now leaves `medium` and `low` unfixed, and that is the change to read first

**Every release before this one fixed or declined every finding unless you typed an acceptance
argument.** The default is now `standard`: `critical` and `high` block, and `medium` and `low` may be
left unfixed — recorded, explained and listed in the report, but unfixed. **`--rigor thorough` is
what gets the old bar back**, and it is the one edit an existing invocation needs.

**Four things follow, and each of them lands on a run that types nothing:**

- **`--merge --auto` aborts** with `reason=unreviewed-accept-merge`. That gate rests on a person
  reading the accepted list before a merge, and `--auto` exists to delete exactly that stop; the
  default now produces such a list. `README.md`'s unattended example is now
  `--rigor thorough --merge --auto`. **This is the change most likely to stop a working invocation.**
- **A grader runs every round** against a reviewer that reports no severity, at one subprocess and
  one permission prompt per round. Three of the five shipped reviewers are that reviewer, so on
  `local-review-loop` the ordinary run is **two** subprocesses per round where it was one.
- **The round cap is lower** — 5 on the pull-request loop and 3 locally, where the builtins were 10
  and 5, because the cap follows the level. `--max-rounds`, `defaults.maxRounds` and
  `defaults.localMaxRounds` all still beat it; write the key to keep the old number.
- **`reason=bad-severity-map` is reachable untyped.** The map is consulted on every run against a
  reviewer that has a ladder, where it used to be consulted only when a floor was named.

**Nothing has measured that `standard` converges in fewer rounds than `thorough` does.** That trade —
a subprocess per round against rounds saved — is the argument the default rests on, and it is an
argument rather than an observation. Both procedures' `## Unexercised paths` say so.

**`--accept-at low` is the one _typed_ invocation whose meaning is not preserved, and it is named
rather than smoothed over.** Against every shipped reviewer it is identical to `--rigor standard`,
because both
shipped `P1`/`P2`/`P3` maps skip `medium` and the two floors therefore produce the same sets. Against
a custom four-rung reviewer it sits one rung stricter than `standard`, so pick `thorough` unless you
mean to accept one rung more than you did.

### `--rigor <level>` replaces the acceptance floor, and moves more than the floor

**A floor answered one question with one comparison.** It said which rungs could be left unfixed and
nothing else: not how many rounds to budget, not how far to sweep after a fix, and not whether the
change looked finished rather than merely above the line. The only lever an operator had for "this
run does not need the full treatment" was to raise the floor and hope the rounds got shorter.

| Level                    | Blocking      | Acceptable band  | Round cap (remote / local) |
| ------------------------ | ------------- | ---------------- | -------------------------- |
| `minimal`                | `critical`    | `high` and below | 3 / 2                      |
| `standard` **(default)** | + `high`      | `medium`, `low`  | 5 / 3                      |
| `thorough`               | every finding | none             | 10 / 5                     |
| `exhaustive`             | every finding | none             | 15 / 8                     |

**The level also supplies the round cap where nothing else did**, and the precedence is
`--max-rounds`, then `defaults.maxRounds` / `defaults.localMaxRounds`, then the level. It replaces
what used to print as `builtin`, and step 1 prints `source=rigor` when it answered — a number that
moves with what you typed must not print as one that does not. **A repository that configured a cap
keeps it**, which is also the way to keep the old builtins now that the default level is not the one
carrying them.

**It also says which sweeps a round owes after a fix.** `minimal` owes the class name and the
already-fixed check — the one sweep that _saves_ rounds rather than spending them, which is why it
survives the cheapest level. `standard` adds the corpus sweep. `thorough` requires every sweep that
applies, which is what both procedures required before levels existed. `exhaustive` promotes the
definition sweep and a closed input-space enumeration from "when it applies" to "always".

**`exhaustive` is deliberately not a second confirming clean round.** A round that reviews an
unchanged tree is the one thing the local loop's runaway invariant refuses, and buying confirmation
by making the loop violate it is not a stricter run.

### The loop now judges whether the change is sufficiently reviewed, and the judgement is bounded

**At every edge into the report step, a run answers in writing whether the change meets its level** —
reading the latest review's rungs and where each came from, its own per-round record of buckets and
rungs, and which sweeps were run. The answer goes into the report, and into the pull-request body on a
publishing run, as a `Sufficiency:` block.

**The test may keep a run going and can never end one early.** Every stop it permits is one the
level's floor already permitted; everything else in it can only withhold permission. **That is what
makes it safe for the loop to run on itself**: the party obliged to fix the findings can give itself
more work and never less. The rungs still come from the reviewer or from a grader that is not told
the floor — what the loop applies is a standard it did not author to rungs it did not author.

**The run's history reaches the decision through one rule, and it re-opens rather than blocks.** A
ceiling that has risen inside the acceptable band since the previous round re-opens the acceptances
under it, beside the existing rule for a rung that crossed the floor. A band is a range rather than a
point, so three `low` findings accepted in one round and three `medium` ones in the next is a change
getting worse under a floor that never moved. **A gate there would deadlock**: with nothing left to
fix, the next round arrives at the step that refuses to review an unchanged tree, and the loop sits
between a step that will not review and a step with no verdict to classify. A re-open gives the round
something to fix, so the tree moves.

**No commit carries the `Sufficiency:` block**, and that is the same gap the last round's `Accepted:`
block has rather than a second one: a commit is written before the review that would justify it, so
the converging round makes no further commit. An empty commit written only to carry the block invents
a commit that says nothing was true.

### Three aborts are gone and one is new

**`reason=unknown-accept-level` is replaced by `reason=unknown-rigor-level`**, which prints four
words where its predecessor printed two ladders and still had to say which of them the value had been
measured against. A level is never a rung name, so there is no vocabulary for it to be written in and
nothing for it to fail to match.

**`reason=no-severity-map` is gone, not moved.** `severityLevels` and `severityMap` are now a
required pair in `schema/reviewer.schema.json`, in both directions, so a ladder with no map is
rejected before either procedure loads the file. **A structural rule belongs where the structure is
validated**, and a runtime abort for a shape the schema can express is a second implementation of the
same rule that only fires on the runs that reach it. Every shipped and example reviewer already
carried both keys, so no definition changed.

**The native/canonical two-pass resolution is gone with it.** It existed so that one typed rung could
mean the same thing against reviewers that do not share a vocabulary; four fixed policy words do that
without a pass, a fallback, or an ordering rule to keep old invocations meaning what they meant.

**`reason=bad-severity-map` stays**, with its condition restated: the reviewer has a ladder **and**
the level has an acceptable band. A map nothing consults cannot move a floor, which is the reasoning
it already carried. **`reason=unreviewed-accept-merge` stays** too, re-homed onto
`--rigor minimal|standard` with `--merge --auto`.

### Grading fires on a level, and the default level starts one

**Grading now fires if and only if the resolved level has an acceptable band and the definition
declares no `severityLevels`.** At `thorough` and `exhaustive` nothing is acceptable, so no rung is
consumed and no subprocess starts. **The default is neither of those**, so against `claude`,
`code-review` and `ecc-review-pr` the grader is part of the ordinary run rather than of a flag —
which is where the extra prompt per round in the section above comes from. `--rigor thorough` is what
removes it, and it removes the floor with it.

### Also in 0.8.0

- **`--rigor` has no configuration key**, for `--accept-at`'s reason: a repository you just cloned
  must not lower its own review bar. **A key holding only the two strict levels was considered and is
  worse, not safer** — those grant nothing, so it could never lower a bar, and a key that can only
  hold the value it already has is a promise rather than a setting.
- **`procedures/rigor-levels.md` is a new file**, and it is a specification cited by both procedures
  in the way `procedures/severity-grading.md` already is. It removes the asymmetry in which the local
  procedure had to say that an acceptance argument meant whatever the pull-request procedure said it
  meant.
- **`README.md`'s `.revloop.json` sketch still showed a `reviewers` map**, which was removed in 0.7.0.
  The sketch now shows `defaults` and points at `docs/adding-a-reviewer.md`.
- **`tests/schema.test.sh`'s "shipped ecc-review-pr preset" fixture carried a `severityLevels` ladder
  the shipped definition does not have** — five measured rounds disproved that ladder in 0.7.0 and
  the fixture was not updated with it. A fixture pinning a preset that was never shipped pins nothing.
- **`tests/commands.test.sh` asserts `--rigor` on all seven commands** and refuses `--accept-at`
  beside the three flags already held removed. **`tests/schema.test.sh` rejects a `rigor` key on both
  surfaces**, and keeps rejecting `acceptAt` — the reader most likely to reintroduce a key is the one
  migrating from the old name.
- **`tests/rigor-levels.test.sh` pins the four level words and the eight round caps to
  `procedures/rigor-levels.md`.** Those values are now written out in the two READMEs, in
  `docs/configuration.md` and in all seven commands, and nothing compared any copy to any other:
  renaming a level in the spec's own table, and separately moving the default's caps from `5 / 3` to
  `6 / 4`, each left `npm test` fully green with every other file holding the old value. **The spec
  is the source rather than a schema**, which is what differs from `severity-ladder.test.sh` — the
  level has no configuration key by design, so no machine-readable copy exists to derive from.
  **`CHANGELOG.md` is swept by neither**: this file says what was true when it was written, and a
  guard over it would make every later cap change demand an edit to a historical record.

### Running revloop _from_ Codex is now called a preview, and that is a documentation change

**Nothing about `@codex review` moves.** As a reviewer it stays what it has been since 0.1.0 — the
`verified` preset with the most measured rounds behind it, driven by `/revloop:remote-codex-loop`
like every other reviewer's command. **What is relabelled is the other Codex: the host you run
revloop from.**

That side is `.agents/skills/revloop/SKILL.md`, one router file. It covers the pull-request loop
only, it is not linted and it is in no test corpus — `CONTRIBUTING.md` has said the second part since
0.7.0 — and nobody has driven it end to end. `docs/install.md` and `docs/permissions.md` already said
all of this; **the two READMEs and the marketplace description did not**, and led with "a Claude Code
/ Codex plugin" and "one entirely local", the second of which is exactly the half Codex cannot reach.
Both READMEs now separate the reviewer from the host in their opening paragraph, carry the three
caveats in their install section, and hold a `Limitations` row for the host. `package.json`,
`.claude-plugin/marketplace.json` and `.codex-plugin/plugin.json` say the same in one line each.

**The router gained the one resolution rule it was missing, and it is the reason the label is
"preview" rather than "unsupported".** `procedures/remote-loop.md` declares that the reviewer's
definition arrives from the invoking command and is never resolved inside it — and **Codex has no
invoking command**, so nothing on that side could name `reviewers/<name>.json` at all.
`docs/design-notes.md` claimed since 0.7.0 that the router "can now read the same file Claude Code
does"; it could not. `SKILL.md` now resolves the definition itself, refuses to default to any
reviewer, and echoes the resolved path in the step-1 table — the compensation for being one skill
where Claude Code is seven commands. It also gained the resolution rule for
`procedures/severity-grading.md`, which it cited without saying where to read it from. **Neither
addition has been driven end to end**, which is what the preview label is for.

### Also corrected before the tag

- **`CHANGELOG.md`'s link definitions stopped at `[0.6.0]`**, so the `[0.7.0]` and `[0.8.0]` headings
  were dangling shortcut references that rendered as literal brackets. markdownlint's MD052 does not
  check shortcut syntax by default, so `npm run lint:md` stayed green over it. Both are now defined.
- **`v0.7.0` was never tagged.** 0.7.0 and 0.8.0 folded their version bump into a `feat!` commit
  rather than a `chore: release` commit, and the tag step went with it. `v0.7.0` is tagged
  retroactively at the merge of `#24`, the last commit whose `package.json` reads `0.7.0`.
- **Both READMEs' resolved-configuration sketch showed `reviewer codex flag`.** `--reviewer` was
  removed in 0.7.0 — the command fixes the reviewer — so the source is `builtin`, and the row now
  carries the `(<status>)` that step 1 has asked for since 0.6.0. The sketch also gained the
  `severity source` row that step 1 lists among the rows it must cover.
- **Step 1 asked for `<name> (<status>, <expectedLatency>)` and no shipped preset carries
  `expectedLatency`.** Read literally, that instructs a run to invent a range for every reviewer.
  The latency is now printed only when the definition states one. The measurements that would fill
  the key live on the cards; `reviewers/codex.md` is the only one that has them.

## [0.7.0] - 2026-09-04

**No fence changed, so there is no re-approval to give.** This release moves every file the fences
live in, splits two commands into seven, and deletes a flag — and the three shell fences are
byte-identical, still matching the hashes in `tests/fence-hashes.txt`. That is the whole point of
keeping runnable text in fences and pinning their bytes: a restructure this large costs nothing at the
permission prompt.

**This is a breaking release. Retype your invocation.** `/revloop:remote-loop` and
`/revloop:local-loop` are gone, with no deprecation window.

| Was                                            | Now                                           |
| ---------------------------------------------- | --------------------------------------------- |
| `/revloop:remote-loop`                         | `/revloop:remote-codex-loop`                  |
| `/revloop:remote-loop --reviewer gemini`       | `/revloop:remote-gemini-loop`                 |
| `/revloop:remote-loop --reviewer claude`       | `/revloop:remote-claude-loop`                 |
| `/revloop:remote-loop --reviewer <yours>`      | `/revloop:remote-custom-loop --config <path>` |
| `/revloop:local-loop --reviewer code-review`   | `/revloop:local-review-loop`                  |
| `/revloop:local-loop --reviewer ecc-review-pr` | `/revloop:local-ecc-loop`                     |
| `/revloop:local-loop --reviewer <yours>`       | `/revloop:local-custom-loop --config <path>`  |
| `--review-model <name>`                        | `--model <name>`                              |
| `--accept-at high --grade-severity`            | `--accept-at high`                            |

### The reviewer is a command, not a flag

**`--reviewer` is removed.** A flag that selects a reviewer is a flag that can select the wrong one,
and the reviewer is not a detail of the run: it decides which bot login the wait fence filters on,
which rungs an acceptance floor is measured against, whether a merge is available at all, and which
aborts are reachable. There is now one command per reviewer, and choosing the command is choosing the
reviewer.

**Seven commands, two procedures.** Every `remote-*` command runs
[`procedures/remote-loop.md`](procedures/remote-loop.md) and every `local-*` command runs
[`procedures/local-loop.md`](procedures/local-loop.md), byte for byte. The commands hold a flag table,
a reviewer definition and a pointer, and nothing else — `tests/commands.test.sh` refuses a bash fence,
a trigger marker, a spelled-out ladder or a stray tool grant in any of them. **Seven front doors, not
seven code paths**, which is the objection `docs/design-notes.md` had to answer before the split was
worth making.

**Reviewer-specific flags now appear only where they apply.** `--merge` and `--timeout` are on the
`remote-*` commands; `--model` and `--no-publish` on the `local-*` ones. Both were advertised to
everyone before, on commands where they did nothing.

**The procedures moved to `procedures/` and carry no frontmatter.** The host installs `commands/` and
never `procedures/`, so an `allowed-tools` line in a procedure would be a grant nobody receives —
`tests/fence-guards.test.sh` now refuses one. `$REVLOOP_PROCEDURE` and the Codex router keep their
names; the router resolves `procedures/remote-loop.md`.

### Reviewers are files

**Each shipped reviewer is now a definition plus a card**: `reviewers/<name>.json`, validated against
the new [`schema/reviewer.schema.json`](schema/reviewer.schema.json), beside the measurement card that
already existed. The definition object is unchanged — it is the one that used to sit in a fenced
` ```json ` block inside the card — so this is a move rather than a rewrite. **The file name is the
name**: there is no `name` key and nothing to drift, and the stem must be marker-safe because the
pull-request procedure writes it into the trigger marker.

**A reviewer you write is the same format, named with `--config <path>`.** One format, one loader, no
special case for a built-in. `examples/reviewer.custom.json` and `examples/reviewer.local.json` are
starting points.

**`.revloop.json` no longer defines reviewers.** The `reviewers` map and the `defaults.reviewer` and
`defaults.localReviewer` keys are removed: with every command naming its own definition, a map here
would be a definition surface no command reads. **Nothing breaks at runtime** — an unknown key in that
file is ignored — so a stale key costs an editor warning rather than a failed run. Move the reviewer
object into a file and point `--config` at it.

### Grading needs no flag

**`--grade-severity` is removed, and `--accept-at` now works against every reviewer.** When the
reviewer's definition declares no `severityLevels`, the rungs come from the grader that flag used to
start — specified now in [`procedures/severity-grading.md`](procedures/severity-grading.md), cited by
both procedures and owned by neither.

**Three aborts are gone with it**: `no-severity-ladder`, `grade-without-floor` and `grade-over-ladder`.
All three were conditions dressed as errors. Grading now fires **if and only if** `--accept-at` was
typed and the definition declares no ladder, so a reviewer that emits its own rungs cannot be regraded
because nothing can ask for it — **stronger than the refusal it replaces**, and it makes
`no-severity-map` and `bad-severity-map` unreachable on a graded run by construction rather than by
another refusal.

**This is the one change that made revloop quieter rather than louder, and it is worth knowing.**
Before, `--accept-at` against a ladderless reviewer stopped the run; now it spends a subprocess and a
permission prompt every round. Three of the five shipped reviewers are ladderless — `claude`,
`code-review` and `ecc-review-pr` — so this is the ordinary case for the local family. **The
compensation is disclosure and not a stop**: step 1 prints `severity source` as `grader (<model>)` and
prints the grader's expanded command line before the first round, and every rung it assigns says
`graded` wherever a rung is written. `.revloop/field-notes.md` records that the grader has never
actually run in nine local rounds, so what changed is which invocations reach it, not what happens
when one does.

**The rule the old abort protected is unchanged and restated where grading now lives:** the loop must
never rank the findings it is itself obliged to fix. The grader is a separate subprocess that is not
told the acceptance floor and does not fix what it grades.

### `copilot` removed, and the fences left alone

**`reviewers/copilot.md` is deleted.** The preset was `unsupported` and could not be driven: a reviewer
summoned by reviewer request posts no comment, so there is nothing to anchor a round's baseline to.

**Its three load-bearing facts were rehomed first, and one of them the repository was missing.** The
card held the only cited provenance for the `bot=` filter — Copilot reviews on `iwmaeda/iwmaeda#1` and
`#2` (2026-08), firing automatically rather than by request — while
`docs/design-notes.md` asserted that failure with no citation at all. It now carries the citation. The
no-comment-trigger constraint and the removed-keys note moved to `docs/adding-a-reviewer.md`.

**The fences still name `copilot`, deliberately.** Its two interim-comment patterns are in the wait
fence's drop list and its name is in the compatibility alternation that lets a hand-typed
`@<reviewer> review` anchor a baseline. Neither is a reviewer registry, and a comment already sitting
on a pull request does not disappear when a card does. Removing them would cost every user one
re-approval to shorten a regex, which is the trade the deleted card had already recorded against
itself. `procedures/remote-loop.md` now says so where the fence is.

### Tests

- **New `tests/commands.test.sh`.** The flag matrix per command, the definition-to-command wiring in
  both directions, the procedure pointers, the thinness guards, and that the two families each grant
  one byte-identical tool string — plus that no `local-*` command grants `Bash(gh pr:*)`, which was
  prose in the procedure and enforced by nothing.
- **Both READMEs are compared for the first time.** `README.ja.md` mirrors every section of the English
  one by hand and nothing tested it; the new suite asserts that every command appears in both.
- `tests/schema.test.sh` validates `reviewers/*.json` directly instead of extracting fenced blocks,
  asserts the definition/card pairing in both directions, and pins the removed keys as rejects.
- `tests/fence-guards.test.sh` and `tests/permissions.test.sh` split their globs: fenced bash and fence
  bytes come from `procedures/`, `allowed-tools` from `commands/`.
- `tests/procedure-refs.test.sh` now scans the commands too — a thin command's whole job is to point at
  a step in a file it does not contain, which is where a line-number citation would appear next.

### Also

- `CONTRIBUTING.md` claimed `markdownlint-cli2` runs with `dot: true` and lints `.claude/**` and
  `.agents/**`. It does not, and never did in this configuration; the claim is corrected rather than
  the configuration changed, because nothing has asked for those files to be linted.

**No fence changed, so there is no re-approval to give.** The three shell fences in
`commands/remote-loop.md` are byte-identical and still match the hashes in
`tests/fence-hashes.txt`.

**Nothing is asked of you.** No flag, no permission rule and no `.revloop.json` key has to change:
the key this release makes available is optional, and both shipped local presets already carry it.

**A local reviewer that has run out of quota is now diagnosed as that, instead of as an unreadable
review.** `/revloop:local-loop` aborted with `reason=unparsed-review-output` when its review command
answered with its host's session-limit notice — exit 0, one line, no findings. **The abort was
right and the diagnosis was not**: that reason's documented causes are a working reviewer and a
checkout missing the permission block from [`README.md`](README.md), and it sent the operator to look
at a parser and a permission grant that were both already correct while the reviewer had simply run
out of quota. The round now aborts with `reason=reviewer-rate-limited`, prints the output in full
including the reset time the message names, and says outright that no review was performed.

**The pull-request loop has had this row since it had a reviewer with a quota** — step 9 of
`commands/remote-loop.md`, _"Do not retry. The quota recovers with time;
retrying only burns rounds"_ — and the local loop is now the same ruling in its own table. It does
not retry and it does not wait: the recovery is a fresh invocation once the quota is back, which
step 6's runaway invariant permits because that invariant is a within-run rule.

Added:

- **`rateLimitPatterns` is readable on a `local-command` reviewer.** The schema forbade it, correctly,
  for as long as nothing in that loop read one — a key with no consumer is the defect the kind split
  exists to prevent. Step 8 now reads it, so the key follows the consumer rather than the other way
  round. It is matched against the review's output — its stdout under `invoke: subprocess`, what it
  reports under `invoke: skill` — where the pull-request loop matches it against a comment body;
  `cleanPatterns` did **not** cross with it, because the local loop's clean
  signal is that no finding was parsed and there is no phrase to match.
- **Both shipped local presets declare one**, so an ordinary run gets the named abort with no
  configuration. `ecc-review-pr` carries it as a measurement; `code-review` carries it as a reading
  carried from the sibling preset — the same host binary — and its card says under `## Not measured`
  that the state has never been observed on that command.
- **The step-1 table prints a `rate-limit pattern` row**, reading `declared` or
  `none — a quota reply will read as unparsed-review-output`. A reviewer with no pattern still aborts
  when its quota runs out; the row says in advance which of the two diagnoses you will get, before the
  wait rather than after it.

Fixed:

- **Step 8's clean row said "the three abort rows"** and there are now four. The paragraph above the
  table that enumerates what an outcome-rows-on-top ordering would have swallowed now names the
  fourth: a reviewer that answered with its quota notice parses as zero findings exactly as an
  unreadable output does.

## [0.6.0] - 2026-09-03

**No fence changed, so there is no re-approval to give.** The three shell fences in
`commands/remote-loop.md` are byte-identical and still match the hashes in
`tests/fence-hashes.txt`.

**The two commands are renamed, and the old names are gone.** `/revloop:review-loop` is now
`/revloop:remote-loop`, and `/revloop:review-loop-local` is now `/revloop:local-loop`. There is no
alias and no deprecation window, because a name that still answers is a third and a fourth entry in
the command list — which is the thing the rename exists to remove. What is asked of you is to retype
the invocation, and **nothing else**: no flag, no default, no `.revloop.json` key and no permission
rule moves, so a repository already configured for 0.5.0 needs no migration.

**Four more things ask something of you. The first two are permission rules to add, and both are
about `/revloop:local-loop`.** It now **pushes and opens a pull request by default**, which means:
add `Bash(gh pr create:*)` and `Bash(gh pr list:*)` to your permission rules —
[`docs/permissions.md`](docs/permissions.md) has the full list — and **`gh` is now a requirement of
that command**, where it previously needed nothing on GitHub at all. `--no-publish` is the run that
still needs neither.

**Those two narrow rules are deliberately not the `Bash(gh pr:*)` the remote loop holds.** That rule
covers `gh pr merge`. The local command has no merge step and no `--merge` flag, so it does not hold
the rule that merges — a grant is a capability, and the command that cannot merge should not be able
to.

**The third is a permission prompt, it appears only if you type `--grade-severity`, and it is the one
item here that touches both commands.** The grader is a subprocess carrying a model, so it is
deliberately absent from both `allowed-tools` lines and the permission system sees it every round:
**two prompts a round on a local run** where there was one, and **one on a pull-request run** where
that loop had never started a model subprocess at all. **There is no rule to add** — leaving it out
is the point — so what is asked of you is to expect the prompt rather than to read it as a defect.

**The fourth is an invocation that has stopped working, and it is the one thing here that used to
work and now aborts.** `--accept-at` against `ecc-review-pr` — including the spelling this README
carried as an example, `--accept-at HIGH` — now ends in `reason=no-severity-ladder`. That preset
shipped `severityLevels` and a `severityMap` this release removes, because **five rounds of driving
it established that it emits neither**: the four-rung ladder was read out of one of the six agents
the command dispatches, the only one with a written output format, and none of that format reaches
the aggregate. What is asked of you is to add `--grade-severity` beside the floor, which is what the
other local preset has always needed:

```console
/revloop:local-loop --reviewer ecc-review-pr --accept-at high --grade-severity
```

**A ladder that was read rather than emitted is the failure `reviewers/README.md` exists to prevent**,
and this project shipped one for a release. Removing it is the correction; the flag is the way back
to a floor.

**Also new, and it is not something you configure: `ecc-review-pr` does not work in a checkout that
has not been given permissions.** Without the block in [`README.md`](README.md) at
`.claude/settings.local.json`, the command exits **0** in under a minute and returns a paragraph
asking for a permission grant — no findings, no severity, no verdict. The loop catches it as
`unparsed-review-output` rather than as a clean round, and the card now records the permission block
as a precondition of the preset rather than of the pull-request loop alone.

Added:

- **`--accept-at` takes one vocabulary, whatever the reviewer calls its rungs.** The level is matched
  against the resolved reviewer's `severityLevels` first — as a whole string, case-sensitively, which
  is what the flag always did, so **no existing invocation changes meaning** — and only then against
  revloop's own canonical ladder, `critical > high > medium > low`, carried onto the reviewer's rungs
  by a new **`severityMap`** key. Three emitted vocabularies already coexisted among the shipped
  presets, so a floor written in one reviewer's words aborted against the others and the flag read as
  broken rather than as reviewer-specific.

  **The map is a judgement and the ladder is a measurement, and they are two keys for that reason.**
  Nothing establishes that one reviewer's `P1` and another's `CRITICAL` describe the same thing, so
  each card ships its map in the config block and says under `## Not measured` that it is a judgement
  — including which canonical rung a three-rung ladder had to skip. The loop **never derives a map
  from rung position**: a canonical level against a reviewer that has a ladder and no map aborts
  with `reason=no-severity-map`, because reading `critical` off "rung 1 of 3" is the loop authoring
  a ladder one key over from where that was already forbidden. **That abort is scoped to a reviewer
  that has a ladder**, so a reviewer carrying neither key — the one `--grade-severity` exists for —
  reaches a round rather than this row. A partial, **foreign**, inverted, or **wholly collapsed** map
  aborts with `reason=bad-severity-map` — collapsed because a map sending every rung to one canonical
  rung is total and inverts nothing while making the lowest floor the flag can express accept the
  reviewer's worst finding, and foreign because a ladder shortened without its map satisfies totality
  while leaving an entry pointing at a rung that no longer exists. Merging rungs stays legal, and is
  unavoidable: three rungs cannot cover four canonical ones and five cannot avoid sharing. **That
  abort is checked only when `--accept-at` resolved on the canonical pass**, for the reason the map is
  allowed a config key at all: a map nothing consults cannot move a floor, so checking it on every run
  broke a reviewer for ordinary use over a key that run never read.

  **A canonical floor is compared rung by rung and does not have to be a rung any of them maps to.**
  Both shipped `P1`/`P2`/`P3` maps skip `medium`, so `--accept-at medium` against either leaves `P1`
  and `P2` blocking and `P3` acceptable — the same floor `--accept-at low` gives, which is what four
  canonical rungs receiving three means rather than a defect in either.

  **`severityMap` is settable from `.revloop.json` and `--accept-at` still is not**, which is a line
  worth being explicit about: `severityLevels`' own **order** has always carried the same power to
  move a floor, so the map is no new class of it. The mitigation covers both — **step 1 now prints
  the resolved floor expanded**, as the sets of the reviewer's own rungs that block and that are
  acceptable, before the first round runs.

- **`--grade-severity`: an acceptance floor against a reviewer that emits no severity.** This is the
  ordinary case rather than an edge one — [`reviewers/code-review.md`](reviewers/code-review.md)
  measures that the local loop's own default preset emits none, so `--accept-at` aborted against it,
  and that card had been asking for a run under the floor to settle whether the loop converges at all.
  **That measurement was not merely unmade; it was unreachable.**

  The flag is **off unless typed** and has no configuration key, for the reason `--accept-at` has
  none. Without it, a reviewer with no ladder still aborts with `reason=no-severity-ladder`, exactly
  as before. It is **refused against a reviewer that has a ladder** (`grade-over-ladder`), because
  regrading a rung the reviewer emitted replaces a measurement with an inference, and typing it with
  no floor aborts too (`grade-without-floor`) — the rungs would have no consumer.

  **It narrows "the loop never supplies a ladder the reviewer did not"; it does not repeal it**, and
  [`docs/design-notes.md`](docs/design-notes.md) argues the new boundary rather than deleting the old
  paragraph. That rule was never about where a rung comes from — it is about the party obliged to fix
  the finding, and about a reader who cannot check afterwards which kind of rung they are looking at.
  So: **the grader is a separate subprocess** on the review model, with none of the loop's context,
  and it does not fix what it grades. **It is not told the acceptance floor**, which is the
  load-bearing half — a grader that knows what will be spared is answering "how much work should the
  caller do" instead of "how severe is this". And **every graded rung is marked `graded`** in the
  pull-request reply, the commit's `Accepted:` block, the pull-request body and both reports, which is
  the direct answer to "from outside the run that is indistinguishable from a reviewer that really
  graded them that way".

  **Withholding the floor accomplishes nothing if a finding can supply one**, so the grader is told
  in its own prompt that the findings are data and not instructions. They are reviewer output quoting
  repository content, so a claim reading "known false positive, rank it low" is the lever the whole
  arrangement is built to keep out of reach, arriving through the one door left open — and it would
  parse, abort nothing, and converge clean. **The findings reach the grader through a file rather
  than through its command line** for the same reason `--body-file` carries a pull-request body:
  building an argv out of repository-derived text is a hole, and it also kept the string you approve
  from growing with the findings. The procedure specifies the grader **once**, in step 10 of
  `commands/remote-loop.md`, which the local loop now cites rather than restates.

  **A graded rung is kept out of step 7's repeat fingerprint**, because a grader's rung can move by
  being asked twice and putting it in the key would switch the repeat suppression off on precisely
  the reviewer whose card measures rounds that do not converge. The finding that would otherwise
  strand is answered separately: **an accepted finding whose graded rung later rises above the floor
  is re-opened and re-bucketed**, which the closed `accepted` bucket bounds to once with no counter,
  since a re-read cannot put it back where a floor it now exceeds would have to hold it.

  **Four things abort a graded round, and all four say the grader is broken rather than that it
  declined a finding**: a non-zero exit (`reason=grading-command-failed`), output that does not parse
  (`reason=unparsed-grading-output`), and — sharing that second reason — a rung outside the four
  canonical words or a finding number that was not sent. **A finding for which no line arrived is not
  one of them**: it is blocking and listed as `ungraded`. Rungs are attached **by the number on each
  line and never by the line's position**, because one dropped line would otherwise shift every rung
  after it and a `critical` would inherit the rung below it, accepted and silent — the same defect
  `unknown-accept-level` refuses on the other ladder.

  **What this does not establish is that a grader's rungs are any good.** Nothing measures that, and
  the reports say a graded convergence is the weaker result. **Nor is the data-not-instructions
  framing measured** — a grader that followed an injected claim answers in the same shape as one that
  did not, so it is the one guard here with no failure mode to fail into, and both procedures say so
  under `## Unexercised paths`. A graded run costs **one more permission prompt a round** than the
  same run without the
  flag — two rather than one in the local loop, where the review command is already prompted for, and
  one rather than none in the pull-request loop, whose reviewer is a GitHub app rather than a process
  it starts. The grader's command line is this procedure's own rather than the repository's, but it
  carries a model, so it is no more a fence than the review command is.

- **`/revloop:local-loop` carries the branch to a pull request.** The loop ended at a commit
  and left the branch for a person or for the remote loop; it now pushes it and opens a pull request,
  reaching the place `/revloop:remote-loop` starts from. **`--no-publish` ends the run at the commit**
  and is the only flag on the feature — an earlier draft of this release had `--push` and `--pr` as
  opt-in flags instead, and inverting the default removed one flag, the "push but no pull request"
  middle state, and every rule that existed only to describe it. Neither flag ever reached a release,
  so nothing in the wild is being taken away.

  **Where the publishing happens is read off the reviewer's `requiresPr`, not off a flag, and that is
  the load-bearing decision in this release.** A reviewer that resolves its own pull request is
  published to before every round, because it would otherwise read a stale diff. Everything else is
  published to once, after the loop converges — **because a push breaks the shipped default
  reviewer.** [`reviewers/code-review.md`](reviewers/code-review.md) records that `/code-review` diffs
  against the branch's upstream when there is one; `git push -u origin HEAD` creates one, `HEAD` then
  equals it, the range is empty, and the commit step has just left the tree clean. A round run after a
  push returns **zero findings**, and zero findings is what a clean review looks like. That is the
  failure this whole family of procedures exists to prevent, reachable through a feature that looks
  unrelated to reviewing — so a `--publish-before-review` switch would have been a way to configure
  it, and the placement is derived instead.

  **One stop disappears on the ordinary run, and it is a removal rather than a suppression.** A
  `requiresPr` reviewer used to cost a confirmation that an open pull request existed, and the
  decision table used to refuse to read zero findings from one as clean. Both existed because the loop
  **could not check**. Publishing supplies the check — step 5 reads the branch's open pull requests
  **that round**, creates one if none answered, and pushes `HEAD` to it immediately before the
  reviewer runs. The read is the round's own rather than step 1's, because step 1's can be stale by
  the second round and a stop retired against a stale read is suppressed rather than supplied.
  `--auto` deletes a question and leaves the uncertainty; this answers the question, which is why it
  may remove a stop `--auto` is not
  allowed to touch. **Both survive under `--no-publish`**, which is the run that still cannot check.

  **It also closes a gap this project had written down and could not fix.** The last round's
  `Accepted:` block reaches no commit — a run that converges by accepting makes no further commit to
  carry it — and the procedure's own text used to end that paragraph by telling you the acceptances
  "belong in the pull-request body you write next", an instruction to a person about an artifact the
  command could not write. It writes it now.

  **What the default costs is stated rather than hidden.** Three situations cannot publish at all — a
  fork, a repository with no `origin`, and a remote that is not GitHub — and step 1 aborts on them
  with `reason=fork-unsupported` or `reason=publish-unavailable`, naming `--no-publish` as the way
  through. Under opt-in flags a user in any of those simply never typed one and the loop worked. **A
  fork is not a rare place to work**, and that is the price of the default.

- **`--review-model <name>`, defaulting to `sonnet`.** The review runs on a light model; the fixing
  stays on whatever model is running the procedure. **This began as a cost change and is recorded as
  an evidentiary one**, because of something the project had already written down twice:
  [`docs/design-notes.md`](docs/design-notes.md) and
  [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) both said a local reviewer sharing the
  fixer's model is not an independent check, and that **only a different model makes it one** — and
  both then listed "a reviewer that runs a different model" as a candidate nobody had shipped. **That
  framing was wrong in a way worth naming: it treated the model as a property of which command you
  pick.** It is a property of how the command is invoked. So the cheap configuration and the more
  independent one turn out to be the same configuration, and it needed no new reviewer.

  **The model reaches the reviewer through a `{reviewModel}` placeholder in its `command`, and not by
  splicing a flag in.** Splicing guesses the command's CLI — one reviewer spells it `--model`, another
  `-m`, another an environment variable, another takes no model at all — and this project aborts
  rather than guesses everywhere else. The placeholder lets whoever wrote the command, the only party
  that knows, say where the model goes.

  **There is no configuration key for it, and for a sharper reason than the flags above.** Its value
  is **expanded into a command line**, so a key would be the first thing revloop interpolates into a
  shell command out of a repository-supplied file —
  [`docs/configuration.md`](docs/configuration.md) states the opposite as an invariant. It comes from
  the flag or the builtin, and is refused unless it matches `^[A-Za-z0-9][A-Za-z0-9._:-]*$`.

  **A flag that cannot act aborts rather than passing silently.** `--review-model` against an
  `invoke: skill` reviewer, or against a `subprocess` one whose command carries no placeholder, aborts
  with `reason=no-model-boundary` and names the fix. This is the rule `--accept-at` already follows
  against a reviewer with no ladder, and it bites harder: somebody typing `--review-model haiku` to
  spend less would otherwise be billed for the strongest model with nothing saying so.

- **`--no-publish` has no configuration key, and inheriting its neighbours' reason would have been
  wrong.** `--merge`, `--auto` and `--accept-at` have none because a repository you just cloned must
  not be able to **grant itself** an action. **Publishing is the default, so a key could only turn it
  off, and a key that removes an action grants nothing.** It stays flag-only because nothing measured
  says a project wants it — a _not yet_, not a _never_, and `tests/schema.test.sh` pins the rejection
  so that adding `defaults.localPublish` is a deliberate act with a test to delete.

Changed:

- **The two commands are named for where they run.**

  | Was                             | Is                        |
  | ------------------------------- | ------------------------- |
  | `/revloop:review-loop`          | `/revloop:remote-loop`    |
  | `/revloop:review-loop-local`    | `/revloop:local-loop`     |
  | `commands/review-loop.md`       | `commands/remote-loop.md` |
  | `commands/review-loop-local.md` | `commands/local-loop.md`  |

  The old pair named the axis once. The remote command carried no word for where it ran, so the local
  one read as a variant of it — and it is not one:
  [`docs/design-notes.md`](docs/design-notes.md) argues at length that these are two procedures with
  different reviewer classes and different scarce resources, one spending wall clock and the other
  tokens. The names now carry that distinction instead of leaving it to the documentation.

  **A command's name is its filename**, so this is a rename of the two files, of every reference to
  them, and of each procedure's own title: the remote one read `# revloop — the review-and-fix loop`,
  carrying the same silence about where it ran that its filename did. `.claude-plugin/plugin.json`
  globs `./commands/`, so no manifest was edited and **the version is unchanged**.

  **Nothing else moved.** The three fences are byte-identical — `tests/fence-hashes.txt` is untouched,
  so there is no re-approval to give — and so is each procedure's `allowed-tools` line, every flag,
  every default, and every key the schema accepts. The one thing to re-export is the Codex router's
  entry point: it resolves `commands/remote-loop.md` now, so `REVLOOP_PROCEDURE` points at the new
  path.

  **The released sections below still say `review-loop`, and that is deliberate.** They record what
  the files were called when each release was cut, so their prose is left as written; only the link
  targets were moved, so a click from an August entry still lands on the file that entry is about.

- **Both shipped local presets pin `{reviewModel}`, and `ecc-review-pr` moves from `invoke: skill` to
  `subprocess`.** A skill runs in the loop's own session, on the loop's model, spending the loop's
  context, and nothing inside a session can lower the model it is running on — so it was the one
  shipped preset that tripped the new abort. **The switch discards no measurement**, because
  [`reviewers/ecc-review-pr.md`](reviewers/ecc-review-pr.md) was written entirely from the installed
  command and never from a run. What it adds is unknown rather than measured, and the card says so:
  whether a subprocess reaches `gh` — which that reviewer needs — and whether the plugin's skills load
  in a `-p` session. `invoke: skill` remains supported for hosts that forbid the other.

- **`reviewers/code-review.md`'s five measured rounds no longer describe the shipped preset**, and the
  card leads with that. They ran `claude -p "/code-review medium"` with no `--model` at all; the
  preset now pins one. The finding counts, the wall clock, the output shape and the absence of repeats
  are kept because they are the only measurements that exist and most of what they establish is about
  the command rather than the model — but **the direction of the error is not knowable from that
  sample**: fewer findings from a lighter reviewer may mean fewer defects present or fewer defects
  found.

- **The local procedure is eleven steps rather than nine**, with publishing at 5 and at 10, and every
  internal citation renumbered. **`--max-rounds` is now checked wherever a round opens** — step 5 for
  a `requiresPr: true` reviewer, whose push is that round's first act, and step 6 for every other.
  The cap used to sit at the first step of a round that spent tokens; publishing put a step that
  pushes in front of it, so on the last permitted round the fix reached the pull request before the
  cap aborted, leaving a commit there that the loop never reviewed.
  `tests/procedure-refs.test.sh` permits step citations and forbids line numbers, so nothing but
  reading catches a stale one; they were swept by hand.

- **A `subprocess` command may not begin with `gh`, or with the `{reviewModel}` placeholder.** The
  first is the existing `git` rule applied to the second grant, and it is **deliberately wider than
  the four rules that motivate it** — banning the granted spellings instead would be four rules that
  have to track a grant list every future step can extend, and a ban that lags its grants by one
  release is the hole itself. The second closes the same hole reached through expansion:
  `{reviewModel} push --force` under `--review-model git` would otherwise become exactly the banned
  shape, since expansion happens after the prefix is checked. The procedure additionally re-checks the
  **expanded** string before running it, because a static rule about a template is not a rule about
  what ran. `tests/schema.test.sh` pins every axis of both.

- **Both shipped local presets have now been driven, and most of what that established is that the
  cards were wrong.** Eight rounds against `iwmaeda/revloop#22`: five of `ecc-review-pr`, which had
  never been run at all, and three of `code-review`, each of them a clean round — the first that
  reviewer
  has ever returned. Neither loop converged on `reviewers/README.md`'s bar, so **both cards stay
  `unverified`** — the third and fourth runs in this repository to end at a cap rather than at a clean
  round, after codex's two. What changed is the evidence under them.

- **`reviewers/code-review.md` derived that a push empties this reviewer's target, and a run in
  exactly that state disproves it.** The card read out of the installed command that `/code-review`
  diffs against the upstream and falls back to the base branch, so a pushed branch — upstream set,
  `HEAD` equal to it, tree clean — was expected to leave the reviewer nothing to read. Run there, it
  reviewed `main..HEAD`, named the changed file and described its diff. Zero findings came back, which
  is what the derivation predicted, for the opposite reason. **That card's `## Not measured` had asked
  for this run by name.** Step 5 of `commands/local-loop.md` cited the
  derivation as measured behaviour; **the publish placement does not move**, and what holds it is now
  stated as caution — one sample is not enough to relocate a step whose failure mode is a run
  finishing clean over a diff nobody read.

- **The output shape of `/code-review` is not stable, and three of them have now been seen.** The five
  rounds recorded for 0.5.0 ran with no `--model` and returned a `Findings (N):` list; under the
  `sonnet` pin the same command at the same effort returned a fenced JSON array, and then prose
  stating the count with no fence at all. **That is why an unrecognised shape is an abort and not a
  loose parse**, and it is the first evidence that the pin this release ships moves more than the
  price of a round.

- **`ecc-review-pr` emits the command's confidence words as headings, and its latency is the highest
  measured in this repository.** Five rounds returned 3, 10, 6, 7 and 7 findings — 33, all distinct,
  no repeat in any of them — in 5m09s, 9m17s, 9m17s, 12m05s and 11m29s, above `code-review`'s
  5m27s–8m39s and above the remote reviewer's 2:46–10:07 at the top end. Six dispatched agents are not
  the cheap end of the local loop.

- **Thirteen rounds across the two presets produced no repeat, so `repeat-findings` is still an abort
  nothing has entered**, and the repeat fingerprint is still unexercised — 73 findings, 73 distinct,
  counting the five `code-review` rounds recorded for 0.5.0. That is now measured rather
  than assumed, and it is recorded on both cards.

- **`tests/version.test.sh` compares the lockfile as well.** The version lived in five manifests and
  the changelog and was checked in all six; `package-lock.json` carries it too, npm regenerates it
  rather than taking an edit, and skipping that regeneration leaves a tracked, shipped file reporting
  the previous release. Nothing downstream complains — `npm ci` was measured installing a
  version-mismatched lockfile without a word, exit 0 — so this suite is where it is caught or nowhere.
  The comparison is a function now, and eleven self-checks drive it against a synthetic mismatch, an
  absent path, an absent file, a file that is not JSON, one that cannot be opened, an empty reference
  and five malformed rows: every row before this ran against manifests that already agreed, so the
  branch reporting a disagreement had never once been entered.

Removed:

- **`severityLevels` and `severityMap` from the `ecc-review-pr` preset**, from its card, and from
  [`examples/revloop.local-reviewer.json`](examples/revloop.local-reviewer.json). See the fourth item
  at the top: they described a ladder the reviewer does not emit. **`grade-over-ladder` is no longer
  reachable through a shipped preset** as a result, and is kept for a configured reviewer that has a
  ladder of its own.

## [0.5.0] - 2026-09-02

**No fence changed, so nothing here asks anything of you.** The three shell fences in
`commands/review-loop.md` are byte-identical to 0.4.0 and still match the
hashes in `tests/fence-hashes.txt`, which `tests/fence-guards.test.sh` reports on every run — so there
is **no re-approval to give**. The granted rule list in
[`docs/permissions.md`](docs/permissions.md) is unchanged as well, and the new command grants a
strict subset of it: `Bash(git:*)` and nothing else.

**That is not luck, and it is the reason this release looks the way it does.** The local loop runs a
command that comes out of `.revloop.json`, and the tempting shape for it was a fence — a fixed string
the permission system approves once. A fence is safe **because its bytes never change**, and this
string is per-project by construction, so a fence here would either prompt every round anyway or hand
a cloned repository a pre-approved slot. `verify` had already answered the question: show the string
in the step-1 table, keep it out of `allowed-tools`, and let the permission system see it every time.
The cost is one prompt per round for the one string most worth looking at.

Added:

- **`/revloop:review-loop-local`, a second procedure that drives a review command on your machine and
  ends at a commit.** It never calls `gh`, opens no pull request, and merges nothing. The failure it
  answers is arithmetic this repository had already written down and could not act on:
  `reviewers/codex.md` derives that **the number of remote rounds is roughly the number of defects
  present when the trigger fires**, and step 3 of the remote procedure has told you since 0.1.0 to run
  step 10's sweeps one step early for that reason — by hand, unaided, as "read the change you are
  about to push". This command is that instruction with a reviewer behind it.

  **It is a separate file rather than a `--local` branch**, and the argument against two code paths
  in [`docs/design-notes.md`](docs/design-notes.md) is what settles it rather than what stands in the
  way. That argument is about two ways of reaching the **same** outcome halving the coverage behind
  every claim. These are not the same outcome: roughly half of `review-loop.md` — the baseline
  timestamp, the trigger marker, the re-post budget, the two-trigger sweep, the wait fence — exists
  because a verdict arrives later, from elsewhere, possibly for someone else's trigger. None of that
  is true when the reviewer hands you its own output, and carrying it across would leave every one of
  those rules to be re-read as "does this still apply?" by whoever edits next. What the two share is
  the prepare phase, and the local procedure **cites it by step number rather than restating it**,
  because `CONTRIBUTING.md` forbids the copy and a restatement is three places to fix the next
  whitespace-preflight defect instead of one.

  **The scarce resource is different, and the procedure is shaped around that.** A remote round costs
  minutes of someone else's compute and a quota that runs out, and both are visible. A local round
  costs tokens, and **nothing in the room displays that** — so four rules exist only because of it: the review
  is not re-run while HEAD is unchanged and the tree is clean (the runaway invariant, transplanted for
  a different reason — remotely the cost is obvious, locally there is nothing else to notice it), a
  finding whose fingerprint this run already answered is counted and **not reasoned about again**, a
  round carries at most ten findings into the fix step, and `--max-rounds` defaults to 5 rather than
  10 because the cap is the only brake there is.

  **An unreadable result is its own abort, and never a clean round.** The built-in review command's
  output shape depends on the effort level and on the model running it — the same command returns a
  fenced JSON array in one configuration and one line per finding in another — so a parser written
  against the shape its author happened to see returns **zero findings** against the other. Zero
  findings is what a clean review looks like. Step 10 of the remote procedure states this rule three
  times for three different reads; it is stated here for the one read this command has.

- **`--accept-at <level>`, on both loops: the highest severity that may be left unfixed.** The failure
  is in this repository's own field notes, three times. `iwmaeda/revloop#13` hit `--max-rounds 10`
  still returning findings, was re-run at 20, hit that too with the last five rounds returning P1, and
  ended at a rate limit. The only exit the procedure had was `abort`, and there was no way to say
  "the top rung is clear, the rest is understood, this is done". `reviewers/gemini.md` records the
  same shape from the other end at 30–50 findings in a single round.

  **It is the first consumer `severityLevels` has ever had.** The schema says a key with no consumer
  is a promise the procedure does not keep, and for four releases this was that key: three cards
  filled the ladder in, nothing read it, and the one place that reasoned about severity — step 12's
  "lead the report with a declined P1" — named **codex's vocabulary** literally. On the
  `["blocker","major","minor"]` ladder shipped in `examples/revloop.custom-reviewer.json`, that rule
  named a rung that does not exist and therefore led with nothing, on a reviewer class nobody had
  driven. Step 12 now reads the top rung off the resolved reviewer.

  **It is off by default, and a run without the flag behaves exactly as 0.4.0 did.** It is flag-only
  for the reason `--merge` and `--auto` are: a repository you just cloned must not be able to lower
  its own review bar while the run still reports a clean convergence. `tests/schema.test.sh` now
  rejects it in both the `defaults` block and a reviewer entry.

  **Accepting is not skipping the read.** An accepted finding is still fetched, classified, recorded
  and listed; the floor decides only when the loop may stop. **"Recorded" rather than "replied to",
  because only one of the two loops has anywhere to reply**: the pull-request loop answers each
  acceptance in a reply, and the local loop writes the same rung-and-floor pair into the commit's
  `Accepted:` block and the report. That boundary is where the flag is safe,
  because `reviewers/codex.md` says outright **not to triage by the badge** — it measured one pull
  request returning 15 of 15 at P2 and another 15 of 15 at P1 — and a version of this flag that
  skipped fetching the accepted rungs would be exactly what that card forbids, and cheaper, which is
  why the rule is written into the procedure rather than left to judgement. The record for an
  acceptance is required to name the rung and the floor, so that it cannot read like a decline: a
  decline asserts the finding is wrong and carries a citation, an acceptance concedes it is right and
  unfixed, and the reader deciding whether to merge cannot recover the difference afterwards.

  **`--accept-at --merge --auto` aborts.** The floor's safety argument is that a person reads the
  accepted list before the merge, and `--auto` exists to delete that class of stop. With `--merge`
  alone, an accepted finding adds a third stop point that lists them.

  **The loop never supplies a ladder the reviewer did not.** Asked to accept from a reviewer that
  emits no severity, step 1 aborts with `no-severity-ladder` rather than ranking the findings itself.
  It is the party obliged to fix them, so a ladder it authors is one it can author its way out of the
  work with, and from outside the run that is indistinguishable from a reviewer that really graded
  them that way. This is not hypothetical: the built-in review command shipped as a preset below is
  exactly that reviewer.

- **Reviewers now have a `kind`, and the schema enforces which fields each may carry.** `kind` is
  absent from every configuration written before this release and absent means `github-comment`, so
  nothing changes meaning. A `local-command` reviewer requires `invoke` and `command`, may carry
  `requiresPr`, and **may not carry** `botLogin`, `trigger`, `markerTolerated`, `cleanPatterns` or
  `rateLimitPatterns`; the reverse holds too, so a `github-comment` reviewer may not carry `command`.
  Without the second direction `kind` would be a label rather than a discriminator, and a reviewer
  could be given a field its loop never reads — the same defect as a config key with no consumer.

  **`requiresPr` exists because "returned nothing" and "found nothing" are the same empty result.**
  A review command that resolves a pull request itself has no target when there is none, and reading
  that as a clean round is the failure mode this whole family of procedures is built around. **The
  loop cannot check whether a pull request exists** — it has no `gh` grant, which is the point of it
  — so the key does not buy an abort the way `markerTolerated: "no"` does. It buys two things that
  are checkable: a confirmation before the first round, and a standing rule in step 7 that **zero
  findings from such a reviewer is never a clean round**. An abort was the first design and it made
  a shipped preset unreachable on the branches where it actually works.

  **There is no `effort` key.** Whatever depth argument a review command takes belongs inside
  `command`, which is the string the step-1 table shows and the string the permission system matches.
  A separate key would put half the invocation where neither of those looks.

  **The one guard on that string — a `subprocess` command may not begin with `git` — is a plain string
  prefix, and two narrower spellings leaked before it got there.** The local command grants
  `Bash(git:*)` for its own probe, and `docs/permissions.md` states the model the whole rule rests on:
  **Claude Code matches a command-string prefix.** So the set to reject is every string starting with
  those three characters, and both earlier attempts instead asked where the _word_ `git` ends — a
  question the matcher never asks. `^\s*git(\s|$)` read only whitespace and end-of-string as ending
  it, so `git;rm -rf /`, `git&&rm -rf /`, `git&`, `git|tee`, `git>out`, `git<in` and `git"" push` all
  passed. `^\s*git($|[^A-Za-z0-9_.-])` closed those and still admitted `gitlint`, `git-review` and
  `git.exe`, on the reasoning that the shell would run a different binary — true, and irrelevant.
  **The prose in `docs/permissions.md`, `SECURITY.md` and the procedure said "may not begin with
  `git`" the whole time; the implementation is now that sentence and nothing else.** The cost is
  stated where a reader configuring a reviewer will meet it: a review command whose own name starts
  with `git` cannot be a `subprocess` reviewer, and has to be configured as a `skill` — which no
  `Bash` rule matches — or renamed. `tests/schema.test.sh` pins both axes.

- **Step 6 of the local loop buckets every finding, not every finding above the floor, and step 7's
  clean row is "no findings" rather than "none above the floor".** Both bounded _reading_ by the
  acceptance floor, when the floor is only allowed to bound _stopping_. A review consisting entirely
  of acceptable findings took the clean row straight to the report before step 8 had assigned a single
  `accepted` bucket — so the run announced a clean convergence over findings the reviewer raised, the
  command parsed, and nobody classified or recorded. That is the exact claim `--accept-at` is sold
  on ("accepting is not skipping the read"), broken in the one case where accepting is the whole
  round. A finding reaching the report with no bucket is **accepted by nothing but its absence from
  the fixed list**, which is the distinction the acceptance reply exists to preserve. A genuinely
  clean round is unaffected: it takes the new first row and reaches step 9 as before.

- **`--max-rounds` is checked where a round is opened — step 7 remotely, step 5 locally — and is
  decided from no verdict at all.** Three placements were tried and the first two are recorded here
  because each looked like the fix for the last. As the decision table's **last** row it was
  unreachable, since every ordinary verdict matched something above it. As the **first** row it
  aborts a round that came back clean on exactly the round the operator budgeted for, because the cap
  aborts a loop that _has not converged_. As a **rule over the row's outcome** it still fails in both
  directions: a `review` row says "go and read the findings", not "the loop has not converged", so
  capping it rejects a valid final round — and a clean comment or a reaction is waved through, while
  on a two-trigger round the mandatory step 10 sweep can then surface blocking findings and open the
  next round past the cap. **The cap is not a property of a verdict**, which is why no position in
  either table was ever going to be right. Deciding it where the round opens also costs nothing when
  it fires: the wait, the trigger and the reviewer's quota are all still unspent.

- **A verdict line carrying `marker_head=none` reaches the lost-baseline row instead of being
  demoted to `pending`.** Step 8 reconciles a mismatched `trigger=` by treating every form as
  `pending`, and step 7 states that a verdict line is the **only** positive evidence that the
  baseline is foreign — precisely because it carries `marker_head=` where a `pending` line carries
  nothing. So the reconciliation destroyed the one signal the recovery is defined in terms of. The
  ordinary way to lose a baseline is a newer hand-typed trigger, which produces exactly the shape the
  carve-out is for: `trigger=` not yours **and** `marker_head=none`. Without it that became three
  mismatches and `reason=foreign-baseline`, which promises no recovery, while the `marker_head=none`
  row — which promises a later run re-takes the baseline — was unreachable for its commonest cause,
  in spite of two places saying it takes precedence.

- **The `requiresPr` confirmation defers to the single stop, which previously only the `skill` half
  did.** Fixing one of a promised pair is not fixing the pair: a reviewer that is `skill`-invoked
  _and_ sets `requiresPr` is the case the "one stop" promise exists for, and it was the case that
  still stopped twice. The shipped `ecc-review-pr` preset is both.

- **The acceptance promise says "recorded" rather than "replied to", in all five places that made
  it.** A reply is a mechanism only the pull-request loop has; the local loop opens none, so the
  wording left it owing a reply it has nowhere to post. Its record is the commit's `Accepted:` block
  and the report, and step 8 now states the obligation where the bucket is assigned rather than only
  at step 4 — a record owed at one step and described at another is a record nobody writes.

- **Both decision tables say how they are read, and their guards sit where first-match reading
  reaches them.** Neither table stated that the first matching row wins, and both were written with
  the exhaustive outcome rows on top — so the cross-cutting guards beneath them could not fire. In
  the local loop nothing mitigated it, because that table is the entire decision: `No findings at
all` matched every zero-finding result, and an unreadable output, a command that never ran, and a
  `requiresPr` reviewer with no pull request **all parse as zero findings**. Each is a run finishing
  clean over a review that did not happen, which is the failure this whole family of procedures
  exists to prevent, and `unconfirmed-empty-review` asserted in its own prose that it takes
  precedence over the clean row while sitting below it. The three aborts now precede it. In the
  pull-request loop the equivalent cases are already caught by checks (a) to (e) before any row is
  read, and two ordering defects were not: `interim-loop` sat behind "any other bot body", a
  strictly wider description of the same comment that swallowed it and aborted with a reason that
  sends the reader hunting an unknown bot; and `EXTRA=`, whose whole content is the rule "rate limit
  takes precedence", was the **last** row, while the fence only ever emits it alongside a `review`
  whose rows are above. `EXTRA=` is now a rule read before the primary line, and `interim-loop`
  precedes the row that shadowed it.

- **`--max-rounds` is applied to the verdict in both loops, and is no longer a row in either table.**
  It was the last row of both, where every ordinary verdict matched something above it, so **the one
  brake that cannot be reached by waiting longer was the one thing waiting longer always skipped**.
  Moving it to the top is the obvious correction and is worse: the cap aborts a loop that **has not
  converged**, so a first row would abort a round that came back clean on exactly the round the
  operator budgeted for, and report a converged run as a failure. Neither position works, because
  the cap is not a signal the reviewer produces — it is a condition on what a signal is allowed to
  mean. The rule is now stated as one: read the table, and if the row it lands on says _continue_
  while the cap is reached, abort with `--max-rounds` as the reason; a clean finish at the cap is a
  convergence.

- **The local loop's `skill` confirmation no longer takes its own stop.** The bullet said "take
  confirmation of it before the first round" and the bullet below it promised that the `skill` and
  `requiresPr` confirmations are **one** stop — and step 1's judgements are read in order, so a
  reviewer setting both stopped twice. Two stops where one was promised teaches the operator that
  the stops are approximate, which is the wrong lesson about the only stop `--auto` cannot suppress.

- **Step 1 of the pull-request loop checks the reviewer's `kind` before it checks for a `trigger`.**
  `reason=not-a-github-reviewer` was added this release so a `local-command` reviewer passed to the
  wrong loop reports the right cause — but it sat _after_ the `no-comment-trigger` row, and the schema
  forbids a `local-command` reviewer from carrying a `trigger` at all. So the new row was unreachable
  for exactly the configuration it diagnoses, and every such run reported a missing field instead. The
  ordering is now stated in the row itself as the reason it exists. It unshadows
  `marker-not-tolerated` the same way, which such a reviewer also cannot carry.

- **`defaults.localReviewer`, because `defaults.reviewer` is one key and the two loops need different
  values.** Every configuration written before this release points `reviewer` at a `github-comment`
  reviewer, so the local loop reading that key would abort `not-a-local-reviewer` on every run until
  `--reviewer` was typed. Falling back to "the only local reviewer defined" would be a guess, which
  is what an unknown `--reviewer` already refuses to make.

- **`defaults.localMaxRounds`, for the same reason and a sharper one.** One key with a per-loop
  built-in was the first design, and it is wrong: a `maxRounds` written for the remote loop silently
  raised the local cap from 5 to whatever it said, and **the local loop's cap is the only brake it
  has** — a remote round announces itself with a push, a comment, a wait and a quota, and a local one
  announces nothing. Both stay settable from config, unlike `--accept-at`, because they bound spend
  rather than safety.

- **Two `local-command` presets, both `unverified`, with cards that say what that means here.**
  Each records **what the installed command declares**, read out of a named version, in a
  `### From the installed command` subsection. `reviewers/code-review.md` additionally carries five
  observed rounds in a subsection of their own, because the command was driven while this release was
  written; `reviewers/ecc-review-pr.md` has no such subsection, because it was not, and says so where
  the subsection would be. **Both stay `unverified`**, and `reviewers/README.md` now says why that
  word is narrower here: the bar for a local reviewer is the loop driven to convergence, and observing
  the command answer — five times or fifty — is not that.

  Two of those declarations are worth reading before choosing a preset. The built-in command's
  reporting surface **carries no severity field at all** — severity is only the order of the list — so
  its card carries no ladder and `--accept-at` aborts against it; its own per-round cap, 4 findings at
  the lowest effort rising to 15 at the highest, is the brake instead. And `ecc:review-pr`'s
  `critical` / `important` / `advisory` are a **confidence rule, not an output format**: they appear
  once each in a closing section, the command has no heading template, and the vocabulary that reaches
  the output comes from an agent it dispatches, which tags findings `CRITICAL` / `HIGH` / `MEDIUM` /
  `LOW`. That four-rung ladder is what the card carries, because a ladder taken from the documented
  three would name rungs the output never emits and `--accept-at important` would match nothing and
  block everything.

- **A third provenance form for reviewer cards: the artifact and its exact version, plus a month.**
  `ecc 2.2.0, 2026-09`. Neither existing form fits a local reviewer — it is not observed on a pull
  request and not inside a private repository — and an artifact version is **more** checkable than the
  anonymised form, since anyone can install that version and read the same file where nobody outside
  can open `repo C` at all. `tests/provenance.test.sh` pins it on the same axes as the other two, and
  `reviewers/README.md` states the limit the form carries: it cites a **declaration**, not a
  behaviour, and a card written from the artifact alone stays `unverified`.

  **A second limit is pinned rather than described**: the lowercase-name rule excludes capitalised
  prose before a version, and does **not** exclude this project's own name, so `revloop 0.4.0` plus a
  month passes as provenance for a bullet about somebody else's reviewer. Closing that means judging
  what a sentence is about, which is the judgement the per-sentence check was already declined for.
  There is a case asserting the gap exists, because a limit stated in a comment and contradicted by
  the code is worse than no comment — and this file had gone green on its own failure case once
  before.

**One thing this release does not claim, and the reason it is worth saying here.** The local
procedure and both its presets ship `unverified`. Rounds do exist: this release's own diff was put
through `claude -p "/code-review medium"` as the `code-review` preset specifies, five times, fixing
everything between rounds. It returned **9, 7, 6, 8 and 10 findings with not one recurrence among the
40**, and **every one was a real defect in this release's own new files**. **Every round after the
first found defects the previous round's fixes had introduced** — a stale claim left by a changed
rule, a rule interaction created by a fix, a truncation created by a budget, and a permission bypass
created by a grant.

**The run reached the local `--max-rounds` built-in of 5 without converging, with the last round
returning more than any before it.** That is the same outcome `.revloop/field-notes.md` records three
times for the remote reviewer, reached here in a fifth of the wall clock by a different reviewer.
**So "the reviewer eventually runs out of things to say" is not what ends either loop** — which is the
argument for `--accept-at` restated as a measurement rather than as a worry, on the release that adds
it. No run under the floor has been made yet, so whether it ends this one is the open question.

**The sample also corrected a premise this release was built on.** "A local round returns at once"
was written into the procedure, the design notes, the schema and both READMEs before anything was
measured, and it is false: the five rounds ran 5m27s to 8m39s, inside the remote reviewer's own
2:46–10:07. The
wall clock is not what separates the two loops. **What a round spends is** — and the local one spends
tokens, which nothing in the room displays. Every rule that had rested on "there is no cost to
notice" now rests on "the cost is invisible", which is the argument that was actually true.

**The sample contradicted the card it was written from, in two places.** The shape that came back was
neither shape read out of the binary, and round 1 returned nine findings where the documented cap for
that effort level is eight. **A card written from a declaration is a card that can be wrong**, which
is the limit `reviewers/README.md` now states for the artifact provenance form — demonstrated on its
first use, by the artifact it was added for.

**Both contradictions are the case `unparsed-review-output` exists for.** A parser written from the
declarations would have matched neither run, returned zero findings, and been read as a clean review.
That abort row was written before the sample and is the reason the sample cost nothing.

Changed:

- **Step 1 of the pull-request loop now aborts on a `local-command` reviewer, under its own reason.**
  Such a reviewer has no `trigger`, so the run already stopped — at `no-comment-trigger`, which names
  a missing field when the cause is a reviewer built for the other loop. `reason=not-a-github-reviewer`
  says which, and names the command that does drive it.

- **Step 12's report rule now has a no-ladder case, which the hardcoded-rung fix had not.** Replacing
  the literal `P1` with "the ladder's top rung" is correct for the three cards that carry a ladder and
  leads with nothing for `claude.md`, which carries none. With no ladder it leads with everything left
  unfixed.

- **Three tests now read every procedure in `commands/`, not the first one that existed.**
  `tests/permissions.test.sh`, `tests/fence-guards.test.sh` and `tests/procedure-refs.test.sh` each
  named `commands/review-loop.md` outright, so a second procedure would have been exempt from the
  granted-command check, the `allowed-tools` check and the line-number-citation check — **which is the
  same drift those files exist to catch, one level up**. The list is globbed rather than written out
  for that reason, and an unexpanded glob is failed on explicitly, because awk over a path that does
  not exist prints nothing and every subset check reads that as "no commands used". The marker guard
  stays scoped to the one procedure that posts a trigger; globbing it would report a missing marker as
  a defect in a file that posts none.

## [0.4.0] - 2026-08-31

**No fence changed, so nothing here asks anything of you.** The three shell fences in
`commands/review-loop.md` are byte-identical to 0.3.0 and still match the
hashes in `tests/fence-hashes.txt` — `tests/fence-guards.test.sh` reports all three matching, which is
the evidence for this paragraph — so there is **no re-approval to give**. The granted rule list in
[`docs/permissions.md`](docs/permissions.md) is unchanged too: the two new reads use
`gh api --paginate repos/{owner}/{repo}/`, a prefix the procedure already used and you already
granted, and `tests/permissions.test.sh` checks that in both directions. None of this is luck. The
re-post rule could have lived inside the wait fence, and putting it there would have cost every user a
Bash prompt for a rule a reader of step 9 can follow unaided; counting wait chunks against `--timeout`
was already the caller's job for exactly that reason.

Added:

- **A trigger that draws no verdict the loop can classify is now posted a second time, once.** The
  failure: a trigger comment is delivered, nothing the loop classifies comes back, and the round dies
  with the pull request, the diff and CI all healthy. (**"Classified" is the operative word** — a
  signal orphaned in the re-post gap leaves the round looking silent when it was not.) Step 8 returned
  `VERDICT=pending` until the budget ran out and step 9's table said `abort` — no path in the
  procedure sent the request again. Step 7 now carries one narrow
  exception to the runaway invariant, with five conditions that are all checkable from GitHub: the
  wait must have expired **and have spent at least three chunks watching your own trigger**, the
  `pending` line's baseline must be yours by both halves of the ownership test, no marker may already
  carry this round's `round=` with an `attempt` key, the round must have produced no classified verdict
  at all, and HEAD must not have moved.
  A rate-limit reply keeps its own row and that row still says **do not retry**; silence is the only
  signal the exception answers. The exception is carved **out of** step 9's exceeding-`--timeout`
  abort rather than standing beside it, so exceeding the budget always terminates the attempt and a
  round ends in at most two of them: written as several conditional aborts it left a hole, where a
  newer hand-typed trigger made every later `pending` a "continue" while blocking the re-post, and the
  caller polled forever.

  **The floor is three chunks — 24 minutes — and it is deliberately not a fraction of `--timeout`.**
  Deriving it from the flag was the first design and it is wrong: `--timeout 8m` would then re-post
  from inside codex's measured 2:46–10:07 range, which is the runaway the invariant exists to prevent,
  reachable by typing a flag. A fixed floor in the unit the caller already counts cannot be pushed
  below the measured ceiling by any flag value. Twenty-four minutes is about 2.4× the widest verdict
  ever measured, which leaves headroom on a card that records **every sample so far widening that
  range at one end or both**. Below the floor there is no re-post and the round aborts exactly as it
  did before, under a new reason, `timeout-before-retry`, that says so rather than blaming slowness.

  **The direction is the safety argument.** A re-post moves the baseline **forward**, so it can only
  reach the too-new row of the table in [`docs/design-notes.md`](docs/design-notes.md) — a verdict that
  arrived is dropped, a liveness failure for every class except the two abort-class comments, where
  ending clean rather than stopping makes it a safety one. It cannot reach the too-old row, where a previous round's
  "no issues" becomes this round's clean verdict. That makes it the mirror image of the refinement that
  document rejects — walking the baseline back to an older trigger — rather than a quiet
  reintroduction of it.

- **`attempt=` joins the trigger marker, and adding it cost no fence edit.** The fence parses the
  marker with a `case` over `key=value` pairs and has no default branch, so a key it does not know is
  skipped, and the jq program's character filter passes `attempt=2` through untouched. Both halves are
  now pinned rather than asserted — `tests/fixtures/verdict/retry-marker` through the shell, and the
  same fixture through `tests/jq-program.test.sh` for the filter. No fixture previously carried a
  marker with anything but the five documented keys — `v`, `reviewer`, `bot`, `head`, `round`, of which
  the fence parses the last four by name — so an unknown key was entirely unexercised.

  **The key is written only on a re-post.** Writing `attempt=1` on every trigger was the first draft
  and it is a cost with nothing bought: `reviewers/codex.md` records the marker being tolerated end to
  end against the five-key body, ten consecutive times, so a sixth key on every round would move every
  round onto a body shape nobody has watched a reviewer accept — to record a `1` that its absence
  already says. Confining it to the re-post also keeps the round count a presence test on one key
  instead of a comparison against a number, where `attempt=1` versus `attempt=10` is the input-space
  trap step 10 spends a paragraph on.

  **`v` stays at `1`, and step 7 now says when it would move**: only when an existing key changes
  meaning or disappears — when a reader of the old format would misread the new one. Adding a key does
  not qualify. That criterion did not exist before, which is the only reason the question was open;
  spending the version signal on an additive change teaches the next reader that `v` moves for
  anything, and makes a genuinely breaking change indistinguishable.

- **Step 7 shows the command it has always prescribed.** "Count the markers from GitHub" had no block
  behind it, which is the prose-prescribed-command drift `tests/permissions.test.sh` was written after
  finding three times over. One `--paginate` read now yields all three facts step 7 needs: the round
  number, whether this round has already been re-posted, and — on a run resuming in a fresh session —
  the `SINCE` steps 8 and 9 reconcile against. **`SINCE` on a resumed run was undefined**; both steps
  said "the `SINCE` you recorded in step 7" and a session that died recorded nothing. It is now the
  `created_at` of the newest marker on the pull request.

  The read filters `.user.type != "Bot"`, which is the fence's own `__typename != "Bot"` rule spelled
  for REST. Without it the read would be a second implementation of "who may anchor a trigger" that
  disagrees with the first: a bot quoting the marker literal would inflate the round number, and a bot
  body carrying `head=` and `attempt=` would satisfy the re-post condition and **suppress a re-post
  the round was owed**. The two spellings were measured on `iwmaeda/revloop#11` (2026-08) —
  `chatgpt-codex-connector[bot]` is `type=Bot`, `iwmaeda` is `type=User`. This was found by the
  definition sweep the procedure's own step 3 prescribes, before the reviewer saw the change.

Fixed:

- **A round that fires twice can be answered twice, and one of the two answers was being dropped.**
  This is the sharpest thing the re-post changes and nothing pre-existing caught it. If both reviews
  land before the retry chunk's first poll, the fence returns the newer one and never mentions the
  older — there is no `EXTRA=` for a second review, only for a comment — and step 10's filter is an
  equality test on that single `review_id`, so the other review's findings are lost for the life of the
  pull request, since the next round's baseline is newer than both. Step 9's "commit is an ancestor of
  HEAD" row cannot catch it: **both reviews name the same, current commit.** Step 10 now reads every
  review by the reviewer at the current HEAD, at or after the round's first trigger, on a two-trigger
  round, and fails closed if that read
  fails, because REST 404s for many minutes while GraphQL keeps answering and an empty result is
  indistinguishable from "only one review". `tests/fixtures/verdict/retry-both-answered` pins the fence
  returning one of two same-commit reviews with no signal that the other exists.

- **Step 8's `SINCE` reconciliation was unbounded, and could never terminate.** "If they differ,
  discard that verdict and re-fire step 8" has been in the procedure since before this change, and it
  has no bound. A mismatched **verdict** exits the fence on its **first** poll, so it burns no wall
  clock and accrues no chunk — which means that against a baseline that is permanently newer and
  already answered, such as a hand-typed trigger posted after yours, the re-fire never reaches
  `--timeout` and never sleeps. A mismatched `pending` is the other shape and does spend its chunk, so
  neither can be bounded on the clock: the first never reaches it, and the second would make the bound
  depend on what somebody else posted.
  That is the infinite loop `## Notes` names for the fence, reached from the caller instead. It was
  the last unbounded re-fire in the procedure; every other one already reads "once" or "a second time
  aborts". It is now two consecutive mismatches, then `reason=foreign-baseline`, and a matching
  `trigger=` resets the count. The rule also now covers `review`, `comment` and `reaction` explicitly
  rather than only a verdict: all four are treated as `pending` so step 9's rows decide, which is the
  same "one exception, one catch-all" shape as above.

- **The runaway invariant and step 9's `marker_head=none` recovery contradicted each other.** That row
  says to fire revloop's own trigger in step 7, at an unchanged HEAD — which the invariant, as this
  change first restated it, forbade. The premise is what the invariant actually protects: it bars a
  second trigger while one of yours can still bind a verdict. Two states end that premise, and **only
  one of them is recovered inside the run**: no verdict of yours classified, which is the re-post with
  `attempt=2` and the same `round=`. A newer trigger taking the baseline **aborts** — an abort is a
  stop, and the loop must not race a person for the newest comment, which is the runaway itself — and
  a later run re-takes the baseline with an **ordinary** trigger that advances the round, because the
  wait it replaces was spent. Getting this wrong the other way was itself caught in review: an earlier
  draft classified the lost baseline as an in-run recovery, which contradicted "an abort is a stop"
  in nine places at once. `marker_head=none` and `reason=foreign-baseline` now both read "report and
  finish", and so does `error reason=no-branch`, which had the same shape before this change.

- **A two-trigger round could finish clean without ever running the review sweep.** The sweep lives in
  step 10, which the table reaches from `VERDICT=review`, so a round whose terminal signal was a
  clean **comment** or a reaction went straight to step 12 — which is precisely the case the sweep
  exists for. A review of the current commit orphaned before the re-post was then never read, its
  findings never replied to, and with `--auto --merge` the loop merged on the second trigger's clean
  signal while an unread review of that same commit sat on the pull request. That is one of the two
  ways the re-post path could produce a wrong merge, and the only one closed here; the other is an
  orphaned abort-class comment answered clean on the second trigger. Step 9 now gates every clean
  finish on the sweep,
  because step 9 is the only place both the clean path and the findings path pass through. A
  single-trigger round is unaffected: there is no second answer to miss.

- **The lost-baseline recovery was unreachable after a restart, which made the abort permanent.** Step
  7's marker read selected only comments carrying the marker, so it could not see the hand-typed
  comment that took the baseline. A resumed run at unchanged HEAD found only its own marker, concluded
  the runaway invariant blocked it, waited, reached `reason=foreign-baseline` again and aborted —
  forever, with the recovery the entry above promises unreachable. The read now returns every non-bot
  comment and marks the unmarked ones, and step 7 says what to do with a newer one: **ask the fence**,
  by firing step 8 once and reading its `trigger=`, rather than replaying the fence's compatibility
  pattern outside it. That pattern under-matches custom triggers into the same deadlock and
  over-matches into licensing an extra trigger, so neither direction of guessing is available — which
  is the same reason the round number does not count hand-typed rounds.

- **Baseline ownership was decided by a second-resolution timestamp.** The fence sorts triggers by
  `createdAt` and, within a second, by `databaseId` — a tie-break this repository added in 0.3.0 and
  pinned with its own fixtures, because two triggers in the same second are a different input from two
  a second apart. Every ownership test this change introduced compared `trigger=` alone, so a
  hand-typed comment posted in the **same second** as the marker with a larger id wins the baseline
  while reporting a timestamp identical to yours: the lost-baseline recovery then never runs, and the
  re-post condition that exists to keep a retry off a foreign baseline is satisfied anyway. The test is
  now both halves — the timestamp, **and** no non-bot comment sharing that second with a larger id —
  and both come out of the read step 7 already performs, so nothing classifies a comment as a trigger
  outside the fence. Step 9's check (c) additionally compares `round=`, because a verdict line carries
  the winning marker's own fields and can say outright which trigger won.

  **A round that only ever sees `pending` under an unclaimable baseline aborts and is handed to a
  human**, and that corner is deliberately not auto-recovered: a `pending` line carries no marker
  fields, so closing it would mean teaching the fence to emit them — a re-approval for every user,
  against a case that needs a same-second collision to reach.

- **The retry budget was searched for as a substring, so `round=1` matched `round=10`.** The rule that
  decides whether this round has already spent its re-post said "substring search" in as many words,
  which means a marker from round 10, 11 or 100 satisfies a search for round 1 and the round is refused
  a re-post it was owed. This is the `attempt=1` versus `attempt=10` trap the procedure already names
  for a predicate's input space, reintroduced in the rule that spends the budget. Both the budget check
  and the round count now split the marker payload on whitespace and compare whole `key=value` tokens.

  The related read was checked and **deliberately left alone**: the marker scan selects on
  `contains("revloop:trigger ")` because that is exactly what the fence's own `TRIG` generator does, so
  a human comment quoting the literal anchors a baseline whatever this read thinks. Making the read
  stricter than the fence would be a second implementation of "what is a trigger" that disagrees with
  the first — the defect class this branch already fixed once. Agreement is the requirement; parsing is
  where the care goes.

- **Step 10's review sweep excluded a review sharing its second with the round's first trigger.** These
  timestamps have second resolution and the bound was strictly "after", and the two ways of being wrong
  are not equally bad: including a review that shares the second costs a re-read of findings that may
  already be answered, while excluding one drops a review of the current commit on the path that
  merges. The bound is now inclusive.

  What is **not** a hazard, and was checked rather than assumed: a review racing a clean comment. The
  fence returns a review whenever one exists **and is strictly newer than the trigger**, and demotes
  the comment to `EXTRA=`, so a clean comment cannot outrank findings that arrived after it. A review
  sharing the trigger's own second is the exception and is a known gap; see `## Notes`.

- **Two lookups were keyed on `head=` where they had to be keyed on the round.** Both became wrong the
  moment the lost-baseline state was allowed to open a **new** round on an unchanged HEAD, which is a
  consequence of this same branch. The re-post bound searched the pull request for any marker with
  this `head=` and an `attempt=`, so a previous round's re-post spent the new round's budget and
  reported `attempts=2` for a round that had sent one trigger; it now matches on this round's `round=`,
  and an unparseable marker counts as a match, because withholding a second trigger is the safe
  direction. Step 10's two-trigger read took every review whose `commit_id` was HEAD with no lower
  bound, so it swept in the previous round's reviews of the same commit and re-opened answered
  findings; it is now bounded below by the round's first trigger. The second was found by sweeping the
  class rather than by review.

- **Step 10's two-trigger sweep compared two values that can never match, so it swept up nothing.**
  The read emitted REST's `user.login` and `commit_id` raw and then asked for the reviewer's login and
  HEAD. REST carries the `[bot]` suffix the marker's `bot=` has stripped — the mistake `## Notes`
  records as having shipped once already — and `commit_id` is the full 40-character sha, while every
  other HEAD comparison in this procedure is the short-8 form the fence writes. Either one alone
  matches **zero** reviews on every run, and zero is indistinguishable from "only one review": the
  sweep this branch added would have reported nothing, the round would have finished clean, and
  `--auto --merge` would have merged past findings nobody read — silently reintroducing the defect the
  sweep exists to fix. Both fields are now normalized in the read itself, mirroring the fence's own
  `BOT=${BOT%"[bot]"}` and `.commit.oid[0:8]`, so the value the reader is handed is the comparable
  one. The fail-closed rule now names **both** reads rather than only the list: a failed per-review
  `comments` read is indistinguishable from "that review had zero inline comments", which is a clean
  review, and it runs once per review, so a two-trigger round takes that risk twice.

- **Step 7's new marker read had no failure rule, on the one endpoint this procedure says 404s.**
  `## Notes` records `repos/…/issues/<n>/comments` returning 404 continuously for many minutes while
  the same token's GraphQL kept answering, and an earlier REST-based wait reporting a pull request
  carrying 22 triggers as `no-trigger` — the wait is built on GraphQL for that reason. The new read is
  that endpoint. An empty result read as "no markers" restarts the round number at 1, hands the
  re-post condition an empty pull request and so refunds a budget the round has already spent, and
  leaves `SINCE` with no left-hand side. Failure is now decided from `gh`'s exit code alone, the way
  step 8 already decides it, and a failed read means do not fire and do not re-post.

- **"This round's `round=`" was undefined on a resumed run, which is the only run the bound matters
  on.** The procedure defines the round number once, as the count of round-opening markers plus one —
  a count that deliberately excludes a re-post. A session that died mid-wait therefore came back and
  computed N+1 for a round still at N, asked the re-post condition about a round that did not exist,
  found no `attempt=` marker, and re-posted a second time; the session after it would have done the
  same, because the marker it should have found is the one the count excludes. The whole bound rests
  on that condition — "it cannot re-post twice, because it reads that from the PR" — so this was the
  guarantee failing exactly where it was claimed. A resumed run now takes this round's number from the
  newest marker, the same marker `SINCE` already comes from, together with whether the round has been
  re-posted and which comment is its first trigger. This is the `SINCE` gap above, one field over, and
  it was left standing when that one was closed.

- **What a reconciliation mismatch costs was stated three ways, and the absolute one was wrong.** Step
  8 said a mismatch "burns no wall clock and accrues no chunk", while its own chunk-counting paragraph
  and step 9's table both said the chunk counts toward `--timeout`. The two are right about different
  inputs: a mismatched **verdict** exits the fence on its first poll and costs nothing, but a
  mismatched **`pending`** means the foreign trigger is itself unanswered, so the fence polls out all
  480 seconds before printing — and that is the only other shape a mismatch arrives in. Neither may be
  bounded on the clock, which is what the two-consecutive-mismatch rule is for. The false half had
  been copied into this changelog as well, and is corrected above. **Only step 8's re-fire paragraph
  and this changelog were corrected then**; the two normative statements named in the sentence above
  kept the absolute rule, and the entry below closes them.

- **The list of what the re-post gap can drop named two comment classes; there are four.** The window
  between an expiring chunk's last poll and the new trigger loses any signal landing in it, and the
  sweep recovers only reviews — it reads `pulls/<n>/reviews` and never comments. The accepted-cost
  argument, that the behaviour being replaced is an abort which loses the same signal **and** the round
  with it, holds for a clean verdict and a rate limit, because both repeat themselves. **It does not
  hold for the two abort-class rows.** An unrecognized bot body and an `interim-loop` exist to stop the
  loop and hand it to a human; losing one used to end in an abort anyway, but now, if the second
  trigger answers clean, the round finishes clean and merges. That is strictly worse than what it
  replaces and it is the one cost of this path that is not offset. It is written down rather than
  closed: closing it would mean classifying comments outside the fence, a second implementation of a
  rule the fence owns, which is the defect class this branch has already reported twice. The report
  now says a signal may have been orphaned on **any** two-trigger round, not only on `no-verdict`.

- **Two of this branch's own new tests could not fail for the reason their comments gave.**
  `fence-guards` checked each required marker key with a substring match, so a marker whose `head=` had
  been typo'd to `marker_head=` satisfied the test while parsing to exactly the `marker_head=none` the
  block exists to catch — the guard going green on its own failure case, by the same
  substring-for-token mistake the procedure states a rule against twice. It is anchored to a token
  boundary now. `fence-verdict`'s `retry-baseline` comment claimed its assertions pinned that a re-post
  does not advance the round; they cannot, because both triggers carry `round=3` by hand and the fence
  has no round-counting logic to get wrong. That comment now claims only what the assertion checks, and
  says plainly that the rule itself lives in prose this harness does not execute.

- **The mismatch-cost split was written in the paragraph that explains it and in neither that
  instructs.** The round before this one named three statements of what a reconciliation mismatch
  costs, worked out that they are right about different inputs, and then corrected one of them and
  this changelog. The two it left are the two a reader follows as instructions: step 8's
  chunk-counting paragraph and step 9's foreign-baseline row both still said flatly that the chunk
  counts toward `--timeout`. A mismatched **verdict** exits on the fence's first poll and spends no
  wall clock, so charging it a chunk overstates the wait by eight minutes each time — two instant
  foreign verdicts followed by two real `pending` chunks are charged the four chunks that stop an
  attempt at the built-in `30m`, so the round aborts its own trigger having actually waited sixteen
  minutes rather than thirty-two. Both now carry the split, and both keep the half that was never in
  doubt: a mismatch watched somebody else's baseline, so it never counts toward step 7's floor and
  can never authorise a re-post. **The class was named too narrowly rather than missed** — the
  previous entry's own first sentence lists all three sites — so it is recorded here as one fix
  applied at every site that states the rule, and the sweep that found them is a grep for the rule
  rather than for the wording.
  `docs/` states the floor and the budget arithmetic but never what a mismatch costs, so nothing
  there needed the same edit.

- **The same narrative-versus-normative split ran through four more rules, across seven files.** Asked
  to list every sibling of the class above rather than the first, the reviewer returned four sets, and
  all four held up against the text. **(1) The runaway invariant admits two firings at an unchanged
  HEAD, not one.** The silence re-post is recovered inside the run; the lost-baseline re-take is
  performed by a later run, once it can establish the baseline is foreign. Step 7's opening imperative,
  the `## Notes` bullet calling silence "the single exception", and `.agents/skills/revloop/SKILL.md`
  all admitted only the first, so following them literally prevents the recovery the same documents
  prescribe. **(2) "Never answered" overstates what the loop knows.** The operative condition is "no
  classified verdict", and a signal can be orphaned in the gap between an expiring chunk's last poll
  and the new trigger, so silence is what was _seen_ rather than what was _sent_. Step 7's prose, the
  re-post section, the field-notes sentence, step 9's re-post row, both READMEs and
  `docs/design-notes.md` all claimed literal silence. **(3) Exceeding `--timeout` does not always
  terminate the round**, only the attempt; the round ends in at most two. **(4) The re-post path can
  reach a wrong merge, and four places said otherwise** — the `## Unexercised paths` preamble claiming
  every listed branch fails closed "never toward a wrong merge" while listing the re-post,
  `docs/design-notes.md`'s too-new row and its "spends nothing it was not already spending", and
  `docs/configuration.md` calling 64 minutes "the whole cost". The procedure's own cost paragraph
  already says the opposite for the two abort-class signals: losing one used to end in an abort, and
  now a clean second answer can finish the round and merge past it. Every normative copy now carries
  the distinction its explanatory paragraph already required. **No behaviour changed and no fence
  changed** — this is the wording that instructs being brought level with the wording that explains.

- **Closing four sets left five more, two of them opened by the previous round's own edit.** The same
  request, repeated once the first four were closed, returned: **(1)** three places still saying step
  10 is reached only from `VERDICT=review` — step 9's pre-table gate, this changelog, and a comment in
  `tests/fence-verdict.test.sh` — when the gate that paragraph introduces is exactly what now routes a
  two-trigger clean comment or reaction into the sweep; **(2)** `docs/design-notes.md` crediting an
  orphaned review's survival to the reviewer answering the second trigger and to `commit=` pinning it,
  neither of which is guaranteed, when what recovers it is step 10's round-bounded sweep; **(3)** two
  copies still calling the missed-review case "the one way" the re-post could cause a wrong merge,
  which the abort-class orphan path contradicts; **(4)** the runaway invariant's bolded imperative
  still reading "fire only when HEAD differs" three lines above the sentence saying two firings at an
  unchanged HEAD are correct; and **(5)** `## Notes` and `SKILL.md` prescribing "every review at HEAD"
  without the configured-reviewer filter the operative rule in step 10 carries, which would sweep
  another bot's findings into this round's replies. **(3) and (4) were introduced by the previous
  round's fix** — it added each qualification next to an absolute statement it left standing, which is
  the same one-member-of-the-class failure that round was fixing. Sweeping the three shapes across the
  tree afterwards found **two more the review had not cited**, both in the same `## Notes` bullet: the
  stale control flow again, and an unfiltered "any review whose commit is HEAD". No behaviour and no
  fence changed.

- **Two of the next four were control flow, not wording.** **(1)** Step 9's pre-table check (c) said to
  abort whenever `marker_head=` or `round=` differs, which is true **only once the baseline is yours**:
  a foreign baseline carries a different `head=` and `round=` as a matter of course, so a reader
  performing the checks in order aborted on the first mismatch and never reached the
  "continue (twice)" reconciliation the table promises. (c) is now explicitly conditional on (b).
  **(2)** Step 10 opened with "step 8 already emitted `review_id=`", which the clean-comment and
  reaction gate had just made false — those rounds reach step 10 with no review id at all, and the
  ID-keyed query returns nothing. Step 10 now names both entries and sends the gated one straight to
  the two-trigger sweep. **(3)** Four more copies of the literal-silence claim sat beside the
  "no classified verdict" qualification. **(4)** The too-new drop was still classified as a liveness
  failure in three places, including the class column of the `docs/design-notes.md` row whose
  consequence column the previous round had already corrected — the same fix-one-column failure, one
  column over. It is a liveness failure for the classes that repeat or are recovered and a **safety**
  failure for the two abort-class comments, which end clean rather than stopping. Sweeping afterwards
  found one more the review had not cited: a comment in `tests/fence-verdict.test.sh` still carrying
  the unqualified "it is accepted" argument. No behaviour and no fence changed.

- **P1: the ordered pre-checks made the whole re-post path unreachable.** Step 9 said to "check five
  things before consulting the table", and the five were written as though every verdict carried every
  key. The fence does not work that way: `VERDICT=pending` emits only `pr=`, `trigger=` and `waited=`,
  so **(c) and (d) could not be satisfied by any `pending` line at all** — and read literally that is
  an abort on the first silent chunk, before either `pending` row is ever reached. The re-post this
  branch exists to add was unreachable, and so was plain "continue". The same mismatch reached three
  more forms: `reaction` carries no `login=`, so (d) stood between it and its clean row; the error
  forms carry neither `trigger=` nor a marker, so they aborted at the wrong check and reported the
  wrong reason rather than landing on their own rows; and on a compatibility baseline the marker
  carries no `bot=`, so the fence's filter admits any bot and (d) could classify a lost baseline as
  "another bot's verdict" — an abort either way, but one that loses the lost-baseline row's promise
  that a later run re-takes the baseline. Each check now names the forms it applies to, as (e) already
  did, over a table of which form emits which key; `marker_head=none` is given precedence over the
  login check in both the check and the table row. **The fence was already right** — this is the
  caller's reading of it being corrected, so no fence changed and no re-approval is owed.

- **P1: four more reads of values their producer does not always supply.** Read against the fence text
  rather than the prose: **(1)** "always reconcile the returned `trigger=`" applied to every output,
  but no `VERDICT=error` form emits `trigger=`, so an auth or connectivity failure was sent into the
  foreign-baseline retry instead of onto its own row; it is now scoped to the four forms that carry
  one. **(2)** The fence takes every review that is not `DISMISSED` and then drops the state from its
  output, and step 10 repeated the same rule — which admits a `PENDING` draft, a review with no
  findings and no `submitted_at`. Step 10 excluded `PENDING` explicitly at this point — **superseded
  two entries below**, where excluding it in the selection turned out to drop the very review whose
  state should stop the round; step 10 now keeps it and lets the state table abort. **(3)** "A clean comment
  cannot outrank findings that arrived in the same round" was stated in the procedure and in this
  changelog, but the fence selects reviews with `$2>t`, so **a review sharing the trigger's own second
  is not selected at all** and a later clean comment wins the round. The trigger selection solves that
  collision with a `databaseId` tie-break; the review selection has no equivalent. Both copies now say
  "strictly newer" and name the gap, which is recorded rather than closed because closing it is a
  fence edit. **(4)** "`MERGE=failed` means the PUT was fired and did not take" was stated in the
  procedure and in `SKILL.md`, but the fence also prints it when the post-PUT status read **fails** —
  `ST` is empty then, which a successful merge can also produce. Both now say the fence could not
  confirm it took, and say to read the pull request rather than re-fire. No fence changed.

- **A review arrived with zero inline comments and a P1 in its body, which two rules said was
  impossible.** Step 10 opened "a review body is boilerplate or empty; the findings are inline review
  comments", and step 9's table read a review with zero inline comments as a clean finish. Measured on
  this pull request's round 16, codex returned a `COMMENTED` review on the current commit whose
  `pull_request_review_id` matched **zero** rows in `pulls/<n>/comments` and whose body carried a
  complete P1 with a severity badge. Counting inline comments would have reported that round clean and,
  under `--auto --merge`, merged past it. Step 10 now reads the body as well as the comments and treats
  a body carrying a severity badge as findings; the table row is "not clean by itself"; and
  `reviewers/codex.md` records the observation as a tendency rather than a contract. **This was found
  by reading the body before acting on the count, not by the count.**

- **The `PENDING` exclusion had been added to one of the two paths.** The previous round excluded
  `PENDING` from step 10's two-trigger REST sweep and left the single-trigger path with nothing — the
  wait fence admits every review that is not `DISMISSED` and drops the state from its output, so a
  draft reaches `VERDICT=review` indistinguishable from a submitted one. Step 10's new body read
  doubles as the state check. Four prose/fence mismatches closed alongside it: step 12's text said
  everything that is not a pass "falls back to `retry`" when a fifth consecutive fetch failure is
  `CI_WAIT=error` and a completed failure is `CHECKS_FAILED`; `## Notes` forbade terminal exits for
  continue rows when the fence exits for **every** review including the ancestor row, which is bounded
  by the caller's one re-fire rather than by the fence; `## Notes` said every fence resolves the
  branch first when `wait-verdict` reads `gh repo view` first and can exit before the branch is
  looked at; and step 12 asked for the merge response body on every non-`ok` result when an abort
  exits before the PUT and has none. No fence changed.

- **Three P1s, all of them made by the fix in the entry above.** **(1) The body read went to one path
  again.** The two-trigger sweep returns metadata and then reads inline comments per `id`, so the
  direct review's body was the only body ever fetched — and the sweep is the **only** reader for a
  review orphaned in the re-post gap, and the only reader at all on a round entering step 10 from the
  clean-comment or reaction gate. The measured body-only finding was therefore still dropped on
  exactly the two paths that exist to recover it. The sweep now reads each selected review's body and
  state alongside its comments. **(2) The new `PENDING` handling was an infinite loop.** It said to
  treat a draft as `pending` and re-fire step 8; the fence keeps every non-`DISMISSED` review and
  exits on its **first** poll, so each re-fire re-selects the same draft with no wall clock spent, no
  chunk accrued and nothing bounding it — the exact loop `## Notes` names, introduced two paragraphs
  after the note that names it. `PENDING` now aborts with `reason=draft-review`, because a draft stops
  being one only when its author submits it. **(3) The state check enumerated one state and let the
  rest through.** `CHANGES_REQUESTED` with no inline comments and a body without a severity badge was
  read as clean and merged, though the state itself says otherwise; so was any state GitHub adds
  later. Step 10 now has a state table: `COMMENTED` and `APPROVED` are read for findings,
  `CHANGES_REQUESTED` **must** produce findings or abort, `PENDING` aborts, and an unrecognised state
  aborts with `reason=unknown-review-state`. No fence changed.

- **The two readers are now one read, because splitting them failed twice in opposite directions.**
  The round before last gave the direct path a body read and left the sweep reading comments only;
  the fix for that gave the sweep a body read and left it reading **only** that — so on a round
  entering step 10 from the clean-comment or reaction gate, where the direct query is skipped, an
  inline-only finding on an orphaned review was never loaded. One half missing on each path, one
  round apart, each introduced by the fix for the other. Step 10 now states **the per-review read**
  once — body and state, plus inline comments — and both paths invoke it by name on whichever `id` is
  in hand, rather than restating half of it each. The fail-closed rule covers both halves, and its
  reasoning is corrected too: it still said an empty `comments` read looks like "zero inline comments,
  which is a clean review", which stopped being true when zero inline comments stopped being clean.
  **Two of the three shapes this round asked about came back with no instances** — the state table's
  stop default holds, and every retry bound is stated where its retry is. No fence changed.

- **The sweep filtered out exactly the reviews whose state was supposed to stop the round.** Its
  selection read "the reviews whose `state` the table above does not abort on", which looks like an
  application of the state table and is its inverse: a `PENDING` or unrecognised review was **removed
  from the sweep instead of aborting**. On a two-trigger round whose second trigger came back clean,
  the reviews saying "do not finish" were the ones discarded and the clean path merged — the stop
  default defeated by running the selection before the check it defaults to. The selection now
  narrows by **identity only** — login, commit, round — drops `DISMISSED` alone, and hands every
  surviving review to the state table. A second hole in the same selection is closed with it: a
  `PENDING` review has no `submitted_at`, so the "at or after this round's first trigger" bound
  discards it too. The bound now applies only to reviews that have a timestamp, and a review by the
  reviewer at HEAD with none is a draft that aborts. No fence changed.

- **One copy of the superseded `PENDING` rule was left in `## Notes`.** The entry above changed step
  10 from excluding a draft review to keeping it and letting the state table abort; the note
  describing the same gap still read "step 10's own read excludes those explicitly". Following that
  copy reinstates the defect the entry above fixed — on a two-trigger round whose second trigger
  returns clean, the stopping review is dropped from the sweep and `--auto --merge` proceeds. The note
  now says keep, says why a selection that drops the stopping review defeats the stop, and records
  that its own earlier wording was the last instance of that mistake. **This was round 20, the run's
  cap: the fix is committed but no review round has seen it.** No fence changed.

- **Ten more latency samples, and the range's low end moved.** `iwmaeda/revloop#13` rounds 11–20 ran
  4:21, 4:18, 4:46, 3:51, 7:25, 6:57, 5:42, 4:55, **2:46** and 3:21 — trigger `createdAt` to review
  `submittedAt`, as the earlier samples were timed. Twenty-seven rounds in this repository now span
  **2:46 to 10:07**. `reviewers/codex.md` carries the sample, and the three operative copies of the
  figure — step 7's floor rationale, step 9's runaway argument, and both READMEs — are updated with
  it. **The three-chunk floor is unchanged and its derivation still holds**: it was chosen as roughly
  2.4× the **10:07** end, which this sample did not move. The card's "every sample has moved both
  ends outward" is corrected to "one end or both", since this one moved only the low end.

Changed:

- **`--timeout` now caps one trigger's wait rather than one round's.** A round fires at most two
  triggers, so its worst case is about twice the flag, rounded up to whole chunks each time: the flag
  is a threshold the chunk count must exceed rather than a stopwatch, so the built-in `30m` runs an
  attempt for 32 minutes and a re-posting round for **64, not 60**, where it used to be 32. That is the price of not
  losing a round to a single dropped comment, and `--timeout`
  is the dial that buys it back. Splitting the existing budget in half instead was considered and
  rejected: it judges a trigger dropped after 16 minutes, only 1.6× the widest measurement. The
  built-in value does not change, and neither does the schema — `"pattern": "^[0-9]+[smh]$"` already
  accepted every value this affects. [`docs/configuration.md`](docs/configuration.md) carries the same
  wording.

- **The round number now excludes re-posts.** It remains the count of `revloop:trigger` markers plus
  one, except that a marker carrying `attempt=` re-posts a round already open and is not counted.
  Without the exclusion a reviewer that drops one comment silently halves `--max-rounds`, which is a
  circuit breaker rather than a target and cannot afford to be spent on delivery failures. The count
  stays a one-line test anyone can reproduce, and it reads the marker's `attempt` key rather than
  searching the body: a raw search matches `notattempt=2` and a quoted `"attempt=2"` in a garbled
  payload, and either would undercount the round and suppress a retry it was owed.

- **The number of re-posts, and the silence threshold, are fixed and not configurable.** A budget above
  one has nothing measured behind it, and it spends the reviewer's quota — the same class as `--merge`,
  so not something the repository you happen to be standing in gets to raise.
  `docs/configuration.md`'s "deliberately not configurable" table says so, alongside the reason the
  threshold is not derived from `timeout`.

- **`reviewers/codex.md` no longer claims nothing in the loop depends on its latency figures.** That
  was true and is not: the three-chunk floor was chosen as roughly 2.4× the 10:07 end of the measured
  range, so a sample that widens that end is now a reason to revisit the floor. The card is still not
  read at runtime.

**This path has not been run against a live reviewer**, and `## Unexercised paths` says so. The
fixtures pin what the fence does with an `attempt=` marker, which trigger wins the baseline, what
happens to a signal orphaned between the two, and what the fence reports when both triggers are
answered — but no fixture can show that a reviewer answers the second trigger. The failure that
motivated the change is **reported rather than measured**: there is no PR, no date and no waited-for
duration to cite, so `reviewers/codex.md` gains no entry for it — a card claim with no source is worse
than no claim, and the only edit to that card is the correction noted above. Step 7 appends one line to
`.revloop/field-notes.md` on every re-post, successful or not; that is the sample that would turn the
floor from derived into measured. One thing checked and dismissed while writing this: the fence's
`comments(last:40)` window is a suffix, and a re-post adds one comment **before** the next verdict, so
the window is unaffected.

## [0.3.0] - 2026-08-25

**The `wait-verdict` fence changed, so every user owes one re-approval.** A fence is granted as its
own permanently identical command string, and this release edits that string; `wait-ci` and `merge`
are untouched and still match the hashes in `tests/fence-hashes.txt`. **There is nothing to
re-copy** — [`docs/permissions.md`](docs/permissions.md) is byte-identical to 0.2.0, so the granted
rule list is exactly the one you already have. The Bash prompt simply returns once, the next time the
loop reaches step 8, and approving it there restores zero prompts per round. That prompt is the point
rather than a cost of doing business: it is how you learn that the bytes you granted standing
permission to have changed. Nothing else asks anything of a reader who already installed 0.2.0 — the
command name, its flags, and the `.revloop.json` schema are unchanged.

Fixed:

- **wait-verdict fence: the baseline was chosen by position, not by time.** The fence's jq program
  builds one array from four generators, and array construction preserves generator order — so every
  compatibility (`compat=1`) row is emitted after every marker row, however much older it is. Taking
  the last `TRIG` row therefore selected the newest **hand-typed** trigger whenever one existed at all,
  rather than the newest trigger. On a pull request driven by hand before revloop was adopted those
  comments are permanent, so the baseline could never move forward. Measured on
  `MIRock-jp/hippoblogs#98` (2026-08): three hand-typed `@codex review` comments from one day and a
  revloop marker from the next produced `trigger=2026-08-24T04:13:01Z`, `marker_head=none`, and the
  **previous** round's review reported as this round's verdict. The cost was a skipped wait rather than
  a slow one — a review newer than an ancient trigger satisfies the exit condition on the first poll.
  Step 9's `SINCE` reconciliation caught it and the round failed closed, but no re-fire could converge,
  because the trigger that lost was revloop's own. Trigger rows are now sorted by `createdAt`, and
  within one second by `databaseId`, before the newest is taken; `LC_ALL=C` keeps a locale's collation
  out of it. Two consequences ride along: a compat baseline carries no `bot=`, and an empty `bot=`
  disabled the fence's bot filter, so a foreign bot's review could be read as the reviewer's — and step
  9's `marker_head=none` recovery, "let revloop fire its own trigger, then re-run step 8", now
  terminates instead of looping forever. The fence gained one utility, `sort`, alongside the `awk`,
  `grep` and `tail` it already used.

  The untriggered-verdict diagnostic had the same defect and is fixed in the same edit: it merged the
  review and comment generators, so `bot=` reported the newest **comment**, or a review only when no
  comment existed, never the newest signal. Diagnostic-only, and batched deliberately — fixing it later
  would have cost every user a second re-approval for a one-line improvement.

  **This changes fence bytes.**

  Verified against real data with the limit stated: `MIRock-jp/hippoblogs#98` is merged, so
  `gh pr list --state open` cannot resolve it and the fence could not be run end to end against it.
  Its real payload was fetched with the fence's own query and put through the fence's own jq program,
  which reproduced the inverted order; the fix was then applied to those real rows. The fixtures carry
  both representations — `graphql.json` for CI, where a real jq runs the program, and the recorded
  `rows` for machines without one, because the previous bug of this family was invisible to row-level
  fixtures.

  The `databaseId` tie-break is pinned by its own pair of cases, because the primary key decides every
  other case in the suite and would leave the secondary key unreachable: two triggers one second
  apart is a different input from two in the same second. Both orders are covered. With the sort
  removed, the first of the pair returns a **foreign bot's review as the reviewer's verdict** — a
  compatibility baseline carries no `bot=`, and an empty `bot=` disables the filter — so the two
  mechanisms compound, and `docs/design-notes.md` now records that they do. That document owns the
  baseline argument and stated the two failure directions without saying how "newest" is computed;
  it now says, and notes that the compatibility class anchors only while it is the newest trigger.

Changed:

- **The round number now says what it counts.** It remains the count of `revloop:trigger` markers plus
  one — the arithmetic is unchanged and no fence is involved — but step 7 and
  [`docs/configuration.md`](docs/configuration.md) now state that it counts revloop's rounds rather
  than the pull request's, so a pull request adopted mid-flight restarts at 1 while its commits and
  replies are already several rounds deep. Counting the hand-typed rounds too was considered and
  rejected: the compatibility pattern recognises a fixed set of reviewer names and matches no custom
  trigger at all, so it would trade a known undercount for an unknown one, and it would mean replaying
  a fence's classification outside the fence. Step 7 now requires both numbers to be named in the
  report and in the round's first reply whenever they differ.

## [0.2.0] - 2026-08-25

**No fence changed, so no re-approval is owed** — but **the granted rule list grew by one**, and
anyone who copy-pasted it needs to copy it again. Step 6 no longer runs `gh pr edit`, so
`Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` joins the list in all four places it is written. All
three fences still match the hashes in `tests/fence-hashes.txt`; `tests/fence-guards.test.sh` proves
it on every run.

Everything here came out of operating the loop on the previous release's own pull request, which ran
ten rounds and stopped on `--max-rounds` rather than on convergence. Three of these are defects that
review could not have found, because they are failures of the procedure as run rather than as read.

Fixed:

- **Step 6 told users to run a command that does not work.** Measured twice on `gh 2.4.0`, the
  version this procedure calls its verified floor: `gh pr edit <n> --body-file` exits 1 with
  `GraphQL: Projects (classic) is being deprecated … (repository.pullRequest.projectCards)` and
  leaves the body unchanged. The subcommand asks for that field to populate the pull request's
  current metadata and GitHub has retired it. The body now goes through
  `gh api -X PATCH "repos/{owner}/{repo}/pulls/<n>"`, which is not a new idea — it is why the merge
  already uses REST `PUT` and why CI status comes from `gh pr view --json`. The floor note used to
  say `gh pr create/edit --body-file` "all exist at 2.4.0"; **existing at the floor and working at
  the floor are different claims**, and it now separates them. `gh pr create` is left alone and
  **measured working** at the same floor (`iwmaeda/revloop#9`, 2026-08, exit 0) — it has no existing
  pull request to query, so it never reaches the retired field. That measurement was taken by this
  changelog's own pull request being opened, which is the cheapest experiment that was available.
- **The procedure prescribed an artifact that broke its own verify step.** `.revloop/field-notes.md`
  is git-ignored, but neither `.markdownlint-cli2.jsonc` nor `.prettierignore` excluded it, and the
  documented "one line per event" format runs past MD013 on the first line. Writing the field note
  the procedure asks for turned `npm run check:all` red. Both ignore lists now name **that file**,
  not the directory: excluding all of `.revloop/` would have let any other Markdown left there skip
  the checks, which is more than the collision needed.
- **`reviewers/codex.md` was stale in the file whose whole purpose is separating measured from
  assumed.** Its latency said 3–4 minutes; ten consecutive rounds on one pull request ran 3:04 to
  8:01, median 4:14, timed from each trigger's `createdAt` to its review's `submittedAt`. Both
  samples are kept and labelled, because the new one widens the range rather than replacing the
  centre. Its `## Not measured` still listed an end-to-end review with the marker attached, which
  those same ten rounds measure; that entry has moved into `## Measured` with its provenance. Both
  READMEs carried a copy of the latency figure and both are updated.

Added:

- **`tests/permissions.test.sh` now covers `gh api` as well as `git`.** A rule matches a
  command-string prefix and the flag precedes the path, so each verb needs its own rule — and the
  `-X PATCH` above arrived with none. The check is the same shape as the git half: extract from
  fenced blocks and compare, in both directions. `GRANTED` is read from the fenced `json` block alone rather than
  the page, because the prose names `Bash(gh api *)` in order to discourage it and a grep over the
  document would read that discouragement as a grant. A case pins that scoping. Verified by
  deleting the `-X PATCH` rule and watching the suite go red.

  **The extractor rejects rather than falls back, and it took three rounds to get there because the
  first two answers were the wrong shape.** Both matched a _method group_ and made it optional, so
  any line the group failed to recognise quietly became the bare form — which is granted. Each round
  then widened the alphabet and the next spelling walked straight through: `-XPOST`, then
  `--method PATCH` and a lowercase verb, then `-X  DELETE` with two spaces, `gh  api`, a tab, and
  `-X 'DELETE'`. **The alphabet was never the class. An optional group with a granted default is
  fail-open by construction**, and a permission check may fail closed and never open.

  So it now finds every line invoking `gh api` in any spelling, classifies each against the canonical
  forms alone, and treats anything unclassified as a failure — with the line count asserted equal to
  the number classified, so nothing can be dropped on the way to green. **The verb is matched as
  written, never normalised**: a rule matches a literal prefix, so `Bash(gh api -X PATCH …)` does not
  cover `-X patch`, and normalising would hide exactly that mismatch. Widening the alphabet is no
  longer how a new spelling is handled; rewriting it canonically is. Verified end to end by rewriting
  step 6 as `--method PATCH` and watching the suite go red.

  **The denominator counts invocations, not lines**, which a later round required twice over.
  Classifying one call per line with `head -1` let a second call on the same line go unseen —
  `gh api "repos/x" && gh api -X DELETE …` classified only the granted sibling — and a call split
  across a continuation (`gh \` then `api -X DELETE …`) matched no single-line pattern at all, so it
  was absent from the count rather than counted and rejected. Both fail now: the first as an
  ungranted verb, the second as a non-canonical invocation, each verified by putting it into the
  procedure and watching the suite go red.

  **It compares the whole prefix, scoped path included.** Matching only the verb let
  `gh api -X PATCH "users/example"` reduce to `-X PATCH`, which is granted — while
  `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` would not authorize that call at all. A rule is a
  whole prefix, and comparing half of one answers a question nobody asked.

  **And the direction is no longer one-way, because the reason it was is gone.** `git add` and
  `git commit` were prescribed in step 4's paragraph and `git fetch` in step 9's table, so no block
  held them and three hardcoded assertions named them by hand — a stand-in for a check rather than
  one. The answer was to move the commands rather than widen the grep: they are in fenced blocks now,
  which both steps wanted anyway, since step 4 told you to stage explicitly and never showed the
  command and step 9 buried its recovery in a table cell. With the sets equal, **a granted rule no
  block uses fails too** — a permission nobody needs is a sign the list and the procedure have
  drifted. Verified in both new directions: an off-scope path, and an unused grant.

  **That second direction went to the git half and not the gh half**, which left an unused
  `gh api -X DELETE` grant passing for a round — the same defect surviving because the fix reached one
  of the two places that needed it. Both halves check both directions now, and `docs/permissions.md`
  no longer calls the check one-way.

- **`tests/procedure-refs.test.sh` stopped declining three citation forms, because the reason for
  declining them was removable.** `makefile:12`, `R:12` and `foo+bar:12` were recorded as permanently
  out of reach: a lowercase bare word before a line number is indistinguishable from prose the file
  really contained — `floor: 2.4.0`, `measured: 0 resolved`, and two `(last:NN)` GraphQL slices. Two
  of those were prose and were rewritten to say the same thing without the shape; the other two are
  pagination arguments and are neutralised by name, `first`, `after` and `before` alongside `last`,
  since a fence edit could reach for any of them. With nothing left to collide with, the capital is
  unnecessary and two patterns collapse into one case-insensitive rule. The token must be letter-led
  and must not follow one, or `2026-08-24T07:59:33Z` reads `T07:59` as a file and a line — found by a
  negative case rather than by reasoning, and pinned. Three declined forms became three caught ones.

  **The first attempt skipped each fence wholesale and justified it by the hash guard, which does not
  hold.** `tests/fence-hashes.txt` is re-pinned whenever a fence legitimately changes, and the
  re-approval a fence edit costs is a human agreeing to new permission bytes, not an audit for
  citations. Skipping also discarded the lines _between_ a marker and its opener, which no hash covers
  at all: a citation injected there was invisible while the suite reported all green. The whole file
  is scanned now, and the neutralisation is anchored to the two fields that actually collide
  (`comments`, `reviews`). A bare `(last:40)` pattern would also have swallowed a prohibited prose
  citation written as `(first:12)` — the same over-broad exclusion, one level smaller, in the fix for
  it. An argument on any other field collides loudly instead.

- **`tests/provenance.test.sh` holds the reviewer cards to the grammar `reviewers/README.md`
  states.** **It checks the provenance half only, and says so**: deciding whether a sentence is an
  observation or an inference is the judgement that rule was rewritten to remove, so a test claiming
  to guard the whole grammar would be the overclaim the grammar exists to prevent. Provenance is the
  half that failed anyway — two `gemini.md` bullets stated observations with no citation and survived
  several reviews. The one exemption is the documented mechanical one, for a bullet opening
  `**Derived from …**`. Verified by injecting an uncited bullet and watching it fail.

  **The two provenance forms are not interchangeable fragments, and the first draft treated them as
  three.** The section gives a public form — cite the pull request — and a private one: anonymise as
  `repo X` **with the month**. Written as a flat alternation the check accepted `repo C` with no
  month, and a bare `2026-08` with no source at all, either of which is a bullet nobody can go and
  check. It is now a PR reference, or a repo tag and a month together.

  **Each form is matched whole rather than as a substring**, which a later round caught: a bare
  `#[0-9]+` is satisfied by `C#8` in ordinary prose, `repo [A-Z]` by `repo GitHub` — a name, not an
  anonymisation — and an unbounded month by `2026-99`. A PR reference now needs its `owner/name`, a
  repo tag needs a lone capital, and a month has to be one that exists. **The exemption was loose the
  same way**: `- **Derived from** …` closed the marker without naming anything and skipped the check
  entirely, so the bold span must now contain a source.

  **And a card the extractor could not parse used to pass in silence.** A `*` list marker or a
  `##  Measured` heading with two spaces yielded zero bullets, while the aggregate count stayed
  non-empty from the other cards — an entirely uncited new card would have gone green. Both markers
  are recognised now, and **each card asserts its own parseable section** rather than contributing to
  a total.

  **Each form is bounded at both ends**, which a later round required: without a left boundary
  `12026-08` supplies a month and `owner/repo#0suffix` a reference, and without a right one `#8x`
  does; a pull request is numbered from 1, so `#0` is not one. The derived exemption closed on
  whitespace alone (`- **Derived from   **`) and now needs something legible in the span.

  **One request is declined and recorded as declined**, in the test rather than only in a reply:
  checking provenance per sentence instead of per bullet. The rule is written per sentence, so the
  gap is real — a bullet holding two observations passes on one citation. Deciding which sentences
  are observations, as against derivations or connective prose, is the judgement the rule was
  rewritten to remove; a grep that guessed would either demand a citation on every sentence, which no
  card could satisfy, or guess at sentence roles and be wrong in the direction that matters. The unit
  is the bullet, and that is a limit rather than an oversight.

  Every existing bullet on all four cards satisfies each tightening, checked before it was applied,
  so the guard starts green.

Changed:

- **Step 3's untracked-file whitespace loop reports a status instead of only printing**, and
  **classifies that status rather than masking it with a bit test.** `--no-index` exits 1 for a clean
  new file and 3 for a dirty one, so `2` is the whitespace bit — but `git diff` also exits 128 when it
  cannot read a path, and `128 & 2` is zero, so a bit test calls an unreadable file clean. Measured on
  git 2.34.1: a single `chmod 000` file that `git ls-files -o` does list gives
  `error: open("only.txt"): Permission denied`, exit 128, and a `& 2` loop reports **status 0**. Only
  0 and 1 are clean now, 3 is the whitespace finding, and every other status is an operational failure
  that outranks it, because a check that could not read its input has not passed. `set -o pipefail`
  covers the producer side for the same reason. The braces are load-bearing as `-z` is — the `while`
  is the last stage of a pipeline and therefore a subshell, so a bare assignment would be discarded
  and the status would be the last file's. The output is still the report; the status says only
  whether to look, and at what.

The entries here come from two sources, and the difference matters when reading them.

**The originating measurement** is seven pull requests driven through this loop with codex in a single
repository (private, so `reviewers/codex.md` anonymises it as repo C, 2026-08). Their round counts
were 2, 3, 3, 8, 10, 21, and 30, and **a round returns roughly one finding** — 23 finding-bearing
rounds on one PR at a mean of 1.22, never more than 2. **The rounds a pull request needs is therefore
roughly the number of defects present when the trigger fires**, which is arithmetic on the measurement
rather than a separate observation, and is labelled derived wherever it appears. It is what the
entries below about steps 3, 7 and 10 were **originally written from**; several of them were then
corrected by the second source, and say so in place.

**The rest comes from this pull request reviewing itself.** Its review rounds on the branch that adds
these entries produced further defects in them, each fixed and recorded in place rather than as a
separate entry, and several were measured in throwaway git repositories built for the question — the
`--no-index` exit codes, the filename-handling table, and the `--follow` rename case. Those say
"measured" and name what was run. **This preamble said "everything here comes from one measurement"
until round 6, when the reviewer pointed out it had stopped being true several rounds earlier.**

Added:

- **Step 10 now names three sweeps instead of one, and asks which one matches the class.** The old
  advice was "sweep the whole codebase for its shape", and for the class that dominates the
  measurement it is wrong: **about 20 of one PR's 30 rounds were successive members of a single
  predicate's input space** — a particle, a comma-joined form, leading whitespace, whitespace around
  a joiner, an em dash, a compound particle — one form per round. **A codebase sweep returns zero for
  that class**, because the missing forms are inputs the predicate could receive and not text that
  exists in the tree, so the author concludes the class is closed and the reviewer names the next
  member next round. The three are a **corpus sweep** (instances exist; grep, fix, report count and
  method — the old bullet, now named), an **input-space sweep** (enumerate the form space along
  stated axes, close it as a set in one round, and pin every member with a synthetic case, because
  the corpus cannot witness this class and a test is the only evidence there is), and a **definition
  sweep** (find every other implementation of the predicate just changed and make them agree, or
  delete one — measured: a splitter and its consumer carried two grammars, and one of two gates read
  a different rule). Two guards ship with them: the input-space sweep is **bounded by what the
  predicate's real inputs can contain**, so the rule cannot generate speculative work of its own, and
  **a location already fixed in an earlier round of this PR means the class was named too narrowly**
  — widen and sweep again rather than patch in the new member (measured: four commit subjects on one
  PR name a prior round, and one line was fixed four separate times).
- **Step 3 now reads the pending change before step 4.** The procedure already asserted that the only
  way to spend fewer rounds is to have fewer defects at fire time, and then fired anyway. Step 3
  already argued the same thing about CI — a red run wastes a round, so pay for it before pushing —
  and the measurement makes the reviewer the more expensive of the two. **It is deliberately not a
  generic self-review**: on the measured PR the author was an LLM that had already missed those
  findings once, so a second general reading by the same reader is not supported by anything. It is
  step 10's sweeps, one step earlier. The pass must be reported, because a self-review nobody can see
  is indistinguishable from one that never happened.

  Two things about **what** it reads, both found by the reviewer on this branch's first round.
  **It reads the working tree, not a committed snapshot.** Step 4 has not committed yet and step 11
  re-enters step 3 with the fix unstaged, so the `git diff <base>...HEAD` and `git show HEAD` the
  step first shipped with read a history that does not contain the edits: round 1 could show an empty
  diff, and from round 2 `git show HEAD` shows the previous round's commit — the code the reviewer
  already found a defect in. `git status --porcelain` joins them because **no diff against a commit or
  the index lists an untracked file** — the `--no-index` form added later is the exception, and only
  because it is handed each path explicitly — and `git diff --check` gained an explicit `HEAD`: bare, it
  reads only what is unstaged. **And the change picks what to sweep for without bounding where to
  look.** The definition-sweep bullet asked for rules "this diff states in two places", which the
  diff can answer on its own and which therefore never fires for the drift the sweep exists to catch
  — a second implementation in a file the change never touched. It now searches the repository.

  Round 2 returned the same shape at two of the same locations, so the class was renamed from "reads
  a committed snapshot" to **a check whose actual input is a proper subset of what its stated rule
  covers**, and swept again. `git diff --check HEAD` reaches tracked content only, so a brand-new
  file — where a whitespace error is likeliest — passed it silently; each untracked path now goes
  through the same check against `/dev/null`, chosen over `git add -N .` because intent-to-add writes
  index entries for files step 4 has not decided to stage. `git status --porcelain` collapses a
  wholly-untracked directory into one `?? dir/` line, which is not something you can "read in full" —
  it now carries `-uall` at all three of its sites, and **step 4's is the one that matters**: staging
  a `?? dir/` line stages everything inside it, the blast radius `git add -A` is banned for. The
  re-sweep also reached step 1, where nothing read the repository's history even though steps 4 and 6
  both say commit style and the two languages are "detected" from it; two `git log` calls now do,
  because a row that says `detected` with no detector behind it is worse than an honest `builtin`.

  Round 3 found four more, all of them the mechanics rather than the intent, and three measured on
  throwaway repositories holding three awkward names — one beginning with two blanks, one called
  `-dashfile.txt`, and one with a newline in its name. The first two were run together; the newline
  case separately, which is why it is reported as what `git ls-files` printed rather than as what the
  loop then did. **The untracked loop skipped exactly
  the awkward names it existed to reach**: `read -r` without `IFS=` strips leading blanks
  (`Could not access 'leading-space.txt'`), `git ls-files` without `-z` renders an embedded newline as
  the quoted `"new\nline.txt"`, and a name beginning with `-` reaches `git diff` as options
  (`unknown switch 'd'`) — both files' whitespace errors went unreported while the loop printed
  complaints about their names. It is now `-z` with `IFS= read -r -d ''` and a `--` separator, and the
  procedure states that the **exit status of `--no-index` is not the signal**: every new file differs
  from `/dev/null`, so a clean one exits `1` and a dirty one `3`, and `$? -ne 0` would mark the
  preflight red whenever any untracked file exists. **Step 10's "was this already fixed in an earlier
  round" query gained `--follow`** — measured: a file fixed in round 1 and renamed in round 2 shows
  only the rename, so the question that exists to detect a too-narrow class answered a confident No.
  And step 1's trailer detection read three bodies, which is a sample of shape and not evidence of a
  convention; trailers are now grepped out of twenty.

  Round 4 closed the probe properly. All three `git log` calls read **the same twenty commits**, so
  the three agree with each other — round 3 had bumped the trailer read to twenty while keeping a
  three-body read and labelling it "read in full rather than sampled", which was a label contradicting
  its own command. **Twenty is still a window and not the history**, which is why the row says
  `detected` rather than proven; round 5 corrected the first version of this entry for claiming the
  sample away entirely. The unfiltered body read is the authority and the trailer grep is a
  convenience view of the same twenty, so **a token that grep fails to match still appears in the line
  above it**; the pattern had in fact been too narrow, dropping trailer tokens containing digits. Its
  comment says "lines shaped like a trailer" rather than "trailers", because an ordinary `Note:` line
  mid-body has the same shape.

- **Step 7's focus asks for every sibling in one comment.** The focus already named the class; it did
  not say what to ask for. That this raises findings per round is **derived, not measured** — what is
  measured is only that codex accepts the suffix — and the paragraph says so.
- **Step 7 forbids the literal `revloop:trigger` in the focus text.** The wait fence reads the marker
  as the text after the first occurrence of that literal, and the focus precedes the marker, so a
  focus containing it wins the split. **Measured** against the fence's own jq program: the marker
  string becomes `markers in the diff--`, carrying no `bot=`, `head=`, `reviewer=`, or `round=`.
  **Derived from that, not separately measured**: step 9 aborts on `marker_head=none` (fail-closed,
  one wait spent), and an empty `bot=` leaves the fence's bot filter matching every login, so any
  other bot on the pull request would have satisfied the wait had the round continued. The schema
  already rejects a configured `trigger` containing the literal; the focus is composed in the
  procedure, so the rule now exists there too. `tests/fixtures/jq/focus-carrying-marker` pins **the
  jq output only** — it runs the extracted jq program against one recorded payload that contains no
  bot verdict, so neither the shell that reads the row nor step 9's table is exercised by it. Round 5
  corrected both this entry and the fixture's own assertion labels, which named the step-9 abort as
  though the fixture reached it. The existing clean-comment fixture is the control that proves the
  assertions discriminate.
- **`reviewers/codex.md` carries a second findings-per-round sample** and four new measurements:
  findings concentrate (28 in 3 files, 30 in 5) and the next one repeats the previous file 39–52% of
  the time across four PRs; the severity mix moves per PR (15/15 P2 on one PR, 15/15 P1 on another,
  25 P1 + 3 P2 on a third, P3 zero throughout — from which "do not triage by badge" is derived, and
  marked so on the card); the per-PR round counts; and the input-form-per-round
  shape. **The second sample is not independent of the existing 37-round one** — same repository,
  same account — and is written as corroborating the centre rather than the range, because presenting
  two samples from one source as two sources is the "looks measured" failure `CONTRIBUTING.md` warns
  about.
- **`reviewers/README.md` states the rule the cards are written to**: a `## Measured` bullet opens
  with an observation and its provenance, and everything after that — inference, recommendation,
  remedy, design consequence — sits behind a `Derived:` marker. A bullet with no observation belongs
  under `## Not measured`, which all four cards now have; the single exception is mechanical, for a
  bullet that opens by naming what it derives from.

  **The rule took three rounds to hold, and the reason is the rule's first draft.** It exempted
  "design rationale signposted as such", and that exemption required deciding sentence by sentence
  whether something was rationale or a claim. The judgement went wrong in both directions in
  consecutive rounds: first leaving inferences unmarked, then defending the exemption for four
  sentences a later audit rejected. The exemption is gone, the rule is now mechanical, and it costs
  some `Derived:` markers on sentences whose status was never in doubt — the cheaper side of the
  trade. It also took three rounds because the first two applications only touched `codex.md` while
  the rule sat in a file governing every card, which is the same "stated in one place, not held to
  elsewhere" shape the rule exists to catch. All four cards are now written to it, `gemini.md` and
  `claude.md` and `copilot.md` gained the `## Not measured` sections the rule implies, and the
  focus-suffix bullet gained the provenance it never had.

  A further round found the rule itself still wrong at its boundary: "opens with an observation, and
  everything after that is `Derived:`" demands a marker on a bullet's **second** observation, and had
  put one in front of an exact quoted string on `codex.md`. It now reads sentence by sentence — every
  sentence is an observation with provenance or sits behind the marker — which is the same rule
  without the false ordering. Three cards were corrected under it, and `gemini.md`'s error
  observation gained the date it lacked.

- **`tests/permissions.test.sh` holds `docs/permissions.md`'s granular git list to the procedure.**
  That list is a copy of a fact living in `commands/review-loop.md`, and it had already drifted three
  times — `switch`, `fetch` and `ls-files` were each run by a step the list did not grant. An earlier
  round **declined to test it**, arguing that a grep for `git <word>` cannot tell a command from prose
  since the file says "makes git set the upstream" and names `git show HEAD` twice to forbid it.
  **That reason was wrong.** Runnable commands live in fenced `bash` blocks and prose does not, so
  extracting from the blocks alone yields neither `set` nor `show` and needs no exclusion list. The
  check compares both directions: every subcommand in a block must be granted, and every granted rule
  must be used by a block. It was one-way at first, because `git add` and `git commit` were prescribed
  in step 4's paragraph and `git fetch` in step 9's table, so no block held them and three assertions
  named them by hand. A later round moved the commands into blocks instead — which both steps wanted
  anyway — and the stand-ins went with them. Both extractions must be non-empty, because a broken one
  finds nothing missing and passes on no data.
- **`CONTRIBUTING.md` no longer says `tests/procedure-refs.test.sh` "enforces" the line-number rule.**
  The rule is absolute; the guard catches the forms it enumerates and once declined three it could not tell
  from prose. Tripwire, not proof — and the difference is now in the sentence that sends readers to it.
- **`tests/procedure-refs.test.sh`** fails if the procedure cites one of its own line numbers, and
  `CONTRIBUTING.md` states the rule beside it. **It took five review rounds to make the guard's claim
  match its behaviour, and the reason is worth more than the guard**: each round closed one axis of the
  notation and left the next one spelled by hand, which is the failure the procedure's own
  input-space sweep is written to prevent. The axes, in the order they were found — number of digits
  (`[0-9]{2,}` passed "line 9"), singular versus plural (`line` alone passed "lines 334 and 371",
  which is just the two citations the guard was written to catch, joined), letter case (`[Ll]` passed
  "LINE 132"), the separator (a literal space passed "line: 132", "line:132", "line number 132"), the
  notation (matching the word alone passed "#L132" and "review-loop.md:132"), and the file cited
  (matching only `.md:` passed "procedure-refs.test.sh:40", though the rule forbids citing any file by
  line). Round 4 added two more: the filename form (a 1–4 letter extension passed
  `package.jsonc:12`, and requiring an extension at all passed `Dockerfile:40` and `Makefile:12`) and
  case sensitivity — folding the filename half into the `grep -i` half **re-broke it**, because `-i`
  does not spare a bracket expression, and `floor: 2.4.0` matched again. Case is noise in `LINE 132`
  and signal in `Dockerfile:40`, so the guard is now two patterns, one grep each. The extensionless
  branch is the one axis with no syntax to derive from — an extensionless filename is lexically just a
  word — so it is derived from the corpus instead: every `word: digits` phrase the procedure really
  contains (`floor: 2.4.0`, `measured: 0 resolved`, and two `(last:40)` forms inside untouchable
  fences) is lowercase or has no dot or slash, and all four are pinned as must-not-match cases. Round
  5 added leading-dot paths (`.env:12`) and the hyphen form (`line-number 12`), for ten axes and 41
  assertions.

  **Round 5 also stopped the guard claiming to cover "any citation notation", which is the claim that
  kept being wrong.** No regex over English prose carries it, and the comment had asserted it for four
  rounds while the pattern did not. It now says it covers the enumerated forms, and it names the three
  it deliberately did not — `makefile:12`, `R:12` and `foo+bar:12` — on the ground that a lowercase
  extensionless filename is lexically identical to prose this file must not break. **A later round
  removed that ground and all three are caught**; see the entry above. **The guard is a tripwire, not
  a decision procedure, and the difference is written down.** The assertion was widened alongside
  the pattern — keying on a literal `line` would have let an `#L132` hit through unseen, the same
  defect one level up. The guard stays scoped to `commands/review-loop.md` so that this file can go on
  quoting the citations it records removing.

Changed:

- **`commands/review-loop.md` no longer cites its own line numbers.** `## Notes` named "step 10, line
  334" and "step 11, line 371". Both were correct when written and both were one insertion away from
  being silently wrong; the step numbers were already there, so the line numbers carried nothing.
- **Two copies of a measured number now point at the card that owns it** rather than restating it:
  the flags table said real PRs have needed 20+ rounds (the measured maximum is 30), and step 10's
  lead declared codex at 1–4 and gemini at 30–50 a second time.
- **Both README phase tables** describe the Prepare and Fix phases as they now behave — Prepare sweeps
  the pending change before pushing, and Fix runs the sweep that matches the class rather than "the
  codebase sweep", which is now one of three and the one that does not apply to the dominant class.
- **`docs/permissions.md`'s granular rule list gained `git switch`, `git fetch`, and `git ls-files`**,
  the first two of which step 2 and step 9's recovery row have always run while the list never granted
  them. The list is a copy of a
  fact that lives in the procedure, so it drifts; the section now says outright that no test holds the
  two together and why one would not help — a grep for `git <word>` cannot tell a command from prose,
  and the procedure names `git show HEAD` twice precisely to forbid it.

## [0.1.0] - 2026-08-23

First release. Everything below happened before it, so **no re-approval is owed to anyone**: there
was no earlier version for a fence to have changed from. The fence-related entries are recorded
anyway, because "record every fence edit" is the rule, and a rule that is skipped when it is
convenient is not one.

### Added

- **Both READMEs now describe the loop's flow, and say how long the wait is.** `## How it works` /
  `## 動作の流れ` sits ahead of the install section in each, giving the run as seven phases and then
  stating the part nobody was told: **after the trigger comment, several minutes pass in which nothing
  happens**, because the reviewer is a GitHub app and the loop can only poll it. A first-time user had
  no way to tell that from a hung command — the arrow chain that used to open the English README read
  as if the steps ran back to back. codex's **3–4 minutes to a verdict is measured and dated**
  ([`reviewers/codex.md`](reviewers/codex.md), 2026-08); gemini and claude are given no latency at all
  rather than codex's. The section summarises the procedure at phase level and does not restate it;
  `commands/review-loop.md` remains the only place the steps are written out, and the only place the
  shipped budgets — the 30-second poll, the 480-second chunk, the cumulative `--timeout 30m`, the
  `--max-rounds` circuit breaker, and the CI wait's ~18-minute worst case — are stated. Neither README
  repeats those numbers; `docs/install.md` links to both files from `## Prerequisites` instead.
- **`docs/permissions.md` now covers Codex.** It described only Claude Code's allowlist and never
  said so, which left Codex users to infer their setup from a note in the skill. There is now a
  `## Codex: approval policy and sandbox` section covering `approval_policy`, `sandbox_mode`,
  `sandbox_workspace_write.network_access`, and per-project `trust_level`, and the file opens by
  saying which sections belong to which host. The section states the failure it exists to prevent:
  **a `workspace-write` sandbox commonly runs with `network_access = false`, and every `gh` call in
  the procedure needs the network.** Its key names and value sets were read out of an installed
  `codex-cli 0.147.0` rather than from vendor documentation, and the claim that the configuration
  carries the loop end to end is **labelled derived**, because it has not been driven against a live
  pull request.
- **Both READMEs now state the reviewer prerequisite up front**, above the command block: the Codex or
  Claude GitHub integration must already be installed on the repository and answering comments. Why
  that is a separate thing to install — a `@codex review` comment goes to
  `chatgpt-codex-connector[bot]`, not to the session you are running — is spelled out once, in the new
  `## Prerequisites` section of `docs/install.md`, which the READMEs link rather than restate. This
  was previously one sentence at the tail of `## Requirements`, where the person who most needed it
  had already stopped reading; that sentence moved rather than being duplicated.

- Initial extraction of the review loop into a standalone, reviewer-agnostic tool.
- `.revloop.json` configuration with auto-detection for base branch, verify commands, branch
  prefixes, and commit conventions; JSON Schema and four worked examples.
- Reviewer presets for `codex`, `gemini`, `claude`, and `copilot`, each as a dated card recording
  what was measured and where.
- Fence tests that extract the shell fences from the procedure and replay recorded GitHub responses
  through a `gh` stub, plus structural guards and a fence-hash gate.
- Codex router under `.agents/skills/revloop/`, resolving the same procedure file.
- A **Limitations** section in the README. Forks, detached HEAD, squash and rebase merges, `copilot`,
  and reviewers that post a preamble are all outside what this drives; each is a stop with a named
  reason rather than something a user discovers.
- `tests/version.test.sh`, pinning the version string across the five manifests and the changelog.
- Issue templates (bug report, reviewer measurement), a pull request template, and a code of conduct.

### Changed

- **The install section is now structured identically in both READMEs**, as
  `### Claude Code` / `### Codex`. The English side had a flat `## Install` with Codex reduced to a
  single link, and the Japanese side had an **empty** `## Codex` heading at the wrong level, which
  broke `npm run check:docs`. Both now carry the same two subsections in the same order, and the
  permission setup lives inside the host it belongs to — the allowlist JSON under `### Claude Code`,
  the approval-policy-and-sandbox pointer under `### Codex` — rather than in a third section that had
  to name both.
- **The Japanese README moved to the repository root, and the English one was cut down to match it.**
  It was `docs/ja/README.ja.md`, a partial overview that covered install and design intent; it is
  `README.ja.md`, a standalone README, and `README.md` now mirrors it section for section — same
  headings in the same order, same tables, same examples — so the two can be compared line by line and
  drift is visible rather than quiet. **The parity was reached by shortening the English side, not by
  expanding the Japanese one.** **The old path is gone, not redirected**, so a link to it 404s; the
  only reference in this repository was the README's own documentation table, and it was updated.
  The procedure itself is unchanged and still English-only, and no fence changed, so **no
  re-approval is owed**.

- **Toolchain versions are stated once, in `mise.toml`.** CI installs them with
  `jdx/mise-action`, replacing `actions/setup-node` and the `node-version: 24` that was duplicated
  across both jobs. `jq` and `shellcheck` are now pinned there too — jq at 1.7.1 (the final patch of
  the 1.7.x series `ubuntu-latest` carried when this was written) and shellcheck at 0.9.0 (matching
  the image exactly) — so a runner image update can no longer change a lint verdict on its own.
  Dependabot does not track mise pins, so raising them stays a manual, deliberate step.

  This closes a real gap rather than only removing duplication. `tests/lint-shell.sh` and
  `tests/jq-program.test.sh` skip themselves when their binary is absent, so a contributor without
  `jq` and `shellcheck` saw `npm run check:all` pass having run neither — while CI ran both. After
  `mise install` the two agree.

- **The configuration surface now matches what the procedure consumes.** About twenty-five schema
  keys had no consumer in `commands/review-loop.md`, which is the single source of truth for
  behaviour — so configuring them did nothing while looking like it did something. Removed:
  `project.roundSource`, `project.commit.embedRoundNumber`, `project.pr.titleTemplate`,
  `project.pr.bodyUpdateMethod`, `project.pr.mergeMethod`, `project.pr.requireCleanCiForMerge`,
  `reviewers.*.triggerKind`, `reviewers.*.announce`, `reviewers.*.focusSuffix`,
  `reviewers.*.verdictOn`, and `reviewers.*.ignoreCommentPatterns`. What each of them was reaching
  for is now stated as a fixed property in `docs/configuration.md` under **What is deliberately not
  configurable**, with the reason it is fixed.

  The round number, which `roundSource` used to select a strategy for, is now defined in step 7:
  the count of `revloop:trigger` markers already on the PR, plus one.

- **Actions are pinned to commit shas** rather than to `@v5`/`@v4`, for the same reason `mise.toml`
  pins jq and shellcheck exactly. `actions/checkout` also moves to v7.

- **`npm audit` runs in CI as its own job**, and `.revloop.json`'s `verifyNotes` now names it as the
  gap `check:all` does not cover. `audit` needs the network and `check:all` has to stay runnable
  offline, so this repository demonstrates its own `verifyNotes` feature rather than claiming to have
  no gap.

- **`ajv-cli` replaced by `ajv` called directly** from `tests/validate-schema.mjs`. `ajv-cli` has not
  moved since 2021 and its dependency tree carried a high-severity prototype-pollution advisory
  through `fast-json-patch` (GHSA-8gh8-hqwg-xf34), which `npm audit fix --force` proposed to resolve
  by downgrading four major versions. The wrapper was the problem; the wrapper is now forty lines in
  this repository, and it distinguishes "the schema rejected it" from "the validator never ran" —
  the reject cases would otherwise pass for the wrong reason after a typo in a path.

### Removed

- **`README.md` no longer carries `## Why it is built the way it is`, `## Tests`, or the
  `### The wait is the slowest part of the loop` subsection.** Each was English-only, and keeping them
  is what made the two READMEs impossible to diff. Nothing was lost, only relocated to the file that
  already owned it: the design rationale is in [`docs/design-notes.md`](docs/design-notes.md), the
  check commands and the warning that `check:all` **goes green having skipped shellcheck and jq**
  without `mise install` are in [`CONTRIBUTING.md`](CONTRIBUTING.md), and the wait budgets are in
  `commands/review-loop.md`. All three are still reachable from the README's documentation table or
  from `docs/install.md`. **`--timeout` is the one flag no longer named anywhere in either README** —
  it remains in the procedure's flag table and in the command's `argument-hint`.

### Fixed

- **All three fences**: a detached HEAD made `git branch --show-current` print nothing, and
  `gh pr list --head ""` reads an empty value as **no filter** rather than as no match — so it
  answered with the first open PR in the repository. Measured here: the unguarded command returned an
  unrelated Dependabot PR (`iwmaeda/revloop#4`). The wait fence would have read a stranger's
  comments, step 12 would have reported a stranger's CI as green, and only the merge fence's `sha=`
  pin stood between that and a merge of someone else's branch — one interlock deep is not enough for
  a gate. Each fence now resolves the branch first and exits `no-branch` when it is empty; step 9's
  table and step 12's output list carry the new reason.

  This changes fence bytes in all three fences.

- **wait-verdict fence**: revloop's own trigger comment matched both trigger classes at once, so a
  single comment emitted two `TRIG` rows with identical timestamps. `tail -1` then took the
  compatibility row, discarding the marker — and with it the `bot=` filter that excludes other bots
  and the `head=` value the runaway check depends on. The compatibility class now excludes bodies
  that already carry a marker. Found by running the fence's jq program against a raw GraphQL payload;
  the row-level fixtures could not see it, because they were written by hand with one row per
  comment.

  This changes fence bytes.

- **A repository could grant itself an unattended merge.** `defaults.merge` and `defaults.auto` were
  configuration keys, and `.revloop.json` comes from whatever repository you are working in,
  including one you just cloned. A hostile or careless config could therefore turn on merging and
  delete both human confirmation points, while `SECURITY.md` claimed safety rules could not be
  switched off from config. Both keys are removed: `--merge` and `--auto` are settable by flag only,
  because the flag is the approval. `tests/schema.test.sh` now asserts both are rejected.

- **The command granted itself the wide permission rule its own docs warn against.** The frontmatter
  carried `Bash(gh api *)` — which reaches every repository the token can touch, and which
  `README.md`, `docs/permissions.md` and `SECURITY.md` all name as the rule to avoid — in a syntax
  (`Bash(git *)`) that did not match the documented one either. It is now the same rules the docs
  tell you to grant, and `tests/fence-guards.test.sh` fails if the frontmatter ever grants something
  `docs/permissions.md` does not list.

  The first pass narrowed to a single `Bash(gh api repos/{owner}/{repo}/:*)` rule and missed that a
  rule matches a command-string **prefix**: the reply-to-finding call and the merge fence both put
  `-X POST`/`-X PUT` before the path, so neither matched. Under `--merge --auto` that reintroduced
  exactly the stall the narrowing was meant to avoid. Two more rules, scoped the same way —
  `Bash(gh api -X POST repos/{owner}/{repo}/:*)` and `Bash(gh api -X PUT repos/{owner}/{repo}/:*)` —
  cover them. Found in review before release.

  The same gap existed one flag over: reading findings (step 10) and verifying a reply (step 11)
  both call `gh api --paginate "repos/{owner}/{repo}/..."`, and `--paginate` sits before the path
  the same way `-X POST`/`-X PUT` do, so none of the existing rules matched either. One more rule,
  `Bash(gh api --paginate repos/{owner}/{repo}/:*)`, covers them. Also found in review before
  release.

- **A hand-typed trigger produced a misleading abort.** A compatibility-class trigger carries no
  marker, so `marker_head=none`, which step 9's check (c) reported as "the runaway invariant is
  violated, or someone else pushed" — sending the reader hunting for a push that never happened. It
  has its own row now, and `docs/design-notes.md` states that anchoring a baseline is the whole of
  what the compatibility class does.

- **`copilot` is marked `unsupported`, not `unverified`.** It has no comment trigger, and the
  reviewer-request path it needs was never written, so `--reviewer copilot` could not run. Step 1
  now aborts with `reason=no-comment-trigger`. The card is kept for what it measured.

- **The claim that adding a reviewer never needs a fence change was false** for a reviewer that
  posts a preamble before its verdict — the drop list is inside the fence, where config cannot reach.
  `README.md` and `docs/adding-a-reviewer.md` now say so, and name the `interim-loop` abort as the
  signal that a fence edit is owed.

- **`docs/install.md` gave `git` no version floor.** It is 2.22 (`git branch --show-current`),
  labelled as derived from the feature rather than measured, next to the `gh` floor that was.

[0.10.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.10.0
[0.9.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.9.0
[0.8.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.8.0
[0.7.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.7.0
[0.6.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.6.0
[0.5.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.5.0
[0.4.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.4.0
[0.3.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.3.0
[0.2.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.2.0
[0.1.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.1.0
