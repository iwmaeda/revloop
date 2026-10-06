# ecc-review-pr

The `review-pr` command from the ECC plugin, run as a subprocess.

| Field               | Value                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------- |
| `kind`              | `local-command`                                                                               |
| `invoke`            | `subprocess`                                                                                  |
| `command`           | `claude --model {reviewModel} --effort medium --append-system-prompt "…" -p "/ecc:review-pr"` |
| `severityLevels`    | none                                                                                          |
| `requiresPr`        | `true`                                                                                        |
| `rateLimitPatterns` | `["You've hit your session limit"]`                                                           |
| verdict on          | the command's stdout                                                                          |
| `status`            | `unverified`                                                                                  |
| `lastChecked`       | 2026-10                                                                                       |

Definition: [`ecc-review-pr.json`](ecc-review-pr.json). Driven by `/revloop:local-ecc-loop`.

The `"…"` in the command row is the argument to `--append-system-prompt`. It must match the
definition:

```text
Non-interactive run: nobody can answer a question or approve a tool call. If a call is denied, never ask and never retry it. If the pull request cannot be read, say so and stop. Otherwise finish without that call, list what you could not run, and open the report with its number, title and changed files.
```

## Output shape

- With findings: one report that names the pull request it reviewed, then findings under the
  headings `## Critical`, `## Important` and `## Advisory`. Each finding has an inline confidence
  percentage. A heading with no findings is left out.
- With nothing to fix: a report that names the pull request, lists what each agent found or set
  aside, and states that there are no blocking findings. It has no headings.

A result that does not name the pull request it reviewed is `unparsed-review-output`, never a clean
round. Three such results are known, all with exit 0:

- No permission block: prose saying that `gh` was blocked, ending with a question.
- Out of quota: one line starting `You've hit your session limit`, followed by a reset time.
  `rateLimitPatterns` matches it.
- A refused tool call: one line asking for permission.

## Measured

- A round takes 3 to 12 minutes, rising with the diff. It is the slowest built-in reviewer.
- Five consecutive rounds on one change returned 3 to 10 findings each, with no finding repeated,
  and reached the round cap without a clean round.
- The headings are the command's confidence words. No severity tag, summary table or verdict line
  appears, so the definition declares no `severityLevels`.
- The command dispatches up to six agents and merges their findings into one report. A round may
  dispatch fewer.
- It resolves the pull request of the current branch through `gh`. For that, the checkout's
  `.claude/settings.local.json` needs the permission block from the README.
- The subprocess cannot run the project's tests and says so. It reviews by reading.
- A refused command does not always end a round. One round was refused four commands and still
  reported.
- The session-limit notice uses an ASCII apostrophe, and a `·` (U+00B7) before `resets`. The pattern
  stops at `limit`.
- The host accepts `--effort medium` with `sonnet` and with `haiku`. A host without `--effort` fails
  the round with `review-command-failed`.
- With the non-interactive instruction, short probe sessions that were refused a command reported
  what they could not run and did not ask.
- The command writes no file and posts nothing.

## Not measured

- A convergence: findings fixed, and a later round returning none.
- A review under the non-interactive instruction, and whether the instruction reaches the agents the
  command dispatches.
- Whether the reviewer stops when the pull request itself cannot be read.
- The heading shape under `--effort medium`, or under a model other than `sonnet`.
- Whether `--model` and `--effort` reach the dispatched agents.
- Whether the headings are an ordered ladder.
- Whether an item the reviewer reports below its own confidence bar counts as a finding.
- Whether the session-limit wording is the same for other limits and plans, and whether a quota
  notice can follow a partial review.
- The token cost of a round.
