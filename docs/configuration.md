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
| Malformed JSON                        | **Abort.** Never fall back to the presets — that would ignore the custom reviewer the file configures while the run still looked healthy    |
| Unknown key                           | Not validated at runtime; ignored. `tests/schema.test.sh` rejects it in CI against fixtures, per the schema's `additionalProperties: false` |
| Unknown `version`                     | **Abort**                                                                                                                                   |
| `--reviewer` names nothing known      | **Abort** and list the available names. Never guess                                                                                         |
| No verify command found or configured | Ask before continuing; record "no verification ran" in the report                                                                           |
| ...and `--merge` was passed           | **Abort.** Do not merge code that nothing checked                                                                                           |

## `project`

| Key                | Meaning                                                                   |
| ------------------ | ------------------------------------------------------------------------- |
| `baseBranch`       | PR base. `null` means detect                                              |
| `verify`           | Commands run before pushing. Run them **exactly as CI runs them**         |
| `verifyNotes`      | Which CI job the umbrella command does **not** reproduce. Sometimes empty |
| `branchPrefixes`   | Allowed topic-branch prefixes                                             |
| `pr.titleLanguage` | Language for the PR title                                                 |

An umbrella check command usually does _not_ cover everything CI runs. Write the gap into
`verifyNotes` so the loop closes it before pushing; a red CI costs a whole review round.

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

| Key              | Meaning                                                               | Built-in |
| ---------------- | --------------------------------------------------------------------- | -------- |
| `reviewer`       | Default `--reviewer` for **the pull-request loop**                    | —        |
| `localReviewer`  | Default `--reviewer` for **the local loop**                           | —        |
| `maxRounds`      | Circuit breaker for **the pull-request loop**                         | `10`     |
| `localMaxRounds` | Circuit breaker for **the local loop**                                | `5`      |
| `timeout`        | Cumulative cap on waiting for one **trigger's** verdict, e.g. `"45m"` | `30m`    |

**The reviewer and the round cap are two keys each, one per loop**, because the loops want different
values and sharing a key silently applies the wrong one. A `reviewer` written before the local loop
existed names a `github-comment` reviewer, and a `maxRounds` written for the remote loop would raise
the local cap — which is the only brake that loop has. Both caps stay settable from config, unlike
`--accept-at`, because they bound spend rather than safety.

`--merge`, `--auto` and `--accept-at` have no entry here on purpose — see below.

## What is deliberately not configurable

A key that can only hold the value it already has is a promise, not a setting. These are fixed.
**Most of them name machinery only the pull-request loop has** — a merge fence, a wait fence, trigger
markers, a retry budget — and are listed here rather than in a per-loop section because the reason
they are fixed is the same in each case. `--merge`, `--auto` and `--accept-at` are the rows that bind
both loops:

| Not a key                                  | Why                                                                                                                                                                                                                                                                           |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--merge` / `--auto` defaults              | This file comes from the repository you are in, including one you just cloned. It must not grant its own merge or delete your confirmation points. **The flag is the approval**                                                                                               |
| `--accept-at`, anywhere                    | Same class. A repository that could set its own acceptance floor would lower its own review bar on a checkout you just cloned                                                                                                                                                 |
| Merge method                               | The merge fence sends `merge_method=merge` and takes no arguments, so its command string never changes                                                                                                                                                                        |
| "Require clean CI before merge"            | The gate re-runs its own check inside the merge step and cannot be loosened from a file                                                                                                                                                                                       |
| Which endpoints carry a verdict            | The wait fence pulls comments, reviews and reactions in one call, always. Watching one is how a poll waits forever                                                                                                                                                            |
| Interim-comment patterns                   | The drop list lives **inside** the wait fence, because config never reaches a fence. Teaching it a new preamble is a fence edit — one re-approval for every user                                                                                                              |
| The round number                           | Counted from the trigger markers already on the pull request. The pull request is the memory, so a resumed run needs no local state                                                                                                                                           |
| The retry budget and the silence threshold | One re-post per round, and not before a fixed floor of silence. Raising either spends the reviewer's quota — the same class as `--merge`. The floor is fixed rather than derived from `timeout`, so that lowering a flag cannot push it under the reviewer's measured latency |

**`timeout` caps one trigger, not one round**, so a round that re-posts waits about twice it. That is
the wall-clock cost of the re-post path, and `timeout` is the one number to change if the wall clock
matters more to you than recovering a dropped trigger. The rest of the argument — including what the
path can still lose — is in [design-notes.md](design-notes.md#the-baseline-timestamp-is-the-whole-safety-argument).

## The acceptance floor

`--accept-at <level>` names **the highest rung that may be left unfixed**. The rungs come from the
resolved reviewer's `severityLevels`, read most severe first, so on a `["P1","P2","P3"]` ladder
`--accept-at P2` leaves P1 blocking and makes P2 and P3 acceptable. Both loops take it.

| Situation                                      | Behaviour                                                                    |
| ---------------------------------------------- | ---------------------------------------------------------------------------- |
| Flag absent                                    | Nothing is acceptable. Identical to the behaviour before the flag existed    |
| Reviewer has no `severityLevels`               | **Abort** (`no-severity-ladder`). The loop never invents a ladder for itself |
| `<level>` is not a rung on that ladder         | **Abort** (`unknown-accept-level`), listing the ladder                       |
| With `--merge` and `--auto` together           | **Abort** (`unreviewed-accept-merge`)                                        |
| With `--merge` alone, having accepted anything | Stop for confirmation, listing every accepted finding, before the CI wait    |

**An accepted finding is still read, still recorded, and still listed in the report.** The flag
decides when the loop may stop, never what it may skip reading. **Where the record goes differs by
loop, because only one of them has somewhere to reply**: the pull-request loop answers each accepted
finding in a reply naming the rung and the floor, and the local loop, which opens no pull request,
writes the same pair into the commit's `Accepted:` block and the report. Why that boundary is where the flag is
safe, and why the loop refuses to invent a ladder for a reviewer that emits none, are in
[design-notes.md](design-notes.md#the-acceptance-floor).

## `reviewers`

Adds to or overrides the presets. See [adding-a-reviewer.md](adding-a-reviewer.md) for the full field
list and how to fill it in from measurements.

**A reviewer is one of two kinds.** `kind` is absent from every file written before the second kind
existed, and absent means `github-comment`, so nothing that worked before changes meaning.

| `kind`           | Required            | Also takes                                                         | May not carry                                                                  |
| ---------------- | ------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `github-comment` | `botLogin`          | `trigger`, `markerTolerated`, `cleanPatterns`, `rateLimitPatterns` | `invoke`, `command`, `requiresPr`                                              |
| `local-command`  | `invoke`, `command` | `requiresPr`                                                       | `botLogin`, `trigger`, `markerTolerated`, `cleanPatterns`, `rateLimitPatterns` |

`displayName`, `severityLevels`, `expectedLatency` and `status` belong to both. The separation is
enforced by the schema rather than left to the reader, because a field the other kind's loop never
reads is a setting that appears to work and does nothing.

| Key          | Meaning                                                                                                                                                |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `invoke`     | `subprocess` runs `command` as a shell command line and reads its stdout; `skill` invokes it in this session                                           |
| `command`    | The skill name, or the command line. Shown in the step-1 table before it runs and never pre-approved, exactly as `verify` is                           |
| `requiresPr` | True when the command resolves an open pull request itself. The local loop cannot check, so step 1 asks and step 7 refuses to call zero findings clean |

**Prefer `subprocess`.** The reviewer's file reads land in its own context rather than the loop's, and
it does not read the reasoning that produced the code under review. Some commands accept nothing else,
because a host may forbid a command from being started by the model rather than by a person.

**There is no `effort` key.** Whatever argument the review command takes for its depth belongs inside
`command`, which is the string the step-1 table shows you and the string the permission system
matches.

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
