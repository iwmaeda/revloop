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
  "defaults": { "maxRounds": 12 }
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

The `source` column of the step-1 table is `flag`, `config`, `detected`, `rigor`, or `builtin`.
**Read it.** It is how you tell a value you chose from a value revloop guessed, without reading any
code. **`rigor` is the fifth, and it is not `builtin` under another name**: it marks a round cap
[the rigor level](#the-rigor-level) supplied, which moves with the level you typed, where `builtin`
marks a number that does not. Printing the level's number as `builtin` would read as "this is the
same whatever you typed", which is the one thing it is not.

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
`--rigor`, because they bound spend rather than safety.

**The built-ins above are `thorough`'s, and the default level is `standard`**, whose numbers are 5
and 3 — so a run that types no level and configures no cap is capped **lower** than the table above
says. `--rigor` supplies a different number at every level; see
[the rigor level](#the-rigor-level). **A key here beats it**, so a repository that
configured a cap keeps the cap it configured; the level answers only where neither the flag nor the
key did, and step 1 prints `source=rigor` when it does.

**Which reviewer runs is not a key and cannot become one.** It was two — `reviewer` and
`localReviewer` — and both were removed in 0.7.0 when the reviewer moved from a flag to a command.
There is nothing left to default: you choose a reviewer by choosing a command. A repository that could
choose it would choose which bot login the wait fence filters on and which rungs your acceptance floor
is measured against, which is the same class of decision as `--merge`.

`--merge`, `--auto`, `--rigor`, `--config`, `--model` and `--no-publish` have no entry here on
purpose — see below.

## What is deliberately not configurable

A key that can only hold the value it already has is a promise, not a setting. These are fixed.
**Most of them name machinery only the pull-request loop has** — a merge fence, a wait fence, trigger
markers, a retry budget — and are listed here rather than in a per-loop section because the reason
they are fixed is the same in each case. `--merge`, `--auto` and `--rigor` are the rows that bind
both procedures, and `--model`, `--no-publish` and `--config` are the local family's:

| Not a key                                  | Why                                                                                                                                                                                                                                                                           |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--merge` / `--auto` defaults              | This file comes from the repository you are in, including one you just cloned. It must not grant its own merge or delete your confirmation points. **The flag is the approval**                                                                                               |
| `--rigor`, anywhere                        | Same class. A repository that could set its own review standard would lower its own bar on a checkout you just cloned. **A key holding only the two strict levels is worse, not safer**: it grants nothing, so it is a promise rather than a setting                          |
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

## The rigor level

`--rigor <level>` names **how strictly this run must finish**, and it is the argument that decides
when the loop may stop. Both loops take it. **The default is `standard`**, under which `critical` and
`high` block and `medium` and `low` may be left unfixed. **That is not the behaviour that existed
before the flag** — every earlier release fixed or declined everything unless an acceptance argument
was typed, and `--rigor thorough` is what gets that back. The full specification is
[`../procedures/rigor-levels.md`](../procedures/rigor-levels.md); this page is the operator's summary.

| Level                    | Blocking — never acceptable | Acceptable band  | Round cap (remote / local) |
| ------------------------ | --------------------------- | ---------------- | -------------------------- |
| `minimal`                | `critical`                  | `high` and below | 3 / 2                      |
| `standard` **(default)** | `critical`, `high`          | `medium`, `low`  | 5 / 3                      |
| `thorough`               | every finding               | none             | 10 / 5                     |
| `exhaustive`             | every finding               | none             | 15 / 8                     |

**Four things follow from the default having a band**, and each lands on a run that typed nothing: a
grader runs every round against a reviewer with no rungs; `severityMap` is read on every run against
one that has them, so `bad-severity-map` is reachable untyped; the round cap is `standard`'s rather
than the number either loop carried as a builtin; and **`--merge --auto` aborts**, because the gate
below rests on a person reading an accepted list the default now produces.

**A level is never a rung name**, which is the whole of what four fixed words buy. An argument that
named a rung had to be resolved against a vocabulary, so it meant one thing against a reviewer with a
`P1`/`P2`/`P3` ladder and missed entirely against one without — three emitted vocabularies coexist
among the shipped presets, so such an argument read as broken rather than as reviewer-specific. A
value that is not one of the four is `unknown-rigor-level`, and that abort prints four words rather
than two ladders.

**The floor is measured on revloop's canonical ladder** — `critical > high > medium > low` — and a
reviewer's own rungs reach it through its `severityMap`, which is **required whenever
`severityLevels` is present**.

| Situation                                                              | Behaviour                                                                                                                                                                                                                 |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Flag absent                                                            | `standard`. `critical` and `high` block; `medium` and `low` are acceptable. A rung is consulted on every run, so a grader starts against a reviewer with none                                                             |
| `<level>` is not one of the four                                       | **Abort** (`unknown-rigor-level`), listing them                                                                                                                                                                           |
| Reviewer has `severityLevels`                                          | Its rungs are carried onto the canonical ladder by `severityMap` and compared against the floor                                                                                                                           |
| Reviewer has `severityLevels` and no `severityMap`                     | **Rejected by the schema**, before either procedure loads the file. This was a runtime abort (`no-severity-map`) until the two keys became a required pair                                                                |
| `severityMap` is partial, foreign, out of order, or collapsed          | **Abort** (`bad-severity-map`), naming the rung that is unmapped, foreign or inverted, or printing a map that leaves no distinction. **Checked only at a level with a band** — a map nothing consults cannot move a floor |
| Reviewer has no `severityLevels`, at `minimal` or `standard`           | **Graded** — a separate subprocess estimates the rungs. See below                                                                                                                                                         |
| Reviewer has no `severityLevels`, at `thorough` or `exhaustive`        | Nothing is graded and nothing is consulted. `severity source` reads `not consulted`. **Not reachable without typing a level**                                                                                             |
| `minimal` or `standard` with `--merge` and `--auto` together           | **Abort** (`unreviewed-accept-merge`). **Reached by `--merge --auto` alone**, since `standard` is the default                                                                                                             |
| `minimal` or `standard` with `--merge` alone, having accepted anything | Stop for confirmation, listing every accepted finding, before the CI wait                                                                                                                                                 |

**A floor is compared rung by rung, not matched.** Each of the reviewer's rungs is carried
through the map and its canonical value compared against the floor: at or below it is acceptable,
above it blocks. **The floor does not have to be a rung any of them maps to.** Both shipped
`P1`/`P2`/`P3` maps skip `medium`, so `--rigor standard` against either leaves `P1` and `P2`
blocking and `P3` acceptable, which is what a four-rung ladder receiving three rungs means rather
than a defect in either.

**Step 1 prints the resolved floor before the first round**, as the two sets of the reviewer's own
rungs that block and that are acceptable — or, on a graded run, as the canonical rungs, because
grading reaches only a reviewer with no rungs of its own, and at a strict level as the single line
that says nothing is acceptable. That is where the paragraph above
becomes checkable rather than inferred, it is the operational check on a map, and it is the
reason `severityMap` may come from this file at all: `severityLevels`' own **order** already carries
the same power to move a floor, so the map is no new class of it, and the answer to both is to show
the operator what the floor actually became.

### What else the level moves

**The round cap**, where nothing else supplied one. The precedence is `--max-rounds`, then
`defaults.maxRounds` / `defaults.localMaxRounds`, then the level — so a repository that configured a
cap keeps it, and the level replaces what used to print as `builtin`.

**The sweeps a round owes after a fix.** The taxonomy is the procedures'; the level says which of it
is required. `minimal` owes the class name and the already-fixed check — the one sweep that saves
rounds rather than spending them. `standard` adds the corpus sweep. `thorough` requires every sweep
that applies, which is what the procedures required before levels existed. `exhaustive` promotes the
definition sweep and a closed input-space enumeration from "when it applies" to "always".

**The sufficiency test.** At every edge into the report step, the run answers in writing whether the
change is sufficiently reviewed for this level — reading the latest review's rungs, the run's own
record of buckets and rungs, and which sweeps were run — and writes the answer into the report, and
into the pull-request body on a publishing run, as a `Sufficiency:` block.

**That test can only keep a run going and can never end one early**, which is what makes it safe for
the loop that has to do the fixing to run it. Every stop it permits is one the floor already
permitted. The rungs still come from the reviewer or from a grader; what the loop applies is a
standard it did not author, to rungs it did not author.

**The run's history reaches the decision through one rule**: a ceiling that has **risen inside the
acceptable band** since the previous round re-opens the acceptances under it. A level with a band
converges over findings that are real, unfixed and conceded, and a band is a range rather than a
point — three `low` findings accepted in one round and three `medium` ones in the next is a change
getting worse under a floor that never moved.

## Grading a reviewer that emits no severity

**Grading fires if and only if the resolved level has an acceptable band and the reviewer's
definition declares no `severityLevels`.** There is no flag: `--grade-severity` existed until 0.7.0
and was removed, because
its two failure modes were both statable as conditions rather than as refusals. A reviewer that
**has** a ladder is never regraded — that used to be an abort an operator could trip and is now
unreachable, since nothing can ask for it — and grading with no floor to consume the rungs cannot
happen, since the band is half the trigger.

**Three of the five shipped reviewers reach it**: `claude`, `code-review` and `ecc-review-pr`, all of
which emit no severity. That makes grading the ordinary shape of a **relaxed** run on the local
family rather than an edge one, and it is why `--rigor minimal` or `--rigor standard` on those
commands costs a subprocess and a permission prompt every round — **and `standard` is the default, so
that is the ordinary run rather than an opt-in.** `--rigor thorough` is what removes it, because
nothing is acceptable there and no rung is consumed. The disclosure is that step 1
prints `severity source` as
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
makes a relaxed level admissible at all is in
[design-notes.md](design-notes.md#the-rigor-level).

**An accepted finding is still read, still recorded, and still listed in the report.** The level
decides when the loop may stop, never what it may skip reading. **Where the record goes differs by
loop, because only one of them has somewhere to reply**: the pull-request loop answers each accepted
finding in a reply naming the rung and the level, and the local loop, which posts no reply, writes the
same pair into the commit's `Accepted:` block and the report — and, unless `--no-publish`, into the
pull-request body, which is where the **last** round's acceptances finally land. They reach no commit
otherwise: the round that converges by accepting makes no further commit to carry them. **The
`Sufficiency:` block sits beside them and has the same gap for the same reason.** Why that
boundary is where a relaxed level is safe, and why the loop refuses to invent a ladder for a reviewer
that emits none, are in [design-notes.md](design-notes.md#the-rigor-level).

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
