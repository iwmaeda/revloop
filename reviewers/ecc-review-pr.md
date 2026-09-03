# ecc-review-pr

The `review-pr` command from the ECC plugin, driven as a subprocess.

| Field            | Value                                                     |
| ---------------- | --------------------------------------------------------- |
| `kind`           | `local-command`                                           |
| `invoke`         | `subprocess`                                              |
| `command`        | `claude --model {reviewModel} -p "/ecc:review-pr"`        |
| `severityLevels` | **none** — the four-rung ladder read here was not emitted |
| `severityMap`    | **none** — there is no measured ladder to map from        |
| `requiresPr`     | **`true`** — it resolves a pull request first             |
| verdict on       | the command's stdout                                      |
| `status`         | `unverified`                                              |
| `lastChecked`    | 2026-09                                                   |

```json
{
  "kind": "local-command",
  "invoke": "subprocess",
  "command": "claude --model {reviewModel} -p \"/ecc:review-pr\"",
  "requiresPr": true,
  "status": "unverified"
}
```

**Two runs exist now, and what they establish is mostly that this card was wrong.** The command runs,
answers in about five minutes and returns usable findings — and it emits neither the ladder nor the
report shape read out of it below. `status` stays `unverified`: for a local reviewer that word turns
on convergence, and no round of this reviewer has yet come back clean.

**It also does not run at all in a repository that has not been configured**, which nothing here
predicted and which is the first thing to check. See `### From the first two runs`.

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

## Measured

### From the first two runs

**Both ran `claude --model sonnet -p "/ecc:review-pr"` against `iwmaeda/revloop#22`, a one-commit
branch touching one file.** The only difference between them was the repository's permission
configuration.

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
  `### From the first two runs`. **Derived, and it is the lesson rather than the detail:** an agent's
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
- **Whether the shape one run emitted is the shape it emits.** The command carries no output
  template, so the aggregate is whatever the model produces, and one run is one sample of that. What
  it produced is recorded above; whether a second run groups findings under the same headings, or
  carries the confidence percentage at all, is unknown — and `code-review.md` now records the same
  command returning two different shapes under two different models, which is the reason to expect
  this one to move too. If it turns out not to be stable, the honest move is `status: unsupported`,
  not a looser parse.
- **What this reviewer's severity vocabulary is.** One run emitted two headings, `Important` and
  `Advisory`, and a third for findings needing no action. **Two headings from one run are not a
  ladder**, the command's confidence rule names a third word above them that no finding reached, and
  nothing here establishes that these are ordered rungs rather than section titles. So this card
  declares no `severityLevels`, `--accept-at` aborts against it with `no-severity-ladder`, and
  `--grade-severity` is the documented way past — the same position `code-review.md` holds, reached
  from the opposite direction: that card never had a ladder and this one had the wrong one.
- **Whether the confidence rule's third word ever appears.** Two of the three showed up as headings
  in the one run there has been; `critical` did not, and a one-commit diff is not a sample that could
  have produced it.
- **Recurrence across rounds, rounds to converge, and tokens per round.** One round has been
  observed and it returned three findings; nothing follows from that about the second round, which is
  the round every one of these questions is about.
- **What the six agents it dispatches run on.** The command is invoked with `--model`, and whether
  that reaches agents the command spawns for itself is not something reading the command establishes.
  If it does not, the pin buys less than it appears to.
- **Whether the merge holds on a diff large enough to test it.** The one run returned a single
  aggregated report rather than six sections, with a line saying all six agents had completed and two
  findings attributed to independent agents converging (`iwmaeda/revloop#22`) — so the merge is
  observed once, on a diff where six agents had one file to disagree about.
