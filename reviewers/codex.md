# codex

| Field         | Value                                                    |
| ------------- | -------------------------------------------------------- |
| `triggerKind` | `comment`                                                |
| `trigger`     | `@codex review`                                          |
| `botLogin`    | `chatgpt-codex-connector[bot]`                           |
| verdict on    | Findings as a review; terminal signals as issue comments |
| `status`      | `verified`                                               |
| `lastChecked` | 2026-10                                                  |

Definition: [`codex.json`](codex.json). Driven by `/revloop:remote-codex-loop`.

## Measured

- A verdict takes 3 to 10 minutes. A clean round takes about as long.
- A round returns 1 to 4 findings, so a pull request needs roughly as many rounds as it has defects
  when the trigger fires. Pull requests have taken from 1 to 30 rounds.
- Consecutive findings often land in the same file, and the missing input forms of one predicate
  arrive one per round.
- Each finding body starts with a `P1`, `P2` or `P3` badge. The mix varies by pull request and `P3`
  is rare, so do not triage by the badge.
- Findings arrive as a review. A review can carry its whole finding in the body, with no inline
  comment.
- Terminal signals arrive as issue comments: the clean phrase and the rate-limit reply.
- The clean phrase is `Codex Review: Didn't find any major issues.` followed by text that varies
  between rounds. Match it as a prefix.
- The rate-limit reply starts `You have reached your Codex usage limits` and arrives in about 10
  seconds.
- A status card may arrive seconds after the trigger: an issue comment whose first line is
  `<!-- codex-pull-request-review-summary -->`, edited in place from `Running` to `Completed`. It
  carries no verdict, and the wait fence drops it.
- The reviewer's 👍 lands on the pull request's description, not on the trigger comment, so the
  `reaction` verdict does not fire.
- `@codex review <focus>` is accepted and answered.
- The trigger is answered with the revloop marker appended.
- REST spells the login `chatgpt-codex-connector[bot]`, and GraphQL `chatgpt-codex-connector`.

## Not measured

- Whether the `severityMap` is right. It is a judgement: `P1` to `critical`, `P2` to `high` and `P3`
  to `low`, with nothing mapped to `medium`.
- Whether a 👍 ever lands on the trigger comment.
- Whether the status card is created once per pull request or once per trigger, and what it shows
  in a state other than `Running` or `Completed`.
- Whether a trigger posted after a rate limit, at an unchanged HEAD, draws a review once the quota
  is back.
