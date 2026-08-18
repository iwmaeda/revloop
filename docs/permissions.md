# Permissions

## The rules to grant

Put these in `.claude/settings.local.json` (per-developer, git-ignored) or `.claude/settings.json`
(shared):

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/{owner}/{repo}/:*)",
      "Bash(gh api graphql:*)",
      "Bash(gh pr:*)",
      "Bash(gh repo view:*)",
      "Bash(git:*)"
    ]
  }
}
```

**A plugin cannot grant itself permissions.** There is no install-time hook that merges anything into
your settings, which is why this is a copy-and-paste list rather than something revloop does for you.

## Why `{owner}/{repo}` matters

`gh api` expands `{owner}` and `{repo}` from the current repository's remote, so no call in the
procedure needs a literal slug or a `$(...)` substitution. That is what makes the narrow rule possible:

| Rule                                   | Reach                                     |
| -------------------------------------- | ----------------------------------------- |
| `Bash(gh api *)`                       | **every repository your token can touch** |
| `Bash(gh api repos/{owner}/{repo}/:*)` | only the repository you are in            |

Prefer the narrow one.

## Why the wait scripts take no arguments

Permission rules match on a command-string **prefix**. If the wait script embedded the PR number, a
timestamp, or the reviewer's name, the string would differ every round, so "always allow" would never
apply and you would be prompted on every round — which is exactly where `--auto` dies.

The wait scripts therefore resolve the repository and PR themselves and take no arguments at all.
Their text is permanently identical, so one approval holds forever.

**Consequence: editing a fence costs every user one re-approval.** That is deliberate. The
re-approval prompt is how you find out that the bytes you granted standing permission to have
changed. revloop keeps `tests/fence-hashes.txt` and fails CI when a fence changes without a
`CHANGELOG.md` entry, so the cost is never paid by accident.

This is also why revloop does **not** ship the fences as scripts under the plugin directory and call
them by path. That would make the command string constant across edits — and would quietly convert
your one-time grant into standing permission for whatever future versions of that script contain.

## Verify commands are deliberately not pre-approved

`.revloop.json` supplies the verify commands, so they are **repository-supplied strings**. Listing
them in the command's `allowed-tools` would pre-approve whatever a cloned repository happens to put
there. They are excluded on purpose, so the permission system always sees them — and step 1 prints
them in the resolved-configuration table **before** anything runs.

## Counting the prompts

The install is meant to reach zero prompts per round after the first approval. If yours does not,
that is a bug worth reporting: include the prompt text and the rule you granted.
