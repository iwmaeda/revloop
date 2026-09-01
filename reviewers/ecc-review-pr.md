# ecc-review-pr

The `review-pr` command from the ECC plugin, invoked as a skill.

| Field            | Value                                         |
| ---------------- | --------------------------------------------- |
| `kind`           | `local-command`                               |
| `invoke`         | `skill`                                       |
| `command`        | `ecc:review-pr`                               |
| `severityLevels` | `["CRITICAL", "HIGH", "MEDIUM", "LOW"]`       |
| `requiresPr`     | **`true`** — it resolves a pull request first |
| verdict on       | what the skill reports                        |
| `status`         | `unverified`                                  |
| `lastChecked`    | 2026-09                                       |

```json
{
  "kind": "local-command",
  "invoke": "skill",
  "command": "ecc:review-pr",
  "requiresPr": true,
  "severityLevels": ["CRITICAL", "HIGH", "MEDIUM", "LOW"],
  "status": "unverified"
}
```

**This card records what the installed command declares, not what a run of it produced.** Nobody has
driven `review-loop-local` with this reviewer.

**`requiresPr` is true, and the local loop cannot check it.** The reviewer resolves the pull request
itself, inside its own invocation; the local loop has no `gh` grant and never opens one. So step 1
neither aborts nor guesses — it **asks you to confirm that the branch already has an open pull
request** — and step 7 refuses to read a zero-finding result from this reviewer as a clean round,
because with no target and with a clean diff it returns the same nothing. Run it on a branch whose
pull request the remote loop opened, or that you opened by hand.

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
  reviewer that returns nothing is indistinguishable from one that found nothing. The loop cannot
  resolve that from outside — it has no `gh` grant — so the key buys a confirmation before the first
  round and a standing refusal to read zero findings from this reviewer as clean, rather than an
  abort that would make the preset unreachable on a branch where it works.
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

- **What a run actually emits.** The command carries no output template, so the aggregate shape is
  whatever the model produces; the agent template above specifies one of six inputs to that, not the
  result. **Nothing here has been observed coming back.** If the shape turns out not to be stable,
  the honest move is `status: unsupported`, not a looser parse.
- **Whether the confidence rule's three words ever appear in output at all.**
- Findings per round, recurrence across rounds, rounds to converge, and tokens per round.
- Whether the six agents' findings arrive already merged in practice, or arrive as six sections.
