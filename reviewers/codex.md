# codex

| Field         | Value                                                             |
| ------------- | ----------------------------------------------------------------- |
| `triggerKind` | `comment`                                                         |
| `trigger`     | `@codex review`                                                   |
| `botLogin`    | `chatgpt-codex-connector[bot]`                                    |
| `verdictOn`   | `comments` (findings arrive as a review; terminal signals do not) |
| `status`      | `verified`                                                        |
| `lastChecked` | 2026-08                                                           |

```json
{
  "trigger": "@codex review",
  "botLogin": "chatgpt-codex-connector[bot]",
  "verdictOn": ["reviews", "comments"],
  "cleanPatterns": ["^Codex Review: Didn't find any major issues\\."],
  "rateLimitPatterns": ["You have reached your Codex usage limits"],
  "severityLevels": ["P1", "P2", "P3"]
}
```

## Measured

- **Latency 3–4 minutes** to a verdict (`iwmaeda/iwmaeda#8`, `#11`; repo C, 2026-08).
- **1–4 findings per round** (repo C, 2026-08, 37 rounds). This is the number that makes sweeping for
  siblings worthwhile: leaving one behind costs a whole round.
- **Terminal signals arrive as issue comments, not reviews.** On `iwmaeda/iwmaeda#8` and `#11`,
  `/pulls/<n>/reviews` was empty while the clean verdict sat in `/issues/<n>/comments`.
- **The clean phrase's tail varies between rounds.** Observed after
  `Codex Review: Didn't find any major issues.` — `Keep it up!`, `:tada:`, `Breezy!`, and
  `What shall we delve into next?` (repo C, 2026-08). **Match it as a prefix.**
- **Supports a one-off focus suffix**: `@codex review <focus>` points the round's findings budget.
- Severities `P1`/`P2`/`P3` appear as a badge at the head of each finding body. One 70-finding sample
  had 12 P1, 58 P2, and zero P3 (repo C, 2026-08).

## Not measured

- The documented "👍 reaction when there are no findings" path. Every measured trigger carried zero
  reactions.
