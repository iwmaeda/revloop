# The rigor level — how strictly a run must finish

Step 1 of [`remote-loop.md`](remote-loop.md) and step 1 of [`local-loop.md`](local-loop.md) resolve
the level against this page. A later step that asks whether the run may stop asks it here.

## The levels

`--rigor <level>` is the only argument that decides when the loop may stop. If `<level>` is not one
of the four words below, abort with `reason=unknown-rigor-level` and print the four.

| Level                    | Blocking — never acceptable | Acceptable band  |
| ------------------------ | --------------------------- | ---------------- |
| `minimal`                | `critical`                  | `high` and below |
| `standard` **(default)** | `critical`, `high`          | `medium`, `low`  |
| `thorough`               | every finding               | none             |
| `exhaustive`             | every finding               | none             |

- The rungs are revloop's canonical ladder, `critical > high > medium > low`, most severe first, and
  never a reviewer's vocabulary.
- The floor is the top of the acceptable band: a finding at or below it is acceptable, and one above
  it blocks.
- The default is `standard`. A finding left unfixed in the band is recorded, explained and listed.
- At a level with a band, `--merge --auto` aborts with `reason=unreviewed-accept-merge` (step 1 of
  `remote-loop.md`); type `--rigor thorough` to merge unattended. `--merge` without `--auto` stops
  at step 12 of that file, which confirms the accepted list.
- `exhaustive` differs from `thorough` only in the sweeps owed and the round cap. It adds no
  confirming round over an unchanged tree.

## Configuration

`--rigor` has no configuration key. **Never take a level from `.revloop.json` or any other
configuration file**: the flag is the approval, so it comes from the person typing it.

## A reviewer's own rungs

- A reviewer that declares `severityLevels` carries every rung onto the canonical ladder through its
  `severityMap`. Compare each mapped value with the floor.
- `schema/reviewer.schema.json` requires the map whenever `severityLevels` is present. Never derive
  one from rung position.
- The floor need not be a rung the map reaches: the shipped `P1`/`P2`/`P3` maps skip `medium`, so
  `standard` blocks `P1` and `P2` and accepts `P3`.
- Check the map only when the reviewer has `severityLevels` and the level has a band. Abort with
  `reason=bad-severity-map` when it is not total over that ladder, names a rung the ladder does not
  hold, is not order-preserving, or leaves no distinction at all. Name the rung that is unmapped,
  foreign or inverted; in the last case print the whole map.
- Grading ([`severity-grading.md`](severity-grading.md)) needs no flag. It runs if and only if the
  level has a band and the definition declares no `severityLevels`: never at `thorough` or
  `exhaustive`, and never over a reviewer's own rungs.
- Mark every rung a grader assigns `graded` in the replies, the report and the commit.

## The round cap

The precedence is `--max-rounds`, then `defaults.maxRounds` or `defaults.localMaxRounds`, then the
table below. When the table answered, step 1's resolved table prints the `source` as `rigor`.

| Level                    | `remote-loop.md` | `local-loop.md` |
| ------------------------ | ---------------- | --------------- |
| `minimal`                | 3                | 2               |
| `standard` **(default)** | 5                | 3               |
| `thorough`               | 10               | 5               |
| `exhaustive`             | 15               | 8               |

- The cap is not a target and hitting it is never success. It aborts a loop that has not converged.
- Check it where a round opens, not where a verdict is read: step 5 or 6 of `local-loop.md` and
  step 7 of `remote-loop.md`.

## Sweeps

The sweep taxonomy is step 10 of `remote-loop.md`, by name: name the class, then the corpus,
input-space, definition and already-fixed sweeps. This page decides only which of them a round
owes.

| Level        | Owed for every class fixed                                               |
| ------------ | ------------------------------------------------------------------------ |
| `minimal`    | Name the class; the already-fixed check                                  |
| `standard`   | The above; the corpus sweep whenever the class has instances in the tree |
| `thorough`   | The above; every sweep that applies, and do not defer                    |
| `exhaustive` | The above; the definition and input-space obligations under the table    |

- `exhaustive`: run the definition sweep whenever a predicate changed, and close an input-space
  class as a set, with a synthetic case per member in the same commit.

## The sufficiency test

Run it at every edge into the report step, and nowhere else: step 8's clean row and step 9's
fall-through in `local-loop.md`, which both reach step 10, and step 11's fall-through to step 12 in
`remote-loop.md`.

Answer in writing whether the change is sufficiently reviewed for this level. Every condition below
must hold; the floor alone is never the answer.

1. **Floor.** No finding of the latest review carries a rung above the floor. A finding the grader
   declined to rank is `ungraded` and is above every floor.
2. **Sweeps.** Every class this run fixed owes the sweeps `## Sweeps` lists for this level, each run
   and recorded. Run now any that is owed and was not run. If it changes the tree, a finding goes in
   `will fix` and the round goes back; if it changes nothing, the debt is discharged and the run may
   stop. Answer this condition by doing the work, never by refusing to stop.
3. **Buckets.** Every finding of the latest review is in a bucket, not only those above the floor.

- The answer may read: the latest review's rungs and where each came from (`reviewer`, `graded`,
  `ungraded`); the per-round record of buckets and rungs that step 9 of `local-loop.md` and step 10
  of `remote-loop.md` keep; which sweeps ran for which class; the round number and the cap.
- **The answer may not read** how hard the remaining fixes look, how much this run has spent, or how
  many rounds are left.
- The test may keep a run going and can never end one early: conditions 2 and 3 only add work.
- The loop still never assigns a rung.

## The record

Every converged run writes a `Sufficiency:` block in the report and, unless `local-loop.md`'s
`--no-publish`, in the pull-request body, as it does the `Accepted:` block:

```text
Sufficiency: standard — sufficient at round 4.
  floor:   nothing above medium remains; 3 accepted at low, 1 at medium
  sweeps:  round 2 corpus (3 instances), already-fixed checked each round
  buckets: all 11 findings bucketed
```

- No commit carries it. Never write an empty commit to carry it.
- A round the test does not pass records why, in the same shape, and the run continues.

## A rising ceiling

- If the highest rung remaining is higher than it was at the end of the previous round while still
  at or below the floor, the findings at that new ceiling leave the `accepted` bucket and are read
  again. Check it against the bucket record, which carries each finding's rung and round.
- This re-opens and never blocks: a round sent back with nothing in `will fix` has nothing to
  change.
- Record the ceiling a finding was re-opened at, and re-open once per rung of rise, not once per
  oscillation of a reviewer or grader.
- A ceiling that falls re-opens nothing.

## Not measured

No run has exercised this page.

- The round caps: all eight are `builtin` guesses.
- The sweep obligations: a judgement about cost, not a measurement.
- The rising-ceiling re-open: it has never fired.
- That the default converges sooner than `thorough`: argued, not observed.
- A re-open on a rising count at an unchanged ceiling: rejected, not overlooked.
