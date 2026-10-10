# gemini

| Field         | Value                     |
| ------------- | ------------------------- |
| `triggerKind` | `comment`                 |
| `trigger`     | `@gemini review`          |
| `botLogin`    | `gemini-code-assist[bot]` |
| verdict on    | `reviews`                 |
| `status`      | `verified`                |
| `lastChecked` | 2026-08                   |

Definition: [`gemini.json`](gemini.json). Driven by `/revloop:remote-gemini-loop`.

## Measured

- Both `@gemini review` and `/gemini review` have drawn a review, in different repositories. Check
  your pull-request history for the form your installation answers.
- Findings arrive as a review.
- It posts a `## Summary of Changes` comment before the review. The wait fence drops it.
- A round returns 30 to 50 findings.
- It has answered a trigger with an error instead of a review.

## Not measured

- Whether the `severityMap` is right. It was copied from the Codex card and has not been checked
  against this reviewer's output.
- What it says when it finds nothing, and when it is out of quota. The definition has neither
  pattern, so a clean round is a review with no findings.
- Whether it answers with the revloop marker appended.
