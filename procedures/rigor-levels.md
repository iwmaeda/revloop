# The rigor level — how strictly a run must finish

**This file is specified once and cited by both procedures.** Step 1 of
[`remote-loop.md`](remote-loop.md) and step 1 of [`local-loop.md`](local-loop.md) resolve the level
against this page rather than restating it, and every later step that asks _may this run stop_ asks
it here.

**`--rigor <level>` is the only argument that decides when the loop may stop.** It takes one of four
words and nothing else parses:

| Level                    | Blocking — never acceptable | Acceptable band  |
| ------------------------ | --------------------------- | ---------------- |
| `minimal`                | `critical`                  | `high` and below |
| `standard` **(default)** | `critical`, `high`          | `medium`, `low`  |
| `thorough`               | every finding               | none             |
| `exhaustive`             | every finding               | none             |

**The rungs are revloop's own canonical ladder** — `critical > high > medium > low`, most severe
first — and never a reviewer's vocabulary. `## Against a reviewer's own rungs` says how it reaches
one that has its own.

**A level is never a rung name, and that is the whole of what four fixed words buy.** An argument
that named a rung had to be resolved against a vocabulary, so it meant one thing against a reviewer
with a `P1`/`P2`/`P3` ladder and missed entirely against one without — reading as broken rather than
as reviewer-specific, and needing a second resolution pass and two aborts to say which way it had
missed. A level that can only be one of four policy words cannot miss: it never names a rung, so
there is no vocabulary for it to be written in and nothing for it to fail to match.

**If `<level>` is not one of the four, abort with `reason=unknown-rigor-level`** and print the four.
That is the whole diagnosis, which is why it is one line where an argument naming a rung had to
print two ladders and still say which of them the value had been measured against.

## The default is `standard`, and it is not the behaviour that existed before this flag

**With the flag absent, `critical` and `high` block and `medium` and `low` may be left unfixed** —
recorded, explained, and listed, but not fixed. **That is a change of default and it is stated as one
rather than left to be discovered.** Every earlier release fixed or declined every finding unless an
acceptance argument was typed; the argument now has to be typed to get that back, and it is
`--rigor thorough`.

**Four things follow from the default having a band, and each of them lands on a run that typed
nothing:**

- **A grader runs every round** against a reviewer that emits no severity, at one subprocess and one
  permission prompt per round. Three of the five shipped reviewers are that reviewer, so this is the
  ordinary cost of the ordinary run rather than the cost of a flag.
- **`severityMap` is read on every run** against a reviewer that has a ladder, so
  `reason=bad-severity-map` is now reachable without anything being typed. It was previously gated
  behind an argument, which is why its own paragraph says a map nothing consults cannot move a floor
  — under this default, every map is consulted.
- **The round cap is `standard`'s**, which is lower than the number either loop carried as a builtin.
  The cap follows the level rather than the history on the argument that a level leaving `medium`
  acceptable converges sooner — **an argument and not a measurement**, which `## Not measured` says
  again. `--max-rounds` and the config keys both still beat it.
- **`--merge --auto` aborts on an ordinary run**, with `reason=unreviewed-accept-merge`. The gate
  rests on a person reading the accepted list before a merge, and the default now produces one. Type
  `--rigor thorough` to merge unattended, or drop `--auto` and confirm the list.

**The two strict levels are cheaper per round than the two relaxed ones**, which is the opposite of
what a word like `exhaustive` suggests and is worth saying once: what a relaxed level buys is fewer
rounds, and what it spends is a subprocess per round to find out which findings it may skip. **So the
default is the cheaper run only if it converges sooner**, and nothing has measured whether it does.

**`exhaustive` differs from `thorough` in what a round must do, not in what may be left unfixed.**
Neither leaves anything unfixed — there is no rung above "every finding" — so the difference is the
sweep obligations below and the round cap. **It is deliberately not a second confirming clean
round**: a round that reviews an unchanged tree is the one thing step 6 of
[`local-loop.md`](local-loop.md) refuses, and buying confirmation by making the loop violate its own
runaway invariant is not a stricter run, it is a broken one.

## It has no configuration key, and adding one would be a defect

`.revloop.json` comes from whatever repository you are working in, including one you just cloned. A
repository that could set this would **lower its own review bar** on that checkout while the run
still reported a clean convergence. The flag is the approval, so it has to come from the person
typing it.

**A key holding only `thorough` and `exhaustive` was considered and is worse, not safer.** Those two
grant nothing, so such a key could never lower a bar — and a key that can only hold the value it
already has is the shape [`../docs/configuration.md`](../docs/configuration.md) refuses as a promise
rather than a setting. The round cap it moves stays settable, under its own keys, for the reason it
always was: it bounds spend rather than safety.

## Against a reviewer's own rungs

**A reviewer that emits its own severity carries every rung onto the canonical ladder through its
`severityMap`**, and each mapped value is compared against the level's floor: at or below it the
finding is acceptable, above it the finding blocks. **The map is required whenever `severityLevels`
is present** — `schema/reviewer.schema.json` makes it a `dependentRequired` pair — so the loop never
derives one from rung position. Reading "rung 1 of 3" as `critical` is the loop authoring a ladder,
and a three-rung ladder does not carry which of four canonical rungs its middle means.

**The floor does not have to be a rung the map reaches.** Both shipped `P1`/`P2`/`P3` maps skip
`medium`, so `minimal` leaves `P1` blocking with `P2` and `P3` acceptable, and `standard` leaves
`P1` and `P2` blocking with `P3` acceptable. That is what a four-rung ladder receiving three rungs
means rather than a defect in either.

**If the reviewer has `severityLevels` and the level has an acceptable band, check the map and abort
with `reason=bad-severity-map`** when it is not total over that ladder, names a rung the ladder does
not hold, is not order-preserving, or leaves no distinction at all — naming the rung that is
unmapped, foreign or inverted, or printing the whole map in the last case. None of the four is
expressible in JSON Schema, which cannot compare values across keys whose names it does not know.
**Check it only when the level has a band**: a map nothing consults cannot move a floor, and checked
unconditionally this abort broke a reviewer for ordinary use over a key that run never read.

**A reviewer that emits no severity is graded, and grading needs no flag.** The rungs come from a
separate subprocess specified in full in [`severity-grading.md`](severity-grading.md). **It fires if
and only if the level has an acceptable band and the definition declares no `severityLevels`** — so
`thorough` and `exhaustive` never start one, and a reviewer that emits its own rungs is never
regraded. Every rung a grader assigns is marked `graded` in the replies, the report and the commit.

## The round cap

**The level supplies the round cap that nothing else did.** The precedence is `--max-rounds`, then
`defaults.maxRounds` or `defaults.localMaxRounds`, then this table — so the level replaces the
`builtin` row and a repository that configured a cap keeps it. Step 1's resolved table prints the
`source` as `rigor` when this table answered.

| Level                    | `remote-loop.md` | `local-loop.md` |
| ------------------------ | ---------------- | --------------- |
| `minimal`                | 3                | 2               |
| `standard` **(default)** | 5                | 3               |
| `thorough`               | 10               | 5               |
| `exhaustive`             | 15               | 8               |

**`thorough` carries the numbers that were the builtins, and it is no longer the default**, so a run
that types no level and configures no cap is capped **lower** than it was — 5 rather than 10 on the
pull-request loop, 3 rather than 5 locally. That is the level owning the cap rather than an
oversight: a run that may leave `medium` unfixed has less left to converge over. **A repository that
wants the old numbers writes them**, under `defaults.maxRounds` or `defaults.localMaxRounds`, which
both beat this table.

**The cap is not a target and hitting it is never success.** It aborts a loop that has **not**
converged, and it is checked where a round opens rather than where a verdict is read — step 5 or 6
of [`local-loop.md`](local-loop.md) and step 7 of [`remote-loop.md`](remote-loop.md) — because that
is the point at which nothing has been spent yet.

## The sweeps a level requires

Both procedures' sweep taxonomy is step 10 of [`remote-loop.md`](remote-loop.md), by name: name the
class, then the corpus, input-space, definition and already-fixed sweeps. **This page decides which
of them a round owes, and never what they are.**

| Level        | Owed for every class fixed                                                                                                                                 |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `minimal`    | Name the class; the already-fixed check                                                                                                                    |
| `standard`   | The above; the corpus sweep whenever the class has instances in the tree                                                                                   |
| `thorough`   | The above; **every sweep that applies**, and do not defer                                                                                                  |
| `exhaustive` | The above; the definition sweep whenever a predicate changed, and an input-space class closed as a set with a synthetic case per member in the same commit |

**The already-fixed check survives the cheapest level, and it is the one that does.** It is the only
sweep that _saves_ rounds rather than spending them: without it a location fixed in an earlier round
is fixed again, which is measured on `reviewers/codex.md` as one line fixed four separate times. A
level that exists to spend fewer rounds cannot drop the sweep that costs the fewest.

**`exhaustive` promotes two sweeps from "when it applies" to "always", and both were already the
expensive half of the taxonomy.** The input-space class is the one a corpus sweep returns zero for —
the missing forms are inputs a predicate could receive, not text in the tree — and about 20 of one
pull request's 30 rounds were successive members of a single predicate's input space, one form per
round. That is the measurement the level is for.

## The sufficiency test

**Run it at every edge into the report step, and nowhere else.** Both convergence paths of
[`local-loop.md`](local-loop.md) reach step 10 — step 8's clean row and step 9's fall-through — and
[`remote-loop.md`](remote-loop.md) reaches step 12 by step 11's. **A test placed on one of them is a
test the other convergence walks past**, which is the same defect as a step reached on one path and
not the other.

**Answer in writing whether the change is sufficiently reviewed for this level.** The floor is a
precondition and not the answer: no run may answer _sufficient_ while a finding sits above it.

1. **Floor.** No finding of the latest review carries a rung above the level's floor. A finding the
   grader declined to rank is `ungraded` and is above every floor.
2. **Sweeps.** Every class this run fixed owes the sweeps the table above lists for this level, and
   each was run and recorded. **If one is owed and was not run, run it now.** A sweep that changes
   the tree puts a finding in `will fix` and the round goes back; one that changes nothing discharges
   the debt and the run may stop. **This condition is answered by doing the work and never by
   refusing to stop**, which is what keeps it from deadlocking the one convergence path that reaches
   it with nothing left to fix.
3. **Buckets.** Every finding of the latest review is in a bucket — not merely every finding above
   the floor. The floor decides when the loop may stop and never what gets read.

**What the answer may read**: the latest review's rungs and where each came from (`reviewer`,
`graded`, `ungraded`); the per-round record of buckets and rungs that step 9 of
[`local-loop.md`](local-loop.md) and step 10 of [`remote-loop.md`](remote-loop.md) already keep;
which sweeps ran for which class; the round number and the cap.

**What it may not read**: how hard the remaining fixes look, how much this run has spent, or how
many rounds are left. **Those are the three levers that end a run because it is tired**, and each of
them is a fact about the loop rather than about the change.

## Why the loop may run this test on itself

**The sufficiency test may keep a run going and can never end one early.** Every stop it permits is
a stop the level's floor already permitted; conditions 2 and 3 can only add to what the round owes.
**The loop is the party obliged to fix the findings, so the only judgement it is trusted with is the
one that can give it more work** — and it is written so that giving itself more work is the only way
it can decline to stop, which is why it cannot leave a run with nowhere to go.

**That is what keeps [`severity-grading.md`](severity-grading.md)'s rule intact rather than bending
it.** The loop still never assigns a rung: rungs come from the reviewer or from a grader that is not
told the floor and does not fix what it grades. What this page adds is a **standard the loop did not
author, applied to rungs the loop did not author** — which is the judgement the decision table has
always made, now made against the run's own history instead of against a constant.

**Written the other way it is the flag's whole safety argument, inverted.** A test able to shorten a
run would let the party doing the work decide how much of it there is, and nothing outside the run
could tell that from a change that was genuinely finished.

## The record

**Every converged run writes a `Sufficiency:` block**, in the report and — unless
[`local-loop.md`](local-loop.md)'s `--no-publish` — in the pull-request body. It is obligated exactly
as the `Accepted:` block is, and for the same reason: a stop nobody can read is indistinguishable
from a stop nobody justified.

**No commit carries it, and that is the same gap the last round's acceptances have** rather than a
second one. A commit is written before the review that would justify it, so the round that converges
makes no further commit and there is nothing left to attach the answer to. **An empty commit written
only to carry the block was rejected for the reason that gap is stated rather than papered over**:
it invents a commit that says nothing was true.

```text
Sufficiency: standard — sufficient at round 4.
  floor:   nothing above medium remains; 3 accepted at low, 1 at medium
  sweeps:  round 2 corpus (3 instances), already-fixed checked each round
  buckets: all 11 findings bucketed
```

**A round the test does not pass records why**, in the same shape, and the run continues. A reader
outside the run must be able to tell why round N+1 happened, and "the loop decided to keep going" is
not that.

## A rising ceiling re-opens the acceptances under it

**This is where the run's history reaches the decision.** A level with an acceptable band converges
over findings that are real, unfixed and conceded, and a band is a range rather than a point: a run
can accept three `low` findings in round 2 and three `medium` ones in round 3 and stop, having
watched the change get worse under a floor that never moved.

**So: if the highest rung remaining is higher than it was at the end of the previous round while
still at or below the floor, the findings at that new ceiling leave the `accepted` bucket and are
read again.** The bucket record already carries each finding's rung and round, which is what makes
this checkable rather than remembered.

**It re-opens rather than blocks, and the difference is a deadlock.** A test that withheld
permission with nothing in `will fix` would send the round back with nothing to change, arrive at
the step that refuses to review an unchanged tree, and leave the loop between a step that will not
review and a step with no verdict to classify. A re-open gives the round something to fix, so the
tree moves and the next round is an ordinary one.

**It is bounded the same way the acceptance re-open beside it is.** The record shows the ceiling a
finding was re-opened at, so a reviewer or grader that oscillates buys one re-read per rung of rise
and not one per oscillation. **A ceiling that falls re-opens nothing** — those findings were
answered under a stricter reading already.

## Not measured

**No run has exercised this page.** Every number and every rule below is stated so that a later run
can contradict it:

- **All eight round caps are `builtin` guesses**, including the default's. `thorough`'s pair is the
  two numbers that were the builtins, which were themselves recorded as guesses; the other six are
  scaled from them and nothing measured stands behind any of them. **The default's pair is therefore
  a guess scaled from a guess**, and it is the one that decides what an untyped run costs.
- **The sweep obligations are a judgement about which sweeps cost what**, taken from the round
  counts on `reviewers/codex.md`, and not a measurement of what a level saves.
- **The rising-ceiling re-open has never fired**, because no run has resolved a floor at all — and
  the default now resolves one on every run, so this is the entry most likely to be entered next.
- **Nothing has measured that the default converges sooner than `thorough` does.** The claim that a
  relaxed level trades a subprocess per round for fewer rounds is the argument for the default, and
  it is an argument rather than an observation.
- **Re-opening on a rising _count_ at an unchanged ceiling was rejected**, not overlooked: it is a
  plausible second signal, it would fire on a reviewer that returns more of the same rung as the
  tree grows, and nothing measured asks for it.
