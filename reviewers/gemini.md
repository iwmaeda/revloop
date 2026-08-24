# gemini

| Field         | Value                            |
| ------------- | -------------------------------- |
| `triggerKind` | `comment`                        |
| `trigger`     | **`@gemini review`** — see below |
| `botLogin`    | `gemini-code-assist[bot]`        |
| verdict on    | `reviews`                        |
| `status`      | `verified`                       |
| `lastChecked` | 2026-08                          |

```json
{
  "trigger": "@gemini review",
  "botLogin": "gemini-code-assist[bot]",
  "severityLevels": ["P1", "P2", "P3"]
}
```

## Measured

- **The trigger form is not settled.** `/gemini review` worked in `iwmaeda/iwmaeda#4` and `#5` and in
  repo B; repo C's history has **30+ triggers, all `@gemini review`, and not one `/gemini review`**
  (2026-08). **Derived:** set `trigger` per project and confirm from the PR history rather than
  assuming.
- **Findings arrive as a review**, not an issue comment (`iwmaeda/iwmaeda#4`, `#5`; repo B, 2026-08)
  — the opposite of codex. **Derived:** a poll watching only one endpoint waits forever on one
  reviewer or the other, which is why the loop watches both in one call.
- **It posts a `## Summary of Changes` preamble before the review** (repo B, 2026-08). **Derived:**
  the preamble is a _non-terminal_ comment, so the wait fence drops it inside the jq program —
  treating it as terminal makes the fence exit on its first iteration every time it is re-fired, an
  infinite loop that never sleeps. **The pattern is in the fence, not in this card's config**, because
  config never reaches a fence, so a preamble is the one reviewer property that costs a fence edit.
  See
  [`../docs/adding-a-reviewer.md`](../docs/adding-a-reviewer.md).
- **30–50 findings per round** (repo C, 2026-08; one PR returned 50). **Derived:** that is an order
  of magnitude more than codex, so switching reviewers trades round count against per-round reading
  cost. Budget for it deliberately.
- Errored on both attempts in `iwmaeda/iwmaeda#7`.

## Not measured

- **The clean-phrase and rate-limit texts.** The config block carries neither, so a clean round is
  recognised by a review arriving with no inline comments rather than by a phrase. Nobody has
  recorded what this reviewer says when it finds nothing, or when it is out of quota.
- **Whether the revloop marker is tolerated.** Measured for codex, assumed here.
