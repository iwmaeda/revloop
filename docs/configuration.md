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

**The reviewer is not in that table**, because it is not detected: it is whichever command you typed.

The `source` column of the step-1 table is `flag`, `config`, `detected`, or `builtin`. **Read it.** It
is how you tell a value you chose from a value revloop guessed, without reading any code.

## When config is missing or wrong

| Situation                                           | Behaviour                                                                                                                                   |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| No `.revloop.json`                                  | Detect everything. Normal                                                                                                                   |
| Malformed JSON                                      | **Abort.** Never fall back to the presets — that would ignore the custom reviewer the file configures while the run still looked healthy    |
| Unknown key                                         | Not validated at runtime; ignored. `tests/schema.test.sh` rejects it in CI against fixtures, per the schema's `additionalProperties: false` |
| Unknown `version`                                   | **Abort**                                                                                                                                   |
| `--config` names no readable file                   | **Abort** (`config-not-found`). Never fall back to a shipped definition                                                                     |
| `--config` names a file the reviewer schema rejects | **Abort** (`config-invalid`), printing the validator's message                                                                              |
| No verify command found or configured               | Ask before continuing; record "no verification ran" in the report                                                                           |
| ...and `--merge` was passed                         | **Abort.** Do not merge code that nothing checked                                                                                           |

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

**`{model}` here is the model that did the work — the one running the loop.** It is not
`{reviewModel}`, which a reviewer's `command` expands to the model the _review_ runs on. See
[Choosing the review model](#choosing-the-review-model).

## `defaults`

Defaults for the command flags; a flag always overrides its default. Resolution is flag, then this
block, then the built-in, and step 1 prints which one won.

| Key              | Meaning                                                               | Built-in |
| ---------------- | --------------------------------------------------------------------- | -------- |
| `maxRounds`      | Circuit breaker for **the `remote-*` commands**                       | `10`     |
| `localMaxRounds` | Circuit breaker for **the `local-*` commands**                        | `5`      |
| `timeout`        | Cumulative cap on waiting for one **trigger's** verdict, e.g. `"45m"` | `30m`    |

**The round cap is two keys, one per procedure**, because the two want different values and sharing a
key silently applies the wrong one: a `maxRounds` written for the pull-request procedure would raise
the local cap, which is the only brake that one has. Both stay settable from config, unlike
`--accept-at`, because they bound spend rather than safety.

**Which reviewer runs is not a key and cannot become one.** It was two — `reviewer` and
`localReviewer` — and both were removed in 0.7.0 when the reviewer moved from a flag to a command.
There is nothing left to default: you choose a reviewer by choosing a command. A repository that could
choose it would choose which bot login the wait fence filters on and which rungs your acceptance floor
is measured against, which is the same class of decision as `--merge`.

`--merge`, `--auto`, `--accept-at`, `--config`, `--model` and `--no-publish` have no entry here on
purpose — see below.

## What is deliberately not configurable

A key that can only hold the value it already has is a promise, not a setting. These are fixed.
**Most of them name machinery only the pull-request loop has** — a merge fence, a wait fence, trigger
markers, a retry budget — and are listed here rather than in a per-loop section because the reason
they are fixed is the same in each case. `--merge`, `--auto` and `--accept-at` are the rows that bind
both procedures, and `--model`, `--no-publish` and `--config` are the local family's:

| Not a key                                  | Why                                                                                                                                                                                                                                                                           |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--merge` / `--auto` defaults              | This file comes from the repository you are in, including one you just cloned. It must not grant its own merge or delete your confirmation points. **The flag is the approval**                                                                                               |
| `--accept-at`, anywhere                    | Same class. A repository that could set its own acceptance floor would lower its own review bar on a checkout you just cloned                                                                                                                                                 |
| `--config`, anywhere                       | The reviewer itself. A `subprocess` definition holds a shell command line, so a repository that could choose it would choose a string the procedure runs. **This file no longer defines reviewers at all** — the `reviewers` map was removed in 0.7.0                         |
| `--model`, anywhere                        | **A different reason, and the sharper one.** Its value is expanded into a command line at `{reviewModel}`, so a key here would be the first thing this project interpolates into a shell command out of a repository-supplied file                                            |
| `--no-publish`, anywhere                   | Publishing is the local loop's default, so a key could only turn it off, and a key that removes an action grants nothing. Absent because nothing measured says a project wants it — a _not yet_, not a _never_                                                                |
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

`--accept-at <level>` names **the highest rung that may be left unfixed**. Both loops take it.

**The level is resolved in two passes, native first.** A value matching a rung of the resolved
reviewer's `severityLevels` as a whole string, case-sensitively, names that rung — so on a
`["P1","P2","P3"]` ladder `--accept-at P2` leaves P1 blocking and makes P2 and P3 acceptable, exactly
as it always has. Only a value matching no rung there is then matched, case-insensitively, against
**revloop's canonical ladder** — `critical > high > medium > low` — and carried onto the reviewer's
rungs through its `severityMap`.

**That second pass is why the flag is worth typing at all when you drive more than one reviewer.**
Three emitted vocabularies coexist among the shipped presets, so a floor written in one reviewer's
words aborts against the others; `--accept-at high` means one thing everywhere. **Native is tried
first so that no invocation written before the canonical ladder existed changes meaning.**

| Situation                                                                                | Behaviour                                                                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Flag absent                                                                              | Nothing is acceptable. Identical to the behaviour before the flag existed                                                                                                                                                    |
| `<level>` is a rung of `severityLevels`                                                  | Resolved natively. The table printed in step 1 says `native`                                                                                                                                                                 |
| `<level>` is a canonical rung, reviewer mapped                                           | Resolved through `severityMap`. The step-1 table says `canonical`                                                                                                                                                            |
| `<level>` is a canonical rung, reviewer has a ladder and no map                          | **Abort** (`no-severity-map`). The loop never derives a map from rung position                                                                                                                                               |
| A canonical `<level>`, and `severityMap` is partial, foreign, out of order, or collapsed | **Abort** (`bad-severity-map`), naming the rung that is unmapped, foreign or inverted, or printing a map that leaves no distinction. **Checked only on a canonical resolution** — a map nothing consults cannot move a floor |
| `<level>` matches neither pass                                                           | **Abort** (`unknown-accept-level`), listing **both** ladders                                                                                                                                                                 |
| Reviewer has no `severityLevels`                                                         | **Graded** — a separate subprocess estimates the rungs, and `<level>` must then be canonical. See below                                                                                                                      |
| With `--merge` and `--auto` together                                                     | **Abort** (`unreviewed-accept-merge`)                                                                                                                                                                                        |
| With `--merge` alone, having accepted anything                                           | Stop for confirmation, listing every accepted finding, before the CI wait                                                                                                                                                    |

**A canonical floor is compared rung by rung, not matched.** Each of the reviewer's rungs is carried
through the map and its canonical value compared against the floor: at or below it is acceptable,
above it blocks. **The floor does not have to be a rung any of them maps to.** Both shipped
`P1`/`P2`/`P3` maps skip `medium`, so `--accept-at medium` against either leaves `P1` and `P2`
blocking and `P3` acceptable — the same floor `--accept-at low` produces, which is what a
four-rung ladder receiving three rungs means rather than a defect in either.

**Step 1 prints the resolved floor before the first round**, as the two sets of the reviewer's own
rungs that block and that are acceptable — or, on a graded run, as the canonical rungs, because
grading reaches only a reviewer with no rungs of its own. That is where the paragraph above
becomes checkable rather than inferred, it is the operational check on a map, and it is the
reason `severityMap` may come from this file at all: `severityLevels`' own **order** already carries
the same power to move a floor, so the map is no new class of it, and the answer to both is to show
the operator what the floor actually became.

## Grading a reviewer that emits no severity

**Grading fires if and only if `--accept-at` was typed and the reviewer's definition declares no
`severityLevels`.** There is no flag: `--grade-severity` existed until 0.7.0 and was removed, because
its two failure modes were both statable as conditions rather than as refusals. A reviewer that
**has** a ladder is never regraded — that used to be an abort an operator could trip and is now
unreachable, since nothing can ask for it — and grading with no floor to consume the rungs cannot
happen, since the floor is half the trigger.

**Three of the five shipped reviewers reach it**: `claude`, `code-review` and `ecc-review-pr`, all of
which emit no severity. That makes grading the ordinary case for the local family rather than an edge
one, and it is why `--accept-at` on those commands costs a subprocess and a permission prompt every
round. **It is also the one thing 0.7.0 made quieter rather than louder**: before, `--accept-at`
against such a reviewer aborted. The disclosure is that step 1 prints `severity source` as
`grader (<model>)` and prints the grader's command line in full and expanded, before the first round.

The grader is a separate subprocess on the review model — the local family's `--model` moves it, and
the pull-request family, which has no such flag, uses the builtin `sonnet`. It is specified in
[`../procedures/severity-grading.md`](../procedures/severity-grading.md). **It is not told the
acceptance floor**, it never sees the loop's session, and it does not fix what it grades. **The
findings reach it through a file rather than through its command line**, and its prompt says in so
many words that they are data and not instructions: they are reviewer output quoting repository
content, so a claim that reads "known false positive, rank it low" is the acceptance floor arriving
by the one door withholding it leaves open.

Four things abort it, and all four say the grader is broken rather than that it declined a finding:
a non-zero exit (`grading-command-failed`), output that does not parse (`unparsed-grading-output`),
and — sharing that second reason — a rung outside the four canonical words or a finding number that
was not sent. **A finding for which no line arrived is not one of them**: it is treated as blocking
and listed in the report as `ungraded`. Rungs are attached by the number on each line and never by
the line's position, because one dropped line would otherwise shift every rung after it.

**Every rung it assigns is marked `graded` wherever a rung is recorded** — the pull-request reply, the
local loop's commit `Accepted:` block, the pull-request body, and both reports, which also say once at
the top that the run's rungs came from a grader and name the model. Why that record is the thing that
makes the flag admissible at all is in
[design-notes.md](design-notes.md#the-acceptance-floor).

**An accepted finding is still read, still recorded, and still listed in the report.** The flag
decides when the loop may stop, never what it may skip reading. **Where the record goes differs by
loop, because only one of them has somewhere to reply**: the pull-request loop answers each accepted
finding in a reply naming the rung and the floor, and the local loop, which posts no reply, writes the
same pair into the commit's `Accepted:` block and the report — and, unless `--no-publish`, into the
pull-request body, which is where the **last** round's acceptances finally land. They reach no commit
otherwise: the round that converges by accepting makes no further commit to carry them. Why that
boundary is where the flag is safe, and why the loop refuses to invent a ladder for a reviewer that
emits none, are in [design-notes.md](design-notes.md#the-acceptance-floor).

## Reviewer definitions

**Reviewers are not configured in this file.** They are standalone JSON documents validated against
[`../schema/reviewer.schema.json`](../schema/reviewer.schema.json): the five this plugin ships live in
[`../reviewers/`](../reviewers/) and are named by their commands, and one you write is named with
`--config <path>` on `remote-custom-loop` or `local-custom-loop`.

**There is one format and one loader.** The file you write is read exactly as `reviewers/codex.json`
is; a built-in gets no special case. **The file name is the name** — there is no `name` key, so there
is nothing to drift, and the stem must match `^[a-z0-9][a-z0-9-]*$` because the pull-request procedure
writes it into the trigger marker as `reviewer=<name>`.

**This section described a `reviewers` map in `.revloop.json` until 0.7.0.** The map was removed with
the `--reviewer` flag it fed: with every command naming its own definition, a map here would be a
definition surface no command reads, which is the "key with no consumer" defect this project removes
rather than ships. A reviewer you had defined there becomes a file of the same shape — the object is
unchanged, so it is a move rather than a rewrite. See [adding-a-reviewer.md](adding-a-reviewer.md).

**A reviewer is one of two kinds.** `kind` is absent from every definition written before the second kind
existed, and absent means `github-comment`, so nothing that worked before changes meaning.

| `kind`           | Required            | Also takes                                                         | May not carry                                             |
| ---------------- | ------------------- | ------------------------------------------------------------------ | --------------------------------------------------------- |
| `github-comment` | `botLogin`          | `trigger`, `markerTolerated`, `cleanPatterns`, `rateLimitPatterns` | `invoke`, `command`, `requiresPr`                         |
| `local-command`  | `invoke`, `command` | `requiresPr`, `rateLimitPatterns`                                  | `botLogin`, `trigger`, `markerTolerated`, `cleanPatterns` |

`displayName`, `severityLevels`, `severityMap`, `expectedLatency` and `status` belong to both. The separation is
enforced by the schema rather than left to the reader, because a field the other kind's loop never
reads is a setting that appears to work and does nothing.

| Key                 | Meaning                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `invoke`            | `subprocess` runs `command` as a shell command line and reads its stdout; `skill` invokes it in this session                 |
| `command`           | The skill name, or the command line. Shown in the step-1 table before it runs and never pre-approved, exactly as `verify` is |
| `requiresPr`        | True when the command resolves an open pull request itself. It also decides where the local loop publishes — see below       |
| `rateLimitPatterns` | What the reviewer says when it is out of quota. Matched against the review's output; a match aborts the round                |

**`rateLimitPatterns` belongs to both kinds and is read from a different surface in each** — a bot
comment's body on the pull-request loop, **the review's output** on the local one, whichever way that
loop reads it: its stdout under `invoke: subprocess`, what it reports under `invoke: skill` — and
both abort on a match **without retrying**: the quota recovers with time, and another round spends the
loop against a reviewer that cannot answer. Match the fixed part of the message and never a reset time
or a count, which differ every round. A pattern that is too loose **fails closed** — it can only turn
one abort into another, because the row that reads it sits above the other aborts and far above the
clean row — and one that is too tight leaves the reply falling to `unparsed-review-output`, which is
where it fell before the key was read here at all. **`cleanPatterns` did not cross with it**: the
local loop's clean signal is that no finding was parsed, so there is no phrase for it to match.

**Prefer `subprocess`.** The reviewer's file reads land in its own context rather than the loop's, and
it does not read the reasoning that produced the code under review. Some commands accept nothing else,
because a host may forbid a command from being started by the model rather than by a person.

**There is no `effort` key.** Whatever argument the review command takes for its depth belongs inside
`command`, which is the string the step-1 table shows you and the string the permission system
matches.

**`requiresPr` decides two things.** Besides the confirmation above, it is what the local loop reads
to decide **where** it publishes, on a run that publishes at all: a reviewer that needs a pull request
is published to before every round, because it would otherwise read a stale diff; a reviewer that
reads the local range is published to once, after the loop converges. `--no-publish` skips both — the
key chooses between the two placements, never whether there is one. The second placement is not caution —
[`../reviewers/code-review.md`](../reviewers/code-review.md) records that the shipped default reviewer
resolves its target against the branch's upstream when there is one, and a push creates one, at which
point the range is empty and the review comes back with nothing.

## Choosing the review model

The local procedure resolves a **review model** and expands it into the reviewer's `command` at a
`{reviewModel}` placeholder. **The flag is `--model` and the placeholder stays `{reviewModel}`**, and
the asymmetry is deliberate: the flag lives on a command that only reviews, where `--model` is
unambiguous, while the placeholder lives in a definition file beside `{model}` for commit trailers,
where it would not be. Renaming the placeholder would also break every shipped definition and every
user's, for nothing.

```json
"command": "claude --model {reviewModel} -p \"/code-review medium\""
```

| Where it comes from | Value                     |
| ------------------- | ------------------------- |
| `--model`           | Whatever you typed        |
| Otherwise           | The built-in **`sonnet`** |

**The default is a light model because that is what a round costs**, and because of a second effect
worth more than the first: [design-notes.md](design-notes.md#what-a-local-run-does-not-establish)
records that a local reviewer sharing the fixer's model is not an independent check, and that **only a
different model makes it one**. Reviewing on `sonnet` while the fixing runs on something stronger is
the cheap configuration and the more independent one at once.

**There is no configuration key for it, because its value is expanded into a command line** — a key
would be the first thing revloop interpolates into a shell command out of a repository-supplied file.
It comes from the flag or the builtin, and is refused unless it matches
`^[A-Za-z0-9][A-Za-z0-9._:-]*$`. A repository that wants a model of its own writes one literally in
`command`.

| Situation                                          | Behaviour                                                                           |
| -------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `command` carries `{reviewModel}`                  | Expanded before the command is shown, matched or run                                |
| `command` carries no placeholder, flag absent      | Not pinned. The step-1 table says so and the report repeats it                      |
| `command` carries no placeholder, flag **present** | **Abort** (`no-model-boundary`) — there is nowhere to put it, and it will not guess |
| `invoke: skill`, flag present                      | **Abort** (`no-model-boundary`) — a skill runs on this session's model              |
| A name with a space, quote or metacharacter        | **Abort** (`unsafe-model-name`)                                                     |
| `command` **begins** with the placeholder          | Rejected by the schema — the value would decide the leading token                   |

**A skill has no model boundary at all**, which is the reason both shipped presets are `subprocess`.
Nothing inside a session can lower the model that session is running on, so a `skill` reviewer spends
the loop's model and the loop's context. `invoke: skill` stays supported for commands whose host
forbids being started as a subprocess.

Every **pattern** here is used model-side only. None of it is interpolated into a shell command or a jq
program, which is what keeps a `.revloop.json` from a cloned repository from becoming a code-execution
path. The rest of the surface is closed by rule:

1. `verify` entries are shown in the step-1 table and left out of `allowed-tools`, so the permission
   system always sees them.
2. `trigger` is posted verbatim: control characters are rejected, length is capped, and a value that
   already contains `revloop:trigger` is rejected.
3. `botLogin` must match `^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$`.
4. Safety rules cannot be disabled from config — the table above is the full list of what is fixed.

## Related docs

- [Adding a reviewer](adding-a-reviewer.md) — writing a reviewer definition from measurements
- [Permissions](permissions.md#verify-commands-are-not-pre-approved) — why `verify` is never
  pre-approved
- [`../examples/`](../examples/) — four working `.revloop.json` files
