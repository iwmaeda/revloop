# code-review

The review command built into Claude Code, driven as a subprocess.

| Field            | Value                                                   |
| ---------------- | ------------------------------------------------------- |
| `kind`           | `local-command`                                         |
| `invoke`         | `subprocess` — the host forbids model invocation        |
| `command`        | `claude --model {reviewModel} -p "/code-review medium"` |
| `severityLevels` | **none** — the reporting surface carries no severity    |
| `requiresPr`     | `false`                                                 |
| verdict on       | the command's stdout                                    |
| `status`         | `unverified`                                            |
| `lastChecked`    | 2026-09                                                 |

```json
{
  "kind": "local-command",
  "invoke": "subprocess",
  "command": "claude --model {reviewModel} -p \"/code-review medium\"",
  "status": "unverified"
}
```

**`{reviewModel}` is expanded by the local loop before the command runs** — to `--review-model` if it
was typed, otherwise to the builtin `sonnet`. **Every measurement below predates that pin**, and
`## Not measured` says what that costs.

**Five rounds have been observed; convergence has not.** The behavioural bullets below come from
driving the command as this preset specifies, five times, on one change, fixing every finding between
rounds. **No round was clean**, and the fifth reached the local loop's `--max-rounds` built-in still
returning findings — so this is a **cap-reached run, not a converged one**, which is exactly the
outcome `.revloop/field-notes.md` records three times for the remote reviewer. `status` stays
`unverified`: for a local reviewer that word turns on convergence, not on the command answering.

## Measured

### From five runs

- **Five consecutive rounds on one change returned 9, 7, 6, 8 and 10 findings, in 5m27s, 6m50s,
  6m37s, 8m39s and 6m29s** (claude-code 2.1.233, 2026-09). The change was this repository's 0.5.0
  diff — 23 modified files and 4 new ones — reviewed as an uncommitted working tree, because the
  branch carried no commits and the range diff against the base was empty. All five runs exited 0.
  **Every finding in all five rounds was acted on as a real defect**, which is an observation about
  this sample and not a rate.
- **The run reached `--max-rounds 5` without converging**, with the fifth round returning more
  findings than any before it (claude-code 2.1.233, 2026-09). **Derived, and the single most useful
  thing on this card:** the local loop's cap is not a formality on a change of this size. It is the
  same outcome `reviewers/codex.md` and the field notes record for the remote reviewer three times,
  reached in a fifth of the wall clock and by a different reviewer — so **"the reviewer runs out of
  things to say" is not what ends either loop**, and the acceptance floor and the cap are the two
  things that do.
- **The wall clock lands inside the remote reviewer's measured range.** 5m27s to 8m39s here against
  2:46–10:07 there (claude-code 2.1.233, 2026-09; `codex.md`). **Derived, and it contradicts what
  this project assumed while building the local loop:** "a local round returns at once" was written
  into the procedure, the design notes, the schema and both READMEs before anything was measured,
  and it is false. **The difference between the two loops is what a round spends, not how long it takes** —
  and the token cost, which is the one that differs, is the figure nothing here measures.
- **Not one finding recurred across the five rounds** — 40 findings, 40 distinct, with each round's
  fixed before the next ran (claude-code 2.1.233, 2026-09). **Derived, and deliberately nothing
  more:** four transitions on one change say the repeat suppression in step 7 of the local procedure
  went unexercised, not that it is unnecessary. The rounds where it would fire are the ones where a
  fix is partial, and none of these was.
- **The count did not fall: 9, 7, 6, 8, 10.** Each round's fixes added text and the next round
  reviewed the larger diff (claude-code 2.1.233, 2026-09). **Every round after the first found
  defects the previous round's fixes had introduced** — a stale claim left by a changed rule, a rule
  interaction created by a fix, a truncation created by a budget, and a bypass created by a grant.
  **Derived, and the reason this is recorded rather than smoothed:** five points are barely a trend,
  but the direction of the last two is the informative part — on a change of this size, **fixing a
  round's findings is itself a reliable source of the next round's**, and a loop that stops only when
  the reviewer stops may not stop.
- **The output shape was neither shape this card read out of the binary.** All five runs returned
  prose —
  a paragraph naming the scope reviewed, a paragraph on what could and could not be verified — then a
  line reading `Findings (N):`, then one bullet per finding shaped as a backticked path and line, an
  em dash, and the claim (claude-code 2.1.233, 2026-09). No fenced JSON array, and not the bare
  one-line-per-finding form either. **Derived, and the reason this bullet is here rather than in a
  footnote:** a parser written from the declarations below would have matched none of the five,
  returned zero findings, and been read as a clean review. The local procedure's `unparsed-review-output`
  abort is what stands between that and a run reporting success, and this is the first evidence that
  it is load-bearing rather than defensive.
- **Round 1 returned 9 findings at `medium`, where the cap read out of the binary for that level is
  8** (claude-code 2.1.233, 2026-09). **Derived:** the cap is not a single number per effort level —
  the model running the review selects among prompt variants, and at least one of them carries its
  own, higher limit. Treat the caps below as the level's floor, not its ceiling.
- **No run emitted a severity anywhere**, on any finding, in any form
  (claude-code 2.1.233, 2026-09). **Derived:** this confirms from behaviour what the reporting
  surface already said by its shape, and it is the reason this card ships no `severityLevels`.
- **All five runs reported that their sandbox prevented them from executing the test suite**, and
  said so in the output rather than failing (claude-code 2.1.233, 2026-09). **Derived:** a subprocess review
  does not inherit the caller's permissions, so a repository whose findings depend on running
  something will get those findings reasoned about statically. That is a property to record on the
  card rather than a fault: the reviewer said which parts it had verified and which it had not.

### From the installed command

- **The structured reporting surface carries no severity field.** Its entries are a file, a line, a
  summary, a short summary, a failure scenario, an optional `category` slug, and an optional
  `verdict` of `CONFIRMED` or `PLAUSIBLE`; severity is expressed only as the order of the list, which
  is documented as most-severe first (claude-code 2.1.233, 2026-09). **Derived:** this card therefore
  carries no `severityLevels`, and `--accept-at` aborts with `reason=no-severity-ladder` against it.
  **That is the ordinary case for this reviewer and not an edge one**, which is worth saying plainly
  because the acceptance floor is the feature people will reach for first. `verdict` is a
  **confidence** axis rather than a severity one and is deliberately not offered as a ladder: reading
  `PLAUSIBLE` as "less severe" would accept a confirmed-cheap finding and block an uncertain-serious
  one, which is the opposite of what the flag is for.
- **The number of findings a single run may return is capped, and the cap moves with the effort
  level** — 4 at the lowest, 8 at `medium`, 10 at `high`, and 15 at `xhigh` and `max`
  (claude-code 2.1.233, 2026-09). **The observed round exceeded the `medium` figure**, so read these
  as floors; the bullet above records that. **Derived:** the reviewer brings its own brake, which is
  why this preset can be driven at all without a ladder. **Derived, and the reason `medium` is the shipped
  default:** the higher levels are documented as broadening coverage and admitting uncertain
  findings, so raising the effort raises both the cap and the share of findings a round will argue
  with — a loop run at the top level manufactures its own next round.
- **The output shape is not one shape.** With a plain text output format the findings are declared to
  come back as a fenced JSON array of objects; on at least one model family at `medium` and `high`
  effort the report is instead one line per finding, a path and line followed by a summary, emitted
  after a tool call (claude-code 2.1.233, 2026-09). **Both observed runs returned a third shape that
  is neither**, which is recorded above. **Derived, and the reason step 8 of
  [`../commands/review-loop-local.md`](../commands/review-loop-local.md) gives an unreadable result
  its own abort row:** a parser written against whichever shape its author saw returns **zero
  findings** against the others, and zero findings is what a clean review looks like.
- **The command declines model invocation** — it is marked as startable by a person and not by the
  model (claude-code 2.1.233, 2026-09). **Derived:** `invoke` must be `subprocess`. There is no
  in-session path, so this is not a preference between two working options.
- **It resolves its own review target.** Its first phase takes a range diff against the upstream, or
  against the base branch when there is no upstream, and additionally reads the working tree when the
  range is empty or the tree is dirty; an argument naming a pull request, a branch, or a path
  replaces that (claude-code 2.1.233, 2026-09). **Derived:** on the unpushed topic branch this loop
  works on, the default resolves to the whole branch against the base, which is the scope the loop
  wants and the reason `command` carries no target argument.
- **Derived from the same rule, and it is the reason the local loop publishes after convergence
  rather than before each round: a push changes what this reviewer reviews, to nothing.**
  `git push -u origin HEAD` gives the branch an upstream, so the first clause applies instead of the
  second; `HEAD` then equals the upstream, so the range is empty; and the loop's commit step has just
  left the tree clean, so the working-tree fallback finds nothing either. **A round run after a push
  returns zero findings, and zero findings is what a clean review looks like** — the failure the
  `unparsed-review-output` abort exists to prevent, arriving instead through a feature that looks
  unrelated to reviewing. This is a property of the reviewer and is recorded here rather than in the
  procedure, which reads it off `requiresPr`.
- **It takes `--model`, and the shipped preset now uses it** (claude-code 2.1.233, 2026-09).
  **Derived:** this is the only lever the local loop has on what a round costs, since the command's
  own effort level moves the number of findings rather than the price of producing them. It is also
  the only thing that makes this reviewer a different model from the one driving the loop, which
  `../docs/design-notes.md` records as the one condition under which a local review is a check rather
  than a second opinion from the same source.
- **The effort levels are `low`, `medium`, `high`, `xhigh` and `max`, and `ultra` is not one of
  them** — it is a separate subcommand that routes to a cloud review and falls back to a local `max`
  run when that is unavailable (claude-code 2.1.233, 2026-09). **Derived:** putting `ultra` in
  `command` would silently buy the most expensive local level, which is the opposite of what this
  loop wants from its effort setting.

## Not measured

- **Anything about the preset as it now ships.** All five rounds below ran
  `claude -p "/code-review medium"` with **no `--model` at all**, inheriting whatever the CLI
  defaulted to; the shipped `command` now pins `{reviewModel}`, which resolves to `sonnet` unless
  `--review-model` says otherwise. **So the finding counts, the wall clock, the output shape and the
  absence of repeats below describe a configuration this project no longer ships.** They are kept
  because they are the only measurements that exist and because most of what they establish is about
  the command rather than the model — but nothing here says how a lighter reviewer changes them, and
  **the direction of the error is not knowable from this sample either**: fewer findings from a
  lighter model may mean fewer defects present or fewer defects found, and this card cannot tell you
  which. Re-running the five rounds under the pin is the single most useful measurement available.
- **Convergence.** It was not reached, and this sample cannot say whether it is reachable. What is
  known is that five rounds did not reach it and that the count rose at the end. **What would settle
  it is a run under `--accept-at`** — the floor is the mechanism for ending a loop the reviewer will
  not end — and no such run has been made. That is the question most worth answering next, and the
  one `status` turns on.
- **The token cost of a round** — the local loop's scarce resource. Nothing here measures it. The
  elapsed times above are wall clock, and the interesting thing about them is that they are **not**
  the difference between the two loops: they land inside the remote reviewer's measured range.
- **Whether the repeat suppression ever fires.** Four transitions produced no repeats. The case it
  exists for is a partial fix, and this sample has none.
- **Whether the observed output shape is stable.** Five runs, same machine, same version, same
  change.
  A different effort level, a different model, or a different repository may return one of the two
  declared shapes instead — which is exactly why the procedure aborts on a shape it does not
  recognise rather than parsing loosely.
- **Whether the ten-finding batch size ever binds.** The five observed rounds returned 9, 7, 6, 8 and
  10 — **the last exactly at the batch size**, so no second batch has been taken and the next round
  would probably have needed one.
- **How a nested invocation behaves under this loop** — its cost, whether it re-authenticates, and
  what it does when the outer session is itself non-interactive. What is known is that its sandbox
  differed from the caller's, recorded above.
- **The token cost of a round at any model.** This is the figure the whole local loop is shaped
  around and the one nothing here measures, before or after the pin. Until it exists, "sonnet is
  cheaper" is an inference from pricing and not a measurement of this reviewer.
- **Whether a push really empties this reviewer's target.** The bullet above is derived from the
  command's own target-resolution rule, read out of the installed command; **nobody has pushed a
  branch and re-run it.** The procedure's publish placement rests on that derivation, so a run that
  falsifies it is worth a pull request.
