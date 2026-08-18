# copilot

| Field         | Value                                  |
| ------------- | -------------------------------------- |
| `triggerKind` | **`reviewer-request`** — not a comment |
| `botLogin`    | `copilot-pull-request-reviewer[bot]`   |
| `verdictOn`   | `reviews`                              |
| `status`      | `unverified`                           |
| `lastChecked` | 2026-08                                |

```json
{
  "triggerKind": "reviewer-request",
  "announce": true,
  "botLogin": "copilot-pull-request-reviewer[bot]",
  "verdictOn": ["reviews"],
  "ignoreCommentPatterns": ["^Copilot is reviewing", "^Copilot wasn't able to review"]
}
```

## The trigger is different

Copilot has no comment trigger. It is requested as a reviewer through the API:

```bash
gh api -X POST "repos/{owner}/{repo}/pulls/<n>/requested_reviewers" -f 'reviewers[]=copilot-pull-request-reviewer'
```

With `triggerKind: reviewer-request`, the loop posts the marker as its own announcement comment
**and** issues the request. The extra comment is what anchors the round's baseline; it also leaves the
round visible in the PR timeline, which is worth having on its own.

## Measured

- Copilot reviews exist on `iwmaeda/iwmaeda#1` and `#2` (2026-08), **fired automatically rather than
  by request**. They are the reason the loop filters bot verdicts by the marker's `bot=`: a second
  reviewer's review otherwise arrives inside the waiting window and is read as this round's verdict.
- The end-to-end request path has not been driven by this tool. Status stays `unverified`.
