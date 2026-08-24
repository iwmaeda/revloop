# copilot

| Field         | Value                                |
| ------------- | ------------------------------------ |
| trigger kind  | **reviewer request** — not a comment |
| `botLogin`    | `copilot-pull-request-reviewer[bot]` |
| verdict on    | `reviews`                            |
| `status`      | **`unsupported`**                    |
| `lastChecked` | 2026-08                              |

## Why it is `unsupported`

Copilot has no comment trigger. It is requested as a reviewer through the API:

```bash
gh api -X POST "repos/{owner}/{repo}/pulls/<n>/requested_reviewers" -f 'reviewers[]=copilot-pull-request-reviewer'
```

The procedure has only the comment path: step 7 posts a trigger comment carrying the revloop marker,
and steps 8 and 9 read the round's identity out of that marker. A reviewer request posts no comment,
so there is nothing to anchor the round's baseline to. Step 1 aborts with `reason=no-comment-trigger`
when the resolved reviewer has no `trigger`.

An earlier draft described a `triggerKind: reviewer-request` mode that would post the marker as its
own announcement comment and issue the request alongside it. That mode was never implemented, so the
configuration keys for it have been removed rather than left in the schema looking usable. The design
is still sound; it just is not written.

Copilot also posts `Copilot is reviewing` and `Copilot wasn't able to review` as interim comments.
Those two patterns are in the wait fence's drop list already — they were added when the fence was
written, and they stay because removing them would cost a re-approval for no gain.

## Measured

- Copilot reviews exist on `iwmaeda/iwmaeda#1` and `#2` (2026-08), **fired automatically rather than
  by request**. **Derived:** they are the reason the loop filters bot verdicts by the marker's `bot=`
  — a second reviewer's review otherwise arrives inside the waiting window and is read as this
  round's verdict — and they are why the card is kept even though the preset cannot be driven.

## Not measured

- The reviewer-request path. It has never been driven by this tool, which is why the preset is
  `unsupported` rather than `unverified`.
