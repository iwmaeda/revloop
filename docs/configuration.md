# Configuration

Every field is optional. With no file, revloop detects what it needs, and step 1 prints each value
with its source. The [schema](../schema/revloop.schema.json) is machine-readable, and the
[examples](../examples/) are a quick start.

```json
{
  "$schema": "https://raw.githubusercontent.com/iwmaeda/revloop/main/schema/revloop.schema.json",
  "version": 1,
  "project": {
    "verify": ["npm run check:all", "npm test"],
    "verifyNotes": "check:all does not run the tests; CI splits them into two jobs"
  },
  "defaults": { "maxRounds": 12 }
}
```

`$schema` enables editor completion. `version` is `1`; an unknown version aborts.

## Where the file lives

| File                   | Whose                   | In git                                                       |
| ---------------------- | ----------------------- | ------------------------------------------------------------ |
| `.revloop.json`        | The team's              | Committed                                                    |
| `.revloop/config.json` | Yours, in this checkout | Ignored by `.revloop/.gitignore`, which the first run writes |

Exactly one file is read. When `.revloop/config.json` exists, `.revloop.json` is not read and nothing
is merged from it. Step 1 prints a `config:` line naming the file it read.

`.revloop/config.json` must be tracked or ignored by git; otherwise the run aborts with
`config-not-ignored`. To create the ignore file before the first run:

```console
mkdir -p .revloop && printf '*\n' > .revloop/.gitignore
```

Both files follow the same schema and the same rules. A reviewer definition only you use can live in
`.revloop/` too, passed with `--config`.

## What is detected

| Value            | Detected from                                                                     |
| ---------------- | --------------------------------------------------------------------------------- |
| `baseBranch`     | `gh repo view --json defaultBranchRef`                                            |
| `verify`         | Build files: `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod` |
| `branchPrefixes` | The prefixes used in the repository's commit subjects                             |
| `commit.*`       | The last 20 commits: style, language, existing trailers                           |

The `source` column of the step 1 table is `flag`, `config`, `detected`, `rigor` or `builtin`.
`rigor` marks a round cap supplied by [the rigor level](#the-rigor-level).

## When configuration is missing or wrong

| Situation                                           | Behaviour                                                    |
| --------------------------------------------------- | ------------------------------------------------------------ |
| Neither file                                        | Detect everything                                            |
| Both files                                          | Read `.revloop/config.json` only                             |
| `.revloop/config.json` untracked and not ignored    | Abort (`config-not-ignored`)                                 |
| `.revloop.json` untracked                           | Read it. Step 1 suggests moving it to `.revloop/config.json` |
| Malformed JSON, or an unknown `version`             | Abort                                                        |
| Unknown key                                         | Ignored at runtime                                           |
| `--config` names no readable file                   | Abort (`config-not-found`)                                   |
| `--config` names a file the reviewer schema rejects | Abort (`config-invalid`)                                     |
| No verify command found or configured               | Ask before continuing. With `--merge`, abort                 |

## `project`

| Key                | Meaning                                                    |
| ------------------ | ---------------------------------------------------------- |
| `baseBranch`       | Pull-request base. `null` means detect                     |
| `verify`           | Commands run before pushing. Write them as CI invokes them |
| `verifyNotes`      | What CI runs that `verify` does not                        |
| `branchPrefixes`   | Allowed topic-branch prefixes                              |
| `pr.titleLanguage` | Language for the pull-request title                        |

An umbrella check command often does not cover everything CI runs. Name the gap in `verifyNotes` so
the loop closes it before pushing; a red CI costs a review round.

### `project.commit`

| Key               | Meaning                                                             |
| ----------------- | ------------------------------------------------------------------- |
| `style`           | Commit-subject convention, e.g. `conventional`                      |
| `subjectLanguage` | Language for the subject line                                       |
| `bodyLanguage`    | Language for the body                                               |
| `scopes`          | Allowed scopes, e.g. `["api", "web", "infra"]`                      |
| `verifiedLabel`   | Label introducing the list of commands that ran, e.g. `"Verified:"` |
| `trailers`        | Trailers to append. `{model}` expands to the running model's name   |
| `onePerRound`     | One commit per round instead of a split                             |

`{model}` is the model running the loop. The model that reviews is `{reviewModel}`; see
[Choosing the review model](#choosing-the-review-model).

## `defaults`

A flag overrides its default. The order is the flag, then this block, then the built-in.

| Key              | Meaning                                                | Built-in             |
| ---------------- | ------------------------------------------------------ | -------------------- |
| `maxRounds`      | Round cap for the `remote-*` commands                  | From the rigor level |
| `localMaxRounds` | Round cap for the `local-*` commands                   | From the rigor level |
| `timeout`        | Cap on waiting for one trigger's verdict, e.g. `"45m"` | `30m`                |

A round that re-posts its trigger can wait up to twice `timeout`.

## What is deliberately not configurable

`--merge`, `--auto`, `--rigor`, `--config`, `--model` and `--no-publish` are flags only. This file
comes from the repository you are working in, including one you just cloned, so it cannot turn on
merging, remove a confirmation, lower the review bar or choose the reviewer. The reviewer is chosen by
the command you type.

Also fixed: the merge method (a merge commit), the CI check before a merge, which endpoints the wait
reads, the interim-comment patterns inside the wait fence, the round number (counted from the trigger
markers on the pull request) and the retry budget (one re-post per round).

## The rigor level

`--rigor <level>` sets how strictly a run must finish. The default is `standard`. The full
specification is [`procedures/rigor-levels.md`](../procedures/rigor-levels.md).

| Level                    | Blocking           | Acceptable       | Round cap (remote / local) |
| ------------------------ | ------------------ | ---------------- | -------------------------- |
| `minimal`                | `critical`         | `high` and below | 3 / 2                      |
| `standard` **(default)** | `critical`, `high` | `medium`, `low`  | 5 / 3                      |
| `thorough`               | every finding      | none             | 10 / 5                     |
| `exhaustive`             | every finding      | none             | 15 / 8                     |

Severity is measured on one ladder, `critical > high > medium > low`. A reviewer's own rungs are
mapped onto it by `severityMap`, which is required whenever `severityLevels` is present. Step 1 prints
which of the reviewer's rungs block and which are acceptable before the first round.

| Situation                                                         | Behaviour                                                           |
| ----------------------------------------------------------------- | ------------------------------------------------------------------- |
| `<level>` is not one of the four                                  | Abort (`unknown-rigor-level`)                                       |
| `severityMap` is partial, out of order, or maps every rung to one | Abort (`bad-severity-map`), at `minimal` and `standard` only        |
| No `severityLevels`, at `minimal` or `standard`                   | Findings are graded; see below                                      |
| No `severityLevels`, at `thorough` or `exhaustive`                | Nothing is graded                                                   |
| `minimal` or `standard` with `--merge --auto`                     | Abort (`unreviewed-accept-merge`)                                   |
| `minimal` or `standard` with `--merge`, after accepting a finding | Stop for confirmation before the CI wait, listing what was accepted |

The level also sets:

- the round cap, when neither `--max-rounds` nor a `defaults` key supplies one;
- the sweeps a round owes after a fix: `minimal` names the class and checks for findings already
  fixed, `standard` adds the corpus sweep, `thorough` runs every sweep that applies, and `exhaustive`
  also enumerates the input space;
- the sufficiency test: before finishing, the run records whether the change is sufficiently reviewed
  for the level, as a `Sufficiency:` block in the report and in the pull-request body.

An accepted finding is still read, answered and listed in the report. The level decides when the loop
may stop, never what it reads.

## Grading a reviewer that emits no severity

When the level is `minimal` or `standard` and the reviewer declares no `severityLevels`, a separate
subprocess estimates each finding's rung. Among the built-ins this applies to `claude`, `code-review`
and `ecc-review-pr`. It costs one more permission prompt per round; `--rigor thorough` avoids it.

- The grader runs on the review model: on the local commands the value of `--model`, or `sonnet`
  when it is omitted; on the remote commands always `sonnet`.
- It is not told the acceptance floor, does not see the loop's session, and fixes nothing.
- Step 1 prints `severity source` as `grader (<model>)`, and the grader's full command.
- Every rung it assigns is marked `graded` in replies, commits and reports.
- A finding it returns no rung for is treated as blocking and listed as `ungraded`.
- The run aborts when the grader fails (`grading-command-failed`) or its output cannot be parsed
  (`unparsed-grading-output`).

The specification is [`procedures/severity-grading.md`](../procedures/severity-grading.md).

## Reviewer definitions

Reviewers are not configured in this file. Each is a JSON document validated against
[`schema/reviewer.schema.json`](../schema/reviewer.schema.json). The five built-ins are in
[`reviewers/`](../reviewers/); pass your own with `--config <path>` on `remote-custom-loop` or
`local-custom-loop`. The file name is the reviewer's name and must match `^[a-z0-9][a-z0-9-]*$`.

| `kind`                     | Required            | Also takes                                                         |
| -------------------------- | ------------------- | ------------------------------------------------------------------ |
| `github-comment` (default) | `botLogin`          | `trigger`, `markerTolerated`, `cleanPatterns`, `rateLimitPatterns` |
| `local-command`            | `invoke`, `command` | `requiresPr`, `rateLimitPatterns`                                  |

Both kinds take `displayName`, `severityLevels`, `severityMap`, `expectedLatency` and `status`. A key
that belongs to the other kind is rejected.

| Key                 | Meaning                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| `invoke`            | `subprocess` runs `command` in a shell and reads its stdout. `skill` invokes it in this session |
| `command`           | The command line, or the skill name. Printed in step 1 and never pre-approved                   |
| `requiresPr`        | True when the command reads an open pull request                                                |
| `rateLimitPatterns` | What the reviewer says when it is out of quota. A match aborts the round                        |

- Prefer `subprocess`. The reviewer then runs in its own context, and it is the only way to choose
  its model.
- With `requiresPr: true` the local loop publishes before every round. Otherwise it publishes once,
  after convergence.
- There is no `effort` key. Put any depth argument inside `command`.
- In `rateLimitPatterns`, match the fixed part of the message, never a reset time or a count.

To write one, see [Adding a reviewer](adding-a-reviewer.md).

## Choosing the review model

The local commands expand `{reviewModel}` in a reviewer's `command`:

```json
"command": "claude --model {reviewModel} -p \"/code-review medium\""
```

The placeholder expands to the value of `--model` if you typed it, and to `sonnet` otherwise. The
command spells its own flag. There is no configuration key for it.
A repository that wants a fixed model writes it literally in `command`.

| Situation                                         | Behaviour                                                        |
| ------------------------------------------------- | ---------------------------------------------------------------- |
| `command` has the placeholder                     | Expanded before the command is shown or run                      |
| No placeholder, no `--model`                      | The model is not pinned, and step 1 says so                      |
| No placeholder, `--model` given                   | Abort (`no-model-boundary`)                                      |
| `invoke: skill`, `--model` given                  | Abort (`no-model-boundary`): a skill runs on the session's model |
| A name with a space, quote or shell metacharacter | Abort (`unsafe-model-name`)                                      |
| `command` begins with the placeholder             | Rejected by the schema                                           |

Reviewing on a different model from the one doing the fixing also makes the review more independent;
see [design notes](design-notes.md#what-a-local-run-does-not-establish).
