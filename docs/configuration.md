# Configuration

`.revloop.json` at the repository root. Every field is optional — with no file at all, revloop detects
what it needs. The [schema](../schema/revloop.schema.json) is machine-readable and the
[examples](../examples/) are a faster start than this page.

```json
{
  "$schema": "https://raw.githubusercontent.com/iwmaeda/revloop/main/schema/revloop.schema.json",
  "version": 1,
  "project": {
    "verify": ["npm run check:all", "npm test"],
    "verifyNotes": "check:all does not run the tests; CI splits them into two jobs"
  },
  "defaults": { "reviewer": "codex", "maxRounds": 12 }
}
```

`$schema` is optional and buys editor completion. `version` is `1`; an unknown major version aborts
rather than degrading.

## Nothing is required

With no config, revloop detects everything and prints where each value came from:

| Value            | How it is detected when absent                                                                      |
| ---------------- | --------------------------------------------------------------------------------------------------- |
| `baseBranch`     | `gh repo view --json defaultBranchRef`                                                              |
| `verify`         | The repository's build files — `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod` |
| `branchPrefixes` | The prefixes actually used in the repository's commit subjects                                      |
| `commit.*`       | The last 20 commit subjects and bodies: style, language, existing trailers                          |
| `reviewers`      | The built-in presets                                                                                |

The `source` column of the step-1 table is `flag`, `config`, `detected`, or `builtin`. **Read it.** It
is how you tell a value you chose from a value revloop guessed, without reading any code.

## When config is missing or wrong

| Situation                             | Behaviour                                                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| No `.revloop.json`                    | Detect everything. Normal                                                                                                                   |
| Malformed JSON                        | **Abort.** No fallback                                                                                                                      |
| Unknown key                           | Not validated at runtime; ignored. `tests/schema.test.sh` rejects it in CI against fixtures, per the schema's `additionalProperties: false` |
| Unknown `version`                     | **Abort**                                                                                                                                   |
| `--reviewer` names nothing known      | **Abort** and list the available names. Never guess                                                                                         |
| No verify command found or configured | Ask before continuing; record "no verification ran" in the report                                                                           |
| ...and `--merge` was passed           | **Abort.** Do not merge code that nothing checked                                                                                           |

Malformed config aborts rather than falling back, because a silent fallback to the presets would
ignore exactly the custom reviewer a user configured, while the run still looked healthy.

## `project`

| Key                | Meaning                                                                   |
| ------------------ | ------------------------------------------------------------------------- |
| `baseBranch`       | PR base. `null` means detect                                              |
| `verify`           | Commands run before pushing. Run them **exactly as CI runs them**         |
| `verifyNotes`      | Which CI job the umbrella command does **not** reproduce. Sometimes empty |
| `branchPrefixes`   | Allowed topic-branch prefixes                                             |
| `pr.titleLanguage` | Language for the PR title                                                 |

Almost every repository has one umbrella command (`npm run check:all`, `make check`) that does _not_
cover everything CI runs — one project's skipped the tests, another's skipped `npm audit`. Write the
gap into `verifyNotes` so the loop closes it before pushing; a red CI costs a whole review round.

### `project.commit`

| Key               | Meaning                                                                 |
| ----------------- | ----------------------------------------------------------------------- |
| `style`           | Commit-subject convention, e.g. `conventional`                          |
| `subjectLanguage` | Language for the subject line                                           |
| `bodyLanguage`    | Language for the body                                                   |
| `scopes`          | Allowed scopes, e.g. `["api", "web", "infra"]`                          |
| `verifiedLabel`   | Label introducing the list of commands actually run, e.g. `"Verified:"` |
| `trailers`        | Trailers to append. `{model}` expands to the running model's name       |
| `onePerRound`     | Whether a round produces a single commit rather than a split            |

## `defaults`

Defaults for the command flags; a flag always overrides its default. Resolution is flag, then this
block, then the built-in, and step 1 prints which one won.

| Key         | Meaning                                                               | Built-in |
| ----------- | --------------------------------------------------------------------- | -------- |
| `reviewer`  | A preset (`codex`, `gemini`, `claude`) or a name from `reviewers`     | —        |
| `maxRounds` | Circuit breaker on the number of review rounds                        | `10`     |
| `timeout`   | Cumulative cap on waiting for one **trigger's** verdict, e.g. `"45m"` | `30m`    |

`--merge` and `--auto` have no entry here on purpose — see below.

## What is deliberately not configurable

A key that can only hold the value it already has is a promise, not a setting. These are fixed:

| Not a key                                  | Why                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--merge` / `--auto` defaults              | This file comes from the repository you are in, including one you just cloned. It must not grant its own merge or delete your confirmation points. **The flag is the approval**                                                                                                                                                                                                                                                                                                                   |
| Merge method                               | The merge fence sends `merge_method=merge` and takes no arguments, so its command string never changes                                                                                                                                                                                                                                                                                                                                                                                            |
| "Require clean CI before merge"            | The gate re-runs its own check inside the merge step and cannot be loosened from a file                                                                                                                                                                                                                                                                                                                                                                                                           |
| Which endpoints carry a verdict            | The wait fence pulls comments, reviews and reactions in one call, always. Watching one is how a poll waits forever                                                                                                                                                                                                                                                                                                                                                                                |
| Interim-comment patterns                   | The drop list lives **inside** the wait fence, because config never reaches a fence. Teaching it a new preamble is a fence edit — one re-approval for every user                                                                                                                                                                                                                                                                                                                                  |
| The round number                           | Counted from the `revloop:trigger` markers already on the PR that opened a round, plus one. The PR is the memory, so a resumed run needs no local state. It counts revloop's rounds, so a PR adopted mid-flight restarts at 1                                                                                                                                                                                                                                                                     |
| The retry budget and the silence threshold | One re-post per round, and never before three silent 8-minute chunks. A budget above one has nothing measured behind it, and it spends the reviewer's quota — the same class as `--merge`, so not something the repository you happen to be standing in gets to raise. The threshold is fixed in chunks rather than derived from `timeout` because a derived one could be pushed below the reviewer's measured latency by _lowering_ a flag, which is the runaway the invariant exists to prevent |

Counting rounds from GitHub rather than from commit subjects is what lets an interrupted run resume in
a fresh session: a round that ended with no findings still cost you a wait, and it left a marker but no
commit. The count is of markers alone, so a pull request driven by hand before revloop was adopted
starts again at 1 — an exact number anyone can reproduce by hand, rather than one that depends on
replaying the wait fence's compatibility pattern outside the fence. A marker carrying an `attempt` key
is excluded from that count because it re-posts a round that was already open, and it is written
**only** on a re-post so the exclusion stays a one-line test. That test reads the key: a raw search for
`attempt=` also matches `notattempt=2` and a quoted `"attempt=2"` in a garbled payload, either of which
would undercount the round. Counting re-posts would let a reviewer that drops one comment halve
`maxRounds` without anyone noticing.

`timeout` caps one trigger rather than one round, so a round that has to re-post waits up to twice it
— about an hour at the built-in value. That is the whole cost of the re-post path, and it is the one
number to change if the wall clock matters more to you than recovering a dropped trigger.

## `reviewers`

Adds to or overrides the presets. See [adding-a-reviewer.md](adding-a-reviewer.md) for the full field
list and how to fill it in from measurements.

Every pattern here is used model-side only. None of it is interpolated into a shell command or a jq
program, which is what keeps a `.revloop.json` from a cloned repository from becoming a code-execution
path. The rest of the surface is closed by rule:

1. `verify` entries are shown in the step-1 table and left out of `allowed-tools`, so the permission
   system always sees them.
2. `trigger` is posted verbatim: control characters are rejected, length is capped, and a value that
   already contains `revloop:trigger` is rejected.
3. `botLogin` must match `^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$`.
4. Safety rules cannot be disabled from config — the table above is the full list of what is fixed.

## Related docs

- [Adding a reviewer](adding-a-reviewer.md) — filling in `reviewers` from measurements
- [Permissions](permissions.md#verify-commands-are-not-pre-approved) — why `verify` is never
  pre-approved
- [`../examples/`](../examples/) — four working `.revloop.json` files
