# ecc-review-pr

The `review-pr` command from the ECC plugin, driven as a subprocess.

| Field            | Value                                              |
| ---------------- | -------------------------------------------------- |
| `kind`           | `local-command`                                    |
| `invoke`         | `subprocess`                                       |
| `command`        | `claude --model {reviewModel} -p "/ecc:review-pr"` |
| `severityLevels` | `["CRITICAL", "HIGH", "MEDIUM", "LOW"]`            |
| `severityMap`    | the identity, case-folded onto the canonical rungs |
| `requiresPr`     | **`true`** — it resolves a pull request first      |
| verdict on       | the command's stdout                               |
| `status`         | `unverified`                                       |
| `lastChecked`    | 2026-09                                            |

```json
{
  "kind": "local-command",
  "invoke": "subprocess",
  "command": "claude --model {reviewModel} -p \"/ecc:review-pr\"",
  "requiresPr": true,
  "severityLevels": ["CRITICAL", "HIGH", "MEDIUM", "LOW"],
  "severityMap": {
    "CRITICAL": "critical",
    "HIGH": "high",
    "MEDIUM": "medium",
    "LOW": "low"
  },
  "status": "unverified"
}
```

**This card records what the installed command declares, not what a run of it produced.** Nobody has
driven `local-loop` with this reviewer, in either invocation.

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

### From the installed command

**There is no second subsection, and its absence is the claim.** Nothing here was observed from a
run; every bullet is read out of the command as installed.

- **The three words `critical`, `important` and `advisory` are a confidence rule, not an output
  format.** Each appears exactly once in the command, in a closing section that defines what counts
  as reportable at each level, and the command's only instruction about output is a prose line asking
  for findings grouped by severity. There is no heading template anywhere in it (ecc 2.2.0, 2026-09).
  **Derived, and the reason this card's `severityLevels` are not those three words:** a ladder taken
  from the confidence rule would name rungs the output does not carry, and `--accept-at important`
  would then match nothing and block everything.
- **The vocabulary that actually reaches the output comes from an agent the command dispatches, and
  it is a different vocabulary.** That agent specifies a bracketed severity tag at the head of each
  finding, a file-and-line line beneath it, a closing summary table whose rows are `CRITICAL`,
  `HIGH`, `MEDIUM` and `LOW`, and a verdict line of `APPROVE`, `WARNING` or `BLOCK`; its stated
  criteria are approve on no `CRITICAL` or `HIGH`, warn on `HIGH` alone, and block on any `CRITICAL`
  (ecc 2.2.0, 2026-09). **Derived:** the four-rung ladder above is that agent's, which is the only
  one with a written specification. **Derived, and the reason this is `unverified` rather than
  `reported`:** the command aggregates six agents and only one of them specifies a format, so what
  the aggregate emits is not established by reading either.
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

- **Whether it runs as a subprocess at all.** The preset now spells the invocation
  `claude -p "/ecc:review-pr"`, and **nobody has run that.** Two things about it are open and the
  first is load-bearing: whether the subprocess reaches `gh`, which this reviewer needs to resolve its
  pull request — [`code-review.md`](code-review.md) measured a subprocess whose sandbox differed from
  the caller's and could not run the test suite, so a narrower sandbox here is a live possibility —
  and whether the ECC plugin's skills are loaded in a `-p` session at all. **If either fails, the
  reviewer returns nothing**, which is why the local loop's `unconfirmed-empty-review` row still
  matters under `--no-publish`, and why the `skill` form stays one line away.
- **What a run actually emits.** The command carries no output template, so the aggregate shape is
  whatever the model produces; the agent template above specifies one of six inputs to that, not the
  result. **Nothing here has been observed coming back.** If the shape turns out not to be stable,
  the honest move is `status: unsupported`, not a looser parse.
- **Whether the confidence rule's three words ever appear in output at all.**
- **Whether this card's `severityMap` is a real identity or only a spelling one.** It carries each
  rung to the canonical rung of the same name, which makes it the one shipped map with nothing to
  choose — the emitted ladder and the canonical ladder have the same four words in the same order.
  **That is a fact about the two vocabularies and not a measurement of this reviewer**, and it is
  worth separating from the stronger claim it resembles: that the agent's `HIGH` means what revloop's
  `high` means is exactly as unestablished here as `P1` to `critical` is on the other cards. The map
  is shipped anyway, because without one `--accept-at high` reaches `no-severity-map` against a
  reviewer whose own ladder already spells the rung, which would be the flag failing at its easiest
  case.
- Findings per round, recurrence across rounds, rounds to converge, and tokens per round.
- **What the six agents it dispatches run on.** The command is invoked with `--model`, and whether
  that reaches agents the command spawns for itself is not something reading the command establishes.
  If it does not, the pin buys less than it appears to.
- Whether the six agents' findings arrive already merged in practice, or arrive as six sections.
