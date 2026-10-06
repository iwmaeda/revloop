# code-review

The review command built into Claude Code, run as a subprocess.

| Field               | Value                                                   |
| ------------------- | ------------------------------------------------------- |
| `kind`              | `local-command`                                         |
| `invoke`            | `subprocess`                                            |
| `command`           | `claude --model {reviewModel} -p "/code-review medium"` |
| `severityLevels`    | none                                                    |
| `requiresPr`        | `false`                                                 |
| `rateLimitPatterns` | `["You've hit your session limit"]`                     |
| verdict on          | the command's stdout                                    |
| `status`            | `unverified`                                            |
| `lastChecked`       | 2026-09                                                 |

Definition: [`code-review.json`](code-review.json). Driven by `/revloop:local-review-loop`.

## Output shape

The shape changes with the model. Parse these and nothing else; any other output is
`unparsed-review-output`.

- A list: prose, then a line `Findings (N):`, then one bullet per finding with a backticked
  `path:line`, a dash and the claim.
- A fenced JSON array after the prose. Each object has a file, a line, a summary and a failure
  scenario; `category` and `verdict` (`CONFIRMED` or `PLAUSIBLE`) are optional.
- No findings: prose that names what was reviewed and states that the count is zero. It may carry an
  empty array, `[]`.
- One line per finding, a `path:line` followed by a summary. The command declares this form; it has
  not been seen.

## Measured

- A round takes 2 to 9 minutes, rising with the size of the diff.
- Without a model pin, five rounds on one large change returned 6 to 10 findings each and reached
  the round cap without a clean round. Each round's fixes produced findings for the next. Under
  `sonnet`, three rounds on smaller diffs returned none.
- No finding carries a severity. `verdict` is a confidence, and the order of the list is not a rank.
- The effort level caps the findings in one run: about 4 at `low`, 8 at `medium`, 10 at `high` and
  15 at `xhigh` and `max`. A run can exceed the figure slightly.
- `ultra` is not an effort level. It is a separate subcommand that runs a cloud review, so do not put
  it in `command`.
- The command picks its own target: the range against the branch's upstream, or against the base
  branch when there is no upstream, plus the working tree when the range is empty or the tree is
  dirty. One round run after a push still reviewed the whole branch.
- The subprocess does not inherit the caller's permissions. Rounds that could not run the test suite
  said so and reviewed by reading.
- The command cannot be started by the model, which is why `invoke` is `subprocess`.

## Not measured

- A convergence: findings fixed, and a later round returning none.
- Findings under the `sonnet` pin, and the token cost of a round.
- The grader against this reviewer.
- Whether `rateLimitPatterns` matches. It was copied from `ecc-review-pr`, which runs the same
  binary.
- Whether there are output shapes beyond those listed.
- Whether a refused tool call makes this reviewer end with a question.
- Whether the repeat suppression or the ten-finding batch limit ever applies.
