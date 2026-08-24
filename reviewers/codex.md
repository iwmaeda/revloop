# codex

| Field         | Value                                                             |
| ------------- | ----------------------------------------------------------------- |
| `triggerKind` | `comment`                                                         |
| `trigger`     | `@codex review`                                                   |
| `botLogin`    | `chatgpt-codex-connector[bot]`                                    |
| verdict on    | `comments` (findings arrive as a review; terminal signals do not) |
| `status`      | `verified`                                                        |
| `lastChecked` | 2026-08                                                           |

```json
{
  "trigger": "@codex review",
  "botLogin": "chatgpt-codex-connector[bot]",
  "cleanPatterns": ["^Codex Review: Didn't find any major issues\\."],
  "rateLimitPatterns": ["You have reached your Codex usage limits"],
  "severityLevels": ["P1", "P2", "P3"],
  "markerTolerated": "verified"
}
```

## Measured

- **Latency 3–4 minutes** to a verdict (`iwmaeda/iwmaeda#8`, `#11`; repo C, 2026-08).
- **1–4 findings per round** (repo C, 2026-08, 37 rounds). This is the number that makes sweeping for
  siblings worthwhile: leaving one behind costs a whole round. A second sample runs narrower: one PR
  produced **23 finding-bearing rounds returning 1–2 each, mean 1.22**, never more than 2, and an
  earlier PR in the same repository averaged 1.52 with the same maximum (repo C, 2026-08). **The two
  samples share a repository and an account**, so they corroborate the centre, not the range.
- **Derived from the samples above**, not separately observed: a round costs roughly one finding, so
  **the number of rounds a PR needs is roughly the number of defects present when the trigger
  fires**. This is arithmetic on the measurements. It is why the procedure sweeps in step 10 and
  re-reads the diff in step 3 — waiting more cleverly cannot move this number, firing with fewer
  defects can.
- **A predicate's missing input forms arrive one per round.** On one PR, roughly 20 of 30 rounds were
  successive members of a single predicate's input space — a particle, then a comma-joined form, then
  leading whitespace, then whitespace around a joiner, then an em dash, then a compound particle
  (repo C, 2026-08). **The corpus never went red for any of them**: the missing forms are inputs the
  predicate could receive, not text that exists in the tree, so no amount of grepping the repository
  would have found the next one.
- **Findings concentrate, and consecutive findings repeat a file.** One PR's 28 findings fell in 3
  files (13/13/2); an earlier one's 30 fell in 5 (14 and 10 in the top two). Across four PRs, the
  next finding landed in the same file as the previous one **39–52%** of the time (repo C, 2026-08).
- **Severity does not predict anything.** One PR returned 15 of 15 at P2, another 15 of 15 at P1, a
  third 25 P1 and 3 P2 (repo C, 2026-08). The mix moves per PR, so do not triage by badge. P3 stayed
  at zero across all four, which matches the 70-finding sample below.
- **Round counts across seven PRs in one repository**: 2, 3, 3, 8, 10, 21, 30 (repo C, 2026-08). The
  30-round PR ran 16.8 hours; its round-to-round gap was a median of 9.2 minutes, so the wall clock
  is dominated by the number of rounds, not by any single wait.
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
