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
  "severityLevels": ["P1", "P2", "P3"],
  "markerTolerated": "verified"
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
- **The revloop marker is tolerated.** A trigger body of `@codex review`, a blank line, and the
  `<!-- revloop:trigger ... -->` comment was recognised and answered (`iwmaeda/revloop#2`, 2026-08).
  The connector does not require the body to be the trigger phrase alone.
- **The rate-limit reply arrives in about 10 seconds**, two orders of magnitude faster than a real
  verdict (`iwmaeda/revloop#2`, 2026-08). A response that fast is a failure, not a review. Its exact
  text is `You have reached your Codex usage limits for code reviews.` followed by a dashboard link,
  so the pattern above matches it as a prefix.
- **REST and GraphQL spell the login differently**, measured on the same comment
  (`iwmaeda/revloop#2`, 2026-08):

  | API     | `login`                        |
  | ------- | ------------------------------ |
  | REST    | `chatgpt-codex-connector[bot]` |
  | GraphQL | `chatgpt-codex-connector`      |

  The wait fence reads GraphQL, so comparing its output against a `botLogin` written the REST way
  **rejects every legitimate verdict**. Strip the suffix before comparing.

- Severities `P1`/`P2`/`P3` appear as a badge at the head of each finding body. One 70-finding sample
  had 12 P1, 58 P2, and zero P3 (repo C, 2026-08).

## Not measured

- The documented "👍 reaction when there are no findings" path. Every measured trigger carried zero
  reactions.
- **A full review with the marker attached.** The marker was recognised, but the round that would
  have proved a complete review hit the account's code-review quota. Trigger recognition is
  `verified`; end-to-end review with a marker is not yet.
