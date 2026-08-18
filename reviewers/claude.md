# claude

| Field         | Value            |
| ------------- | ---------------- |
| `triggerKind` | `comment`        |
| `trigger`     | `@claude review` |
| `botLogin`    | `claude[bot]`    |
| `verdictOn`   | unknown          |
| `status`      | `unverified`     |
| `lastChecked` | 2026-08          |

```json
{
  "trigger": "@claude review",
  "botLogin": "claude[bot]",
  "verdictOn": ["reviews", "comments"]
}
```

## Measured

- **No response** to a trigger on `iwmaeda/iwmaeda#7` (2026-08). One observation, on one repository.

**Do not read that as "claude does not work".** Whether a trigger is answered depends on the Claude
GitHub App being installed and configured on the repository, which was not confirmed at the time. The
preset is shipped so the loop can drive it; the status stays `unverified` until someone drives it
successfully and updates this card.
