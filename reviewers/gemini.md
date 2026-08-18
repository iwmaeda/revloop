# gemini

| Field         | Value                            |
| ------------- | -------------------------------- |
| `triggerKind` | `comment`                        |
| `trigger`     | **`@gemini review`** — see below |
| `botLogin`    | `gemini-code-assist[bot]`        |
| `verdictOn`   | `reviews`                        |
| `status`      | `verified`                       |
| `lastChecked` | 2026-08                          |

```json
{
  "trigger": "@gemini review",
  "botLogin": "gemini-code-assist[bot]",
  "verdictOn": ["reviews", "comments"],
  "ignoreCommentPatterns": ["^## Summary of Changes"],
  "severityLevels": ["P1", "P2", "P3"]
}
```

## Measured

- **The trigger form is not settled.** `/gemini review` worked in `iwmaeda/iwmaeda#4` and `#5` and in
  repo B; repo C's history has **30+ triggers, all `@gemini review`, and not one `/gemini review`**
  (2026-08). Set `trigger` per project and confirm from the PR history rather than assuming.
- **Findings arrive as a review**, the opposite of codex. A poll watching only one endpoint waits
  forever on one reviewer or the other — which is why the loop watches both in one call.
- **It posts a `## Summary of Changes` preamble before the review.** This is a _non-terminal_ comment.
  The wait fence drops it inside the jq program: treating it as terminal makes the fence exit on its
  first iteration every time it is re-fired, an infinite loop that never sleeps.
- **30–50 findings per round** (repo C, 2026-08; one PR returned 50). That is an order of magnitude
  more than codex. Switching reviewers trades round count against per-round reading cost — budget for
  it deliberately.
- Errored on both attempts in `iwmaeda/iwmaeda#7`.
