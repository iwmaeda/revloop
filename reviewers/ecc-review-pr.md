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
Non-interactive run: never ask and never retry a denied call. Finish without it and list what did not run. Read the pull request with gh pr view --json number,title,files and gh pr diff, never plain gh pr view. If it cannot be read, say so and stop. Open the report with its number, title and changed files.
```

## Output shape

- With findings: one report that names the pull request it reviewed, then findings grouped under
  the labels `Critical`, `Important` and `Advisory`. A label is a `##` heading or a bold line, and
  a label with no findings is left out. A round may add a label of its own. A finding may carry an
  inline confidence percentage.
- With nothing to fix: a report that names the pull request, lists what each agent found or set
  aside, and states that there are no blocking findings. It has no headings.
- Short progress lines may come before either report. The report is the last message.

A result that does not name the pull request it reviewed is `unparsed-review-output`, never a clean
round. Four such results are known, all with exit 0:

- No permission block: prose saying that `gh` was blocked, ending with a question.
- Out of quota: one line starting `You've hit your session limit`, followed by a reset time.
  `rateLimitPatterns` matches it.
- A refused tool call: one line asking for permission.
- An unreadable pull request: a report on the branch diff, saying that the pull request could not
  be read.

## Measured

- A round takes 3 to 12 minutes, rising with the diff. It is the slowest built-in reviewer.
- Five consecutive rounds on one change returned 3 to 10 findings each, with no finding repeated,
  and reached the round cap without a clean round.
- The labels are the command's confidence words. No severity tag, summary table or verdict line
  appears, so the definition declares no `severityLevels`.
- Of 203 reports, about three in four put those words in `##` headings. The rest used bold lines,
  headings of the reviewer's own, or no labels. One report in three carried confidence percentages.
- The command dispatches up to six agents and merges their findings into one report. A round may
  dispatch fewer.
- The agents run in the background, and the reviewer ends a turn each time it waits for one. At
  Claude Code 2.1.296, stdout carries the last message of every turn, so progress lines precede the
  report. At 2.1.233 and 2.1.283 it carried the last turn's message alone.
- It resolves the pull request of the current branch through `gh`. For that, the checkout's
  `.claude/settings.local.json` needs the permission block from the README.
- On `gh` 2.4.0, `gh pr view` without `--json` fails with a GraphQL error about Projects (classic).
  `gh pr view --json` and `gh pr diff` work there, and the instruction names them.
- Without being told how, the reviewer opened with `gh pr view --json` in 222 of 223 rounds. The
  other round opened with plain `gh pr view` on `gh` 2.4.0, could not read the pull request, and
  reviewed the branch diff without naming it.
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
- Whether the reviewer, under the instruction, stops when the pull request cannot be read.
- The report shape under a model other than `sonnet`.
- Which Claude Code release began printing every turn's last message.
- Whether `--model` and `--effort` reach the dispatched agents.
- Whether the headings are an ordered ladder.
- Whether an item the reviewer reports below its own confidence bar counts as a finding.
- Whether the session-limit wording is the same for other limits and plans, and whether a quota
  notice can follow a partial review.
- The token cost of a round.
