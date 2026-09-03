# ecc-review-pr

The `review-pr` command from the ECC plugin, driven as a subprocess.

| Field               | Value                                                      |
| ------------------- | ---------------------------------------------------------- |
| `kind`              | `local-command`                                            |
| `invoke`            | `subprocess`                                               |
| `command`           | `claude --model {reviewModel} -p "/ecc:review-pr"`         |
| `severityLevels`    | **none** — the four-rung ladder read here was not emitted  |
| `severityMap`       | **none** — there is no measured ladder to map from         |
| `requiresPr`        | **`true`** — it resolves a pull request first              |
| `rateLimitPatterns` | `["You've hit your session limit"]` — its host's, measured |
| verdict on          | the command's stdout                                       |
| `status`            | `unverified`                                               |
| `lastChecked`       | 2026-09                                                    |

```json
{
  "kind": "local-command",
  "invoke": "subprocess",
  "command": "claude --model {reviewModel} -p \"/ecc:review-pr\"",
  "requiresPr": true,
  "rateLimitPatterns": ["You've hit your session limit"],
  "status": "unverified"
}
```

**Six runs exist now, and what they establish is mostly that this card was wrong.** The command runs,
answers in about five minutes and returns usable findings — and it emits neither the ladder nor the
report shape read out of it below. `status` stays `unverified`: for a local reviewer that word turns
on convergence, and no round of this reviewer has yet come back clean.

**It also does not run at all in a repository that has not been configured**, which nothing here
predicted and which is the first thing to check. See `### From the first six runs`.

**A seventh run found a second way for it not to run, and this one is not a configuration at all:
its host's session limit.** The command exits 0 and returns the notice in place of a review, which is
the same shape as the unconfigured case and the same shape as a clean round. The card now carries a
`rateLimitPatterns` so the loop names the quota rather than the parse. See
`### From a seventh run, in another repository`.

**It shipped as `invoke: skill` and no longer does, and the reason is that a skill has no model
boundary.** A skill runs in the loop's own session: on the loop's model, spending the loop's context.
Nothing inside a session can lower the model that session is running on, so `--review-model` against
a `skill` reviewer aborts with `reason=no-model-boundary` — and this was the one shipped preset that
tripped it. A subprocess is started with a command line, and a model is a token in one.

**The switch discards no measurement, because there was none.** Every bullet below is read out of the
installed command rather than observed from a run, and both invocations drive the same command, so
none of them changes. What the switch adds is unknown rather than measured, and `## Not measured`
lists it.

**`invoke: skill` remains supported** and is the only option for a review command whose host forbids
subprocess invocation. Configure it that way if you must, and read the `review model` row in the
step-1 table as `this session's model — no boundary exists`.

**`requiresPr` is true, and the local loop now satisfies it by itself on an ordinary run.** The
reviewer resolves the pull request inside its own invocation; the loop opens one for it.

| Local run      | What happens                                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------------------------------ |
| default        | The loop opens the pull request if the branch has none and pushes to it **before every round**. Nothing to confirm |
| `--no-publish` | Step 1 **asks you to confirm** one exists, and step 8 refuses to read a zero-finding result as a clean round       |

Under `--no-publish` the loop opens no pull request and makes no `gh` call, so it can neither check
nor guess: with no target and with a clean diff this reviewer returns the same nothing. **The ordinary
run is the supported way to use this preset** — it supplies the check the confirmation was standing in
for. Under the flag, run it on a branch whose pull request the remote loop opened, or that you opened
by hand.

**That check is narrower than "the reviewer had a target", and the difference is a hole this card
opened by measuring one thing and claiming another.** Publishing establishes that a pull request
exists; it establishes nothing about whether the reviewer could reach it. A checkout without
`README.md`'s permission block produces the second kind of no-target, and on an ordinary run
`unconfirmed-empty-review` cannot fire — the loop confirmed the pull request itself, that round — so a
zero-finding result would reach step 8's clean row and the run would converge over a review that never
happened.

**What stopped it is that the blocked command answers in prose, and that is an observation rather than
a guarantee.** Across five rounds the working ones opened by naming the pull request they had
reviewed — its number, its title and its changed files — and the blocked one said instead that it
could not confirm one existed. **So the shape this card records for the loop to match includes naming
the target**, which is the only signal that survives the process boundary: nothing outside the
subprocess can see whether `gh` answered. A result that does not name what it reviewed is
`unparsed-review-output` and never a clean round.

## Measured

### From the first six runs

**All six ran `claude --model sonnet -p "/ecc:review-pr"` against `iwmaeda/revloop#22`.** The first
reviewed nothing and the other five are consecutive rounds of one loop, each answering the previous
round's fixes. The only difference between the first and the second was the repository's permission
configuration. **The loop ended at `--max-rounds 5` without a clean round**, so it is a cap-reached
run and not a converged one, and `status` stays `unverified` on that.

- **Unconfigured, it does not review at all, and it does not fail either.** In a checkout with no
  `.claude/settings.local.json`, the command exited **0** after **52s** and returned prose: that `gh`
  and `WebFetch` were "blocked without permission grant", that it could not confirm whether a pull
  request existed, and a question asking which of two options to take (`iwmaeda/revloop#22`). Zero
  findings, no severity, no verdict. **Derived:** this is the `unparsed-review-output` row's case
  rather than the clean row's, and it is why that row sits above the clean row — an exit of 0 and a
  well-formed English paragraph are what a working reviewer and a blocked one have in common.
  **Derived:** the permission block in `README.md` is a precondition of this preset and not only of
  the pull-request loop, and a card that did not say so let an unconfigured install look like a
  reviewer that found nothing.
- **Configured, it works.** With that block installed, the same command exited 0 after **5m09s** and
  returned an aggregated report naming the pull request, its title and its single changed file, with
  **three findings** — two rated at its middle level and one at its lowest — plus a section of
  candidates it had considered and dismissed (`iwmaeda/revloop#22`). All three were acted on as real
  defects. **Derived:** five minutes is the same order as this repository's remote reviewer and as the
  `code-review` preset's five rounds, so six dispatched agents do not make this reviewer a different
  class of wait.
- **The emitted vocabulary is the command's confidence rule, not the agent ladder read out of it
  below.** The findings arrived under `## Important` and `## Advisory`, with a third heading for
  what needed no action, and each finding carried an inline confidence percentage
  (`iwmaeda/revloop#22`). **No bracketed severity tag, no `CRITICAL`/`HIGH`/`MEDIUM`/`LOW` summary
  table, and no `APPROVE`/`WARNING`/`BLOCK` verdict line appeared anywhere in the output.**
  **Derived, and it is why `severityLevels` and `severityMap` are gone from this card:** the ladder
  they carried was never emitted, so `--accept-at high` would have resolved a floor against rungs that
  do not appear and then found no finding it could rank. A ladder that is read rather than emitted is
  precisely what `reviewers/README.md` refuses, and this card shipped one.
- **The subprocess could not run the test suite**, and said so in its own output rather than failing
  (`iwmaeda/revloop#22`). Its verification was file reads and cross-checks between agents.
  **Derived:** this is the same limitation `code-review.md` records for all five of its rounds, so it
  is a property of a `-p` subprocess in this environment rather than of either reviewer.
- **Every working round opened by naming the pull request it had reviewed** — number, title and
  changed files — and the blocked round said instead that it could not confirm one existed
  (`iwmaeda/revloop#22`, five rounds). **Derived, and it is why this is in the recorded shape rather
  than a note:** it is the only evidence the loop can have that the reviewer reached its target, since
  nothing outside the subprocess can see whether `gh` answered, and on a publishing run
  `unconfirmed-empty-review` has already been satisfied by the loop's own pull-request read.
- **All three of the command's confidence words are emitted, as headings.** Rounds 1 and 2 returned
  `## Important` and `## Advisory`; round 3 returned `## Critical` above them; rounds 4 and 5 returned
  `## Important` alone, the first saying outright that there were no critical findings and the second
  naming two advisory items it was deliberately excluding (`iwmaeda/revloop#22`). **Derived:** they
  behave as section titles for a round's findings, and three headings observed across five rounds is
  still not a ladder — nothing here establishes that they are ordered rungs a floor could sit between,
  which is why `severityLevels` stays off this card.
- **Findings per round, and no repeat in any of them: 3, 10, 6, 7 and 7 — 33 findings, 33 distinct**
  (`iwmaeda/revloop#22`). Each round's findings were answered before the next ran, and the count did
  not fall. **Derived:** this matches what `code-review.md` records for its own five rounds — 40
  findings, 40 distinct — so across two reviewers and thirteen rounds the local loop's repeat suppression
  has never had a repeat to suppress, and `repeat-findings` remains an abort nothing has entered.
- **The wall clock rises with the diff: 5m09s, 9m17s, 9m17s, 12m05s and 11m29s**
  (`iwmaeda/revloop#22`). Round 1 read one file and the later rounds four. **Derived:** these are the
  slowest local rounds this repository has measured — above `code-review`'s 5m27s–8m39s, and at the
  top end above the remote reviewer's 2:46–10:07. Six dispatched agents are not free, and a round of
  this reviewer is not the cheap end of the local loop.

### From a seventh run, in another repository

**One round, in a different repository and on a different change, and it did not review anything.**
It is kept apart from the six above because it shares neither their repository nor their
configuration, and what it measures is the host rather than the command.

- **Out of quota, it answers in one line and exits 0.** `claude --model sonnet -p "/ecc:review-pr"`
  returned a single line on stdout — `You've hit your session limit · resets 8:50pm (Asia/Tokyo)`,
  60 bytes with its newline — and exited **0**. No findings, no heading, no confidence figure, and
  **it did not name the pull request it had reviewed**, which is the signal this card records as the
  only one that survives the process boundary. The round ran at the ordinary publishing placement, so
  the loop had opened a pull request for it that round and `unconfirmed-empty-review` was already
  narrowed out (`repo B, 2026-09`). **Derived:** this is neither of the two ways this card had
  recorded for a round to return nothing — the reviewer ran and found nothing, or the checkout lacked
  the permission block — and the second was ruled out on the spot, because that block was installed.
  **Derived:** it is the reviewer's own quota, so the card carries `rateLimitPatterns` and step 8 of
  [`../commands/local-loop.md`](../commands/local-loop.md) has a row that reads it.
- **The notice is punctuated in a way a pattern can get wrong.** Read from the captured output, the
  apostrophe in `You've` is **ASCII `'` (0x27)** and the separator before `resets` is **U+00B7**, not
  a hyphen and not an em dash (`repo B, 2026-09`). **Derived, and it is why the shipped pattern stops
  at `limit`:** a pattern typed with a typographic apostrophe matches nothing, and a pattern that
  matches nothing is indistinguishable from a card with no pattern at all — the failure is silent in
  the same way an unemitted ladder was.
- **It names a reset time, where the remote loop's rate-limit reply does not.**
  [`codex.md`](codex.md) records `You have reached your Codex usage limits for code reviews` with no
  time in it; this one carries a wall-clock reset (`repo B, 2026-09`). **Derived:** the local abort
  can print something actionable, which is why step 8's row asks for the output in full rather than
  for the fact of a match. **Derived:** the reset had already passed by the time the run classified
  the round, so the interval between the notice and the operator reading it is not negligible and a
  reported time can be stale in the useful direction.

### From the installed command

**Every bullet here is read out of the command as installed, and the subsection above is what happened
when it was run.** Where the two disagree, the run wins and the reading is kept with the correction
beside it.

- **The three words `critical`, `important` and `advisory` are a confidence rule, not an output
  format.** Each appears exactly once in the command, in a closing section that defines what counts
  as reportable at each level, and the command's only instruction about output is a prose line asking
  for findings grouped by severity. There is no heading template anywhere in it (ecc 2.2.0, 2026-09).
  **Derived, and the reason this card's `severityLevels` are not those three words:** a ladder taken
  from the confidence rule would name rungs the output does not carry, and `--accept-at important`
  would then match nothing and block everything.
- **One agent the command dispatches specifies a format of its own, and none of it reached the
  output.** That agent specifies a bracketed severity tag at the head of each finding, a file-and-line
  line beneath it, a closing summary table whose rows are `CRITICAL`, `HIGH`, `MEDIUM` and `LOW`, and
  a verdict line of `APPROVE`, `WARNING` or `BLOCK`; its stated criteria are approve on no `CRITICAL`
  or `HIGH`, warn on `HIGH` alone, and block on any `CRITICAL` (ecc 2.2.0, 2026-09). **This card took
  that ladder as the reviewer's and shipped it, and the run disproved it** — see
  `### From the first six runs`. **Derived, and it is the lesson rather than the detail:** an agent's
  specification is a claim about that agent's output and not about the aggregate that consumes it, and
  the bullet above already said only one of six specifies a format. Reading a ladder out of one
  contributor was the "looks measured" failure `reviewers/README.md` exists to prevent, committed on
  this card by the party that wrote the rule.
- **It requires a pull request.** Its first step resolves one through `gh` and, given no argument,
  looks for the pull request of the current branch (ecc 2.2.0, 2026-09). **Derived, and the reason
  `requiresPr` exists as a key at all:** with no pull request the command has no target, and a
  reviewer that returns nothing is indistinguishable from one that found nothing. Under `--no-publish`
  the loop cannot resolve that from outside — it opens no pull request and makes no `gh` call — so the
  key buys a confirmation before the first round and a standing refusal to read zero findings from
  this reviewer as clean, rather than an abort that would make the preset unreachable on a branch
  where it works. **On the ordinary run the same key buys something else entirely**: it is what tells
  the loop to publish _before_ each review rather than after convergence, so the target exists and
  tracks `HEAD`, and both the confirmation and the refusal fall away with nothing left to be uncertain
  about.
- **It dispatches six specialised agents and aggregates them by deduplicating overlapping findings
  and ranking by severity, described in prose with no key, no schema and no threshold**
  (ecc 2.2.0, 2026-09). **Derived:** the deduplication is inside one review, across agents, and is
  not the same mechanism as the local loop's across-round fingerprint — neither substitutes for the
  other.
- **It writes no file and posts nothing.** Its steps end at reporting, with no artifact path and no
  publishing step (ecc 2.2.0, 2026-09). **Derived, and the reason this preset rather than the
  plugin's other review command:** a reviewer that writes into the work tree or posts to GitHub would
  have to have those suppressed before a loop could drive it, and this one has nothing to suppress.

## Not measured

- **Whether it reaches `gh` in a repository configured some other way than this one.** Both open
  questions here are now answered for one configuration and only that one: the ECC command is loaded
  in a `-p` session, and the subprocess reaches `gh` when `.claude/settings.local.json` grants it and
  not otherwise. **What the unconfigured run shows is that failing this way is silent** — exit 0, no
  findings — so a host with a narrower sandbox, or a grant list shaped differently from `README.md`'s,
  would look the same. The `skill` form stays one line away for that case.
- **Whether the shape holds under any other model or effort.** Five consecutive rounds under the
  `sonnet` pin returned the same one — the command's confidence words as headings, findings numbered
  beneath them, an inline confidence percentage — so it is stable across five diffs and one
  configuration. **That is exactly as far as it goes**, and `code-review.md` records the same command
  returning three different shapes under two different models, which is the reason to expect this one
  to move as well. If it turns out not to hold, the honest move is `status: unsupported`, not a looser
  parse.
- **Whether this reviewer's headings are a ladder.** All three confidence words have now been emitted
  as headings, and they appeared in the same order every time one of them was used. **Ordering
  observed is not ordering asserted**: nothing in five rounds establishes that these are rungs a floor
  could sit between rather than section titles a model chose, and a card that read three headings as a
  three-rung ladder would be repeating the mistake this card was just corrected for one paragraph up.
  So it declares no `severityLevels`, `--accept-at` aborts against it with `no-severity-ladder`, and
  `--grade-severity` is the documented way past — the same position `code-review.md` holds, reached
  from the opposite direction: that card never had a ladder and this one had the wrong one.
- **Rounds to converge, and tokens per round.** Five rounds have run, **none of them came back clean**,
  and the count did not fall — so this card cannot say convergence is reachable, only that the loop
  reached its cap without it.
  Recurrence is measured and is zero; the token cost of a round is not measured here or anywhere else
  in this repository, and it is the resource the local loop is shaped around.
- **What the six agents it dispatches run on.** The command is invoked with `--model`, and whether
  that reaches agents the command spawns for itself is not something reading the command establishes.
  If it does not, the pin buys less than it appears to.
- **Whether the merge holds on a diff larger than one branch's worth.** Every round returned a single
  aggregated report rather than six sections, several times naming which agents had converged on one
  finding (`iwmaeda/revloop#22`, five rounds) — so the merge is observed on diffs of one, four and eleven
  files, and on nothing wider.
- **Whether the session-limit wording is stable.** One occurrence, one host version, one account
  state. The pattern this card ships is the fixed head of that one sentence, and nothing establishes
  that a different plan, a different limit — a weekly cap rather than a session one — or a later
  release words it the same way. **The fall-through is the behaviour that existed before the pattern
  did**: a wording this misses reaches `unparsed-review-output`, which still aborts and still refuses
  to read the round as clean, so what a stale pattern costs is the diagnosis and never the guard.
- **Whether a quota state can arrive _after_ a partial review.** Only the instead-of shape has been
  seen: the notice in place of a review, with nothing else in the output. A run that returned findings
  and then hit the limit would carry both, and step 8's first-match ordering answers it — the round
  aborts on the pattern and the findings are printed but not acted on, which is the ruling step 9 of
  [`../commands/remote-loop.md`](../commands/remote-loop.md) already made for the same collision on a
  review. **Nothing here has observed that shape**, so what is untested is whether the reviewer can
  produce it at all.
