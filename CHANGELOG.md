# Changelog

All notable changes to this project are documented here.

**Fence changes are called out explicitly.** The shell fences in
[`procedures/remote-loop.md`](procedures/remote-loop.md) are matched by permission rules on their exact
text, so editing one costs every user a single re-approval. See
[`docs/permissions.md`](docs/permissions.md).

**Entries before 0.7.0 name `commands/remote-loop.md` and `commands/local-loop.md`.** Those files moved
to [`procedures/`](procedures/) in 0.7.0 and the historical names are left unlinked rather than
repointed, because an entry should say what was true when it was written.

## [Unreleased]

## [0.7.0] - 2026-09-04

**No fence changed, so there is no re-approval to give.** This release moves every file the fences
live in, splits two commands into seven, and deletes a flag — and the three shell fences are
byte-identical, still matching the hashes in `tests/fence-hashes.txt`. That is the whole point of
keeping runnable text in fences and pinning their bytes: a restructure this large costs nothing at the
permission prompt.

**This is a breaking release. Retype your invocation.** `/revloop:remote-loop` and
`/revloop:local-loop` are gone, with no deprecation window.

| Was                                            | Now                                           |
| ---------------------------------------------- | --------------------------------------------- |
| `/revloop:remote-loop`                         | `/revloop:remote-codex-loop`                  |
| `/revloop:remote-loop --reviewer gemini`       | `/revloop:remote-gemini-loop`                 |
| `/revloop:remote-loop --reviewer claude`       | `/revloop:remote-claude-loop`                 |
| `/revloop:remote-loop --reviewer <yours>`      | `/revloop:remote-custom-loop --config <path>` |
| `/revloop:local-loop --reviewer code-review`   | `/revloop:local-review-loop`                  |
| `/revloop:local-loop --reviewer ecc-review-pr` | `/revloop:local-ecc-loop`                     |
| `/revloop:local-loop --reviewer <yours>`       | `/revloop:local-custom-loop --config <path>`  |
| `--review-model <name>`                        | `--model <name>`                              |
| `--accept-at high --grade-severity`            | `--accept-at high`                            |

### The reviewer is a command, not a flag

**`--reviewer` is removed.** A flag that selects a reviewer is a flag that can select the wrong one,
and the reviewer is not a detail of the run: it decides which bot login the wait fence filters on,
which rungs an acceptance floor is measured against, whether a merge is available at all, and which
aborts are reachable. There is now one command per reviewer, and choosing the command is choosing the
reviewer.

**Seven commands, two procedures.** Every `remote-*` command runs
[`procedures/remote-loop.md`](procedures/remote-loop.md) and every `local-*` command runs
[`procedures/local-loop.md`](procedures/local-loop.md), byte for byte. The commands hold a flag table,
a reviewer definition and a pointer, and nothing else — `tests/commands.test.sh` refuses a bash fence,
a trigger marker, a spelled-out ladder or a stray tool grant in any of them. **Seven front doors, not
seven code paths**, which is the objection `docs/design-notes.md` had to answer before the split was
worth making.

**Reviewer-specific flags now appear only where they apply.** `--merge` and `--timeout` are on the
`remote-*` commands; `--model` and `--no-publish` on the `local-*` ones. Both were advertised to
everyone before, on commands where they did nothing.

**The procedures moved to `procedures/` and carry no frontmatter.** The host installs `commands/` and
never `procedures/`, so an `allowed-tools` line in a procedure would be a grant nobody receives —
`tests/fence-guards.test.sh` now refuses one. `$REVLOOP_PROCEDURE` and the Codex router keep their
names; the router resolves `procedures/remote-loop.md`.

### Reviewers are files

**Each shipped reviewer is now a definition plus a card**: `reviewers/<name>.json`, validated against
the new [`schema/reviewer.schema.json`](schema/reviewer.schema.json), beside the measurement card that
already existed. The definition object is unchanged — it is the one that used to sit in a fenced
` ```json ` block inside the card — so this is a move rather than a rewrite. **The file name is the
name**: there is no `name` key and nothing to drift, and the stem must be marker-safe because the
pull-request procedure writes it into the trigger marker.

**A reviewer you write is the same format, named with `--config <path>`.** One format, one loader, no
special case for a built-in. `examples/reviewer.custom.json` and `examples/reviewer.local.json` are
starting points.

**`.revloop.json` no longer defines reviewers.** The `reviewers` map and the `defaults.reviewer` and
`defaults.localReviewer` keys are removed: with every command naming its own definition, a map here
would be a definition surface no command reads. **Nothing breaks at runtime** — an unknown key in that
file is ignored — so a stale key costs an editor warning rather than a failed run. Move the reviewer
object into a file and point `--config` at it.

### Grading needs no flag

**`--grade-severity` is removed, and `--accept-at` now works against every reviewer.** When the
reviewer's definition declares no `severityLevels`, the rungs come from the grader that flag used to
start — specified now in [`procedures/severity-grading.md`](procedures/severity-grading.md), cited by
both procedures and owned by neither.

**Three aborts are gone with it**: `no-severity-ladder`, `grade-without-floor` and `grade-over-ladder`.
All three were conditions dressed as errors. Grading now fires **if and only if** `--accept-at` was
typed and the definition declares no ladder, so a reviewer that emits its own rungs cannot be regraded
because nothing can ask for it — **stronger than the refusal it replaces**, and it makes
`no-severity-map` and `bad-severity-map` unreachable on a graded run by construction rather than by
another refusal.

**This is the one change that made revloop quieter rather than louder, and it is worth knowing.**
Before, `--accept-at` against a ladderless reviewer stopped the run; now it spends a subprocess and a
permission prompt every round. Three of the five shipped reviewers are ladderless — `claude`,
`code-review` and `ecc-review-pr` — so this is the ordinary case for the local family. **The
compensation is disclosure and not a stop**: step 1 prints `severity source` as `grader (<model>)` and
prints the grader's expanded command line before the first round, and every rung it assigns says
`graded` wherever a rung is written. `.revloop/field-notes.md` records that the grader has never
actually run in nine local rounds, so what changed is which invocations reach it, not what happens
when one does.

**The rule the old abort protected is unchanged and restated where grading now lives:** the loop must
never rank the findings it is itself obliged to fix. The grader is a separate subprocess that is not
told the acceptance floor and does not fix what it grades.

### `copilot` removed, and the fences left alone

**`reviewers/copilot.md` is deleted.** The preset was `unsupported` and could not be driven: a reviewer
summoned by reviewer request posts no comment, so there is nothing to anchor a round's baseline to.

**Its three load-bearing facts were rehomed first, and one of them the repository was missing.** The
card held the only cited provenance for the `bot=` filter — Copilot reviews on `iwmaeda/iwmaeda#1` and
`#2` (2026-08), firing automatically rather than by request — while
`docs/design-notes.md` asserted that failure with no citation at all. It now carries the citation. The
no-comment-trigger constraint and the removed-keys note moved to `docs/adding-a-reviewer.md`.

**The fences still name `copilot`, deliberately.** Its two interim-comment patterns are in the wait
fence's drop list and its name is in the compatibility alternation that lets a hand-typed
`@<reviewer> review` anchor a baseline. Neither is a reviewer registry, and a comment already sitting
on a pull request does not disappear when a card does. Removing them would cost every user one
re-approval to shorten a regex, which is the trade the deleted card had already recorded against
itself. `procedures/remote-loop.md` now says so where the fence is.

### Tests

- **New `tests/commands.test.sh`.** The flag matrix per command, the definition-to-command wiring in
  both directions, the procedure pointers, the thinness guards, and that the two families each grant
  one byte-identical tool string — plus that no `local-*` command grants `Bash(gh pr:*)`, which was
  prose in the procedure and enforced by nothing.
- **Both READMEs are compared for the first time.** `README.ja.md` mirrors every section of the English
  one by hand and nothing tested it; the new suite asserts that every command appears in both.
- `tests/schema.test.sh` validates `reviewers/*.json` directly instead of extracting fenced blocks,
  asserts the definition/card pairing in both directions, and pins the removed keys as rejects.
- `tests/fence-guards.test.sh` and `tests/permissions.test.sh` split their globs: fenced bash and fence
  bytes come from `procedures/`, `allowed-tools` from `commands/`.
- `tests/procedure-refs.test.sh` now scans the commands too — a thin command's whole job is to point at
  a step in a file it does not contain, which is where a line-number citation would appear next.

### Also

- `CONTRIBUTING.md` claimed `markdownlint-cli2` runs with `dot: true` and lints `.claude/**` and
  `.agents/**`. It does not, and never did in this configuration; the claim is corrected rather than
  the configuration changed, because nothing has asked for those files to be linted.

**No fence changed, so there is no re-approval to give.** The three shell fences in
`commands/remote-loop.md` are byte-identical and still match the hashes in
`tests/fence-hashes.txt`.

**Nothing is asked of you.** No flag, no permission rule and no `.revloop.json` key has to change:
the key this release makes available is optional, and both shipped local presets already carry it.

**A local reviewer that has run out of quota is now diagnosed as that, instead of as an unreadable
review.** `/revloop:local-loop` aborted with `reason=unparsed-review-output` when its review command
answered with its host's session-limit notice — exit 0, one line, no findings. **The abort was
right and the diagnosis was not**: that reason's documented causes are a working reviewer and a
checkout missing the permission block from [`README.md`](README.md), and it sent the operator to look
at a parser and a permission grant that were both already correct while the reviewer had simply run
out of quota. The round now aborts with `reason=reviewer-rate-limited`, prints the output in full
including the reset time the message names, and says outright that no review was performed.

**The pull-request loop has had this row since it had a reviewer with a quota** — step 9 of
`commands/remote-loop.md`, _"Do not retry. The quota recovers with time;
retrying only burns rounds"_ — and the local loop is now the same ruling in its own table. It does
not retry and it does not wait: the recovery is a fresh invocation once the quota is back, which
step 6's runaway invariant permits because that invariant is a within-run rule.

Added:

- **`rateLimitPatterns` is readable on a `local-command` reviewer.** The schema forbade it, correctly,
  for as long as nothing in that loop read one — a key with no consumer is the defect the kind split
  exists to prevent. Step 8 now reads it, so the key follows the consumer rather than the other way
  round. It is matched against the review's output — its stdout under `invoke: subprocess`, what it
  reports under `invoke: skill` — where the pull-request loop matches it against a comment body;
  `cleanPatterns` did **not** cross with it, because the local loop's clean
  signal is that no finding was parsed and there is no phrase to match.
- **Both shipped local presets declare one**, so an ordinary run gets the named abort with no
  configuration. `ecc-review-pr` carries it as a measurement; `code-review` carries it as a reading
  carried from the sibling preset — the same host binary — and its card says under `## Not measured`
  that the state has never been observed on that command.
- **The step-1 table prints a `rate-limit pattern` row**, reading `declared` or
  `none — a quota reply will read as unparsed-review-output`. A reviewer with no pattern still aborts
  when its quota runs out; the row says in advance which of the two diagnoses you will get, before the
  wait rather than after it.

Fixed:

- **Step 8's clean row said "the three abort rows"** and there are now four. The paragraph above the
  table that enumerates what an outcome-rows-on-top ordering would have swallowed now names the
  fourth: a reviewer that answered with its quota notice parses as zero findings exactly as an
  unreadable output does.

## [0.6.0] - 2026-09-03

**No fence changed, so there is no re-approval to give.** The three shell fences in
`commands/remote-loop.md` are byte-identical and still match the hashes in
`tests/fence-hashes.txt`.

**The two commands are renamed, and the old names are gone.** `/revloop:review-loop` is now
`/revloop:remote-loop`, and `/revloop:review-loop-local` is now `/revloop:local-loop`. There is no
alias and no deprecation window, because a name that still answers is a third and a fourth entry in
the command list — which is the thing the rename exists to remove. What is asked of you is to retype
the invocation, and **nothing else**: no flag, no default, no `.revloop.json` key and no permission
rule moves, so a repository already configured for 0.5.0 needs no migration.

**Four more things ask something of you. The first two are permission rules to add, and both are
about `/revloop:local-loop`.** It now **pushes and opens a pull request by default**, which means:
add `Bash(gh pr create:*)` and `Bash(gh pr list:*)` to your permission rules —
[`docs/permissions.md`](docs/permissions.md) has the full list — and **`gh` is now a requirement of
that command**, where it previously needed nothing on GitHub at all. `--no-publish` is the run that
still needs neither.

**Those two narrow rules are deliberately not the `Bash(gh pr:*)` the remote loop holds.** That rule
covers `gh pr merge`. The local command has no merge step and no `--merge` flag, so it does not hold
the rule that merges — a grant is a capability, and the command that cannot merge should not be able
to.

**The third is a permission prompt, it appears only if you type `--grade-severity`, and it is the one
item here that touches both commands.** The grader is a subprocess carrying a model, so it is
deliberately absent from both `allowed-tools` lines and the permission system sees it every round:
**two prompts a round on a local run** where there was one, and **one on a pull-request run** where
that loop had never started a model subprocess at all. **There is no rule to add** — leaving it out
is the point — so what is asked of you is to expect the prompt rather than to read it as a defect.

**The fourth is an invocation that has stopped working, and it is the one thing here that used to
work and now aborts.** `--accept-at` against `ecc-review-pr` — including the spelling this README
carried as an example, `--accept-at HIGH` — now ends in `reason=no-severity-ladder`. That preset
shipped `severityLevels` and a `severityMap` this release removes, because **five rounds of driving
it established that it emits neither**: the four-rung ladder was read out of one of the six agents
the command dispatches, the only one with a written output format, and none of that format reaches
the aggregate. What is asked of you is to add `--grade-severity` beside the floor, which is what the
other local preset has always needed:

```console
/revloop:local-loop --reviewer ecc-review-pr --accept-at high --grade-severity
```

**A ladder that was read rather than emitted is the failure `reviewers/README.md` exists to prevent**,
and this project shipped one for a release. Removing it is the correction; the flag is the way back
to a floor.

**Also new, and it is not something you configure: `ecc-review-pr` does not work in a checkout that
has not been given permissions.** Without the block in [`README.md`](README.md) at
`.claude/settings.local.json`, the command exits **0** in under a minute and returns a paragraph
asking for a permission grant — no findings, no severity, no verdict. The loop catches it as
`unparsed-review-output` rather than as a clean round, and the card now records the permission block
as a precondition of the preset rather than of the pull-request loop alone.

Added:

- **`--accept-at` takes one vocabulary, whatever the reviewer calls its rungs.** The level is matched
  against the resolved reviewer's `severityLevels` first — as a whole string, case-sensitively, which
  is what the flag always did, so **no existing invocation changes meaning** — and only then against
  revloop's own canonical ladder, `critical > high > medium > low`, carried onto the reviewer's rungs
  by a new **`severityMap`** key. Three emitted vocabularies already coexisted among the shipped
  presets, so a floor written in one reviewer's words aborted against the others and the flag read as
  broken rather than as reviewer-specific.

  **The map is a judgement and the ladder is a measurement, and they are two keys for that reason.**
  Nothing establishes that one reviewer's `P1` and another's `CRITICAL` describe the same thing, so
  each card ships its map in the config block and says under `## Not measured` that it is a judgement
  — including which canonical rung a three-rung ladder had to skip. The loop **never derives a map
  from rung position**: a canonical level against a reviewer that has a ladder and no map aborts
  with `reason=no-severity-map`, because reading `critical` off "rung 1 of 3" is the loop authoring
  a ladder one key over from where that was already forbidden. **That abort is scoped to a reviewer
  that has a ladder**, so a reviewer carrying neither key — the one `--grade-severity` exists for —
  reaches a round rather than this row. A partial, **foreign**, inverted, or **wholly collapsed** map
  aborts with `reason=bad-severity-map` — collapsed because a map sending every rung to one canonical
  rung is total and inverts nothing while making the lowest floor the flag can express accept the
  reviewer's worst finding, and foreign because a ladder shortened without its map satisfies totality
  while leaving an entry pointing at a rung that no longer exists. Merging rungs stays legal, and is
  unavoidable: three rungs cannot cover four canonical ones and five cannot avoid sharing. **That
  abort is checked only when `--accept-at` resolved on the canonical pass**, for the reason the map is
  allowed a config key at all: a map nothing consults cannot move a floor, so checking it on every run
  broke a reviewer for ordinary use over a key that run never read.

  **A canonical floor is compared rung by rung and does not have to be a rung any of them maps to.**
  Both shipped `P1`/`P2`/`P3` maps skip `medium`, so `--accept-at medium` against either leaves `P1`
  and `P2` blocking and `P3` acceptable — the same floor `--accept-at low` gives, which is what four
  canonical rungs receiving three means rather than a defect in either.

  **`severityMap` is settable from `.revloop.json` and `--accept-at` still is not**, which is a line
  worth being explicit about: `severityLevels`' own **order** has always carried the same power to
  move a floor, so the map is no new class of it. The mitigation covers both — **step 1 now prints
  the resolved floor expanded**, as the sets of the reviewer's own rungs that block and that are
  acceptable, before the first round runs.

- **`--grade-severity`: an acceptance floor against a reviewer that emits no severity.** This is the
  ordinary case rather than an edge one — [`reviewers/code-review.md`](reviewers/code-review.md)
  measures that the local loop's own default preset emits none, so `--accept-at` aborted against it,
  and that card had been asking for a run under the floor to settle whether the loop converges at all.
  **That measurement was not merely unmade; it was unreachable.**

  The flag is **off unless typed** and has no configuration key, for the reason `--accept-at` has
  none. Without it, a reviewer with no ladder still aborts with `reason=no-severity-ladder`, exactly
  as before. It is **refused against a reviewer that has a ladder** (`grade-over-ladder`), because
  regrading a rung the reviewer emitted replaces a measurement with an inference, and typing it with
  no floor aborts too (`grade-without-floor`) — the rungs would have no consumer.

  **It narrows "the loop never supplies a ladder the reviewer did not"; it does not repeal it**, and
  [`docs/design-notes.md`](docs/design-notes.md) argues the new boundary rather than deleting the old
  paragraph. That rule was never about where a rung comes from — it is about the party obliged to fix
  the finding, and about a reader who cannot check afterwards which kind of rung they are looking at.
  So: **the grader is a separate subprocess** on the review model, with none of the loop's context,
  and it does not fix what it grades. **It is not told the acceptance floor**, which is the
  load-bearing half — a grader that knows what will be spared is answering "how much work should the
  caller do" instead of "how severe is this". And **every graded rung is marked `graded`** in the
  pull-request reply, the commit's `Accepted:` block, the pull-request body and both reports, which is
  the direct answer to "from outside the run that is indistinguishable from a reviewer that really
  graded them that way".

  **Withholding the floor accomplishes nothing if a finding can supply one**, so the grader is told
  in its own prompt that the findings are data and not instructions. They are reviewer output quoting
  repository content, so a claim reading "known false positive, rank it low" is the lever the whole
  arrangement is built to keep out of reach, arriving through the one door left open — and it would
  parse, abort nothing, and converge clean. **The findings reach the grader through a file rather
  than through its command line** for the same reason `--body-file` carries a pull-request body:
  building an argv out of repository-derived text is a hole, and it also kept the string you approve
  from growing with the findings. The procedure specifies the grader **once**, in step 10 of
  `commands/remote-loop.md`, which the local loop now cites rather than restates.

  **A graded rung is kept out of step 7's repeat fingerprint**, because a grader's rung can move by
  being asked twice and putting it in the key would switch the repeat suppression off on precisely
  the reviewer whose card measures rounds that do not converge. The finding that would otherwise
  strand is answered separately: **an accepted finding whose graded rung later rises above the floor
  is re-opened and re-bucketed**, which the closed `accepted` bucket bounds to once with no counter,
  since a re-read cannot put it back where a floor it now exceeds would have to hold it.

  **Four things abort a graded round, and all four say the grader is broken rather than that it
  declined a finding**: a non-zero exit (`reason=grading-command-failed`), output that does not parse
  (`reason=unparsed-grading-output`), and — sharing that second reason — a rung outside the four
  canonical words or a finding number that was not sent. **A finding for which no line arrived is not
  one of them**: it is blocking and listed as `ungraded`. Rungs are attached **by the number on each
  line and never by the line's position**, because one dropped line would otherwise shift every rung
  after it and a `critical` would inherit the rung below it, accepted and silent — the same defect
  `unknown-accept-level` refuses on the other ladder.

  **What this does not establish is that a grader's rungs are any good.** Nothing measures that, and
  the reports say a graded convergence is the weaker result. **Nor is the data-not-instructions
  framing measured** — a grader that followed an injected claim answers in the same shape as one that
  did not, so it is the one guard here with no failure mode to fail into, and both procedures say so
  under `## Unexercised paths`. A graded run costs **one more permission prompt a round** than the
  same run without the
  flag — two rather than one in the local loop, where the review command is already prompted for, and
  one rather than none in the pull-request loop, whose reviewer is a GitHub app rather than a process
  it starts. The grader's command line is this procedure's own rather than the repository's, but it
  carries a model, so it is no more a fence than the review command is.

- **`/revloop:local-loop` carries the branch to a pull request.** The loop ended at a commit
  and left the branch for a person or for the remote loop; it now pushes it and opens a pull request,
  reaching the place `/revloop:remote-loop` starts from. **`--no-publish` ends the run at the commit**
  and is the only flag on the feature — an earlier draft of this release had `--push` and `--pr` as
  opt-in flags instead, and inverting the default removed one flag, the "push but no pull request"
  middle state, and every rule that existed only to describe it. Neither flag ever reached a release,
  so nothing in the wild is being taken away.

  **Where the publishing happens is read off the reviewer's `requiresPr`, not off a flag, and that is
  the load-bearing decision in this release.** A reviewer that resolves its own pull request is
  published to before every round, because it would otherwise read a stale diff. Everything else is
  published to once, after the loop converges — **because a push breaks the shipped default
  reviewer.** [`reviewers/code-review.md`](reviewers/code-review.md) records that `/code-review` diffs
  against the branch's upstream when there is one; `git push -u origin HEAD` creates one, `HEAD` then
  equals it, the range is empty, and the commit step has just left the tree clean. A round run after a
  push returns **zero findings**, and zero findings is what a clean review looks like. That is the
  failure this whole family of procedures exists to prevent, reachable through a feature that looks
  unrelated to reviewing — so a `--publish-before-review` switch would have been a way to configure
  it, and the placement is derived instead.

  **One stop disappears on the ordinary run, and it is a removal rather than a suppression.** A
  `requiresPr` reviewer used to cost a confirmation that an open pull request existed, and the
  decision table used to refuse to read zero findings from one as clean. Both existed because the loop
  **could not check**. Publishing supplies the check — step 5 reads the branch's open pull requests
  **that round**, creates one if none answered, and pushes `HEAD` to it immediately before the
  reviewer runs. The read is the round's own rather than step 1's, because step 1's can be stale by
  the second round and a stop retired against a stale read is suppressed rather than supplied.
  `--auto` deletes a question and leaves the uncertainty; this answers the question, which is why it
  may remove a stop `--auto` is not
  allowed to touch. **Both survive under `--no-publish`**, which is the run that still cannot check.

  **It also closes a gap this project had written down and could not fix.** The last round's
  `Accepted:` block reaches no commit — a run that converges by accepting makes no further commit to
  carry it — and the procedure's own text used to end that paragraph by telling you the acceptances
  "belong in the pull-request body you write next", an instruction to a person about an artifact the
  command could not write. It writes it now.

  **What the default costs is stated rather than hidden.** Three situations cannot publish at all — a
  fork, a repository with no `origin`, and a remote that is not GitHub — and step 1 aborts on them
  with `reason=fork-unsupported` or `reason=publish-unavailable`, naming `--no-publish` as the way
  through. Under opt-in flags a user in any of those simply never typed one and the loop worked. **A
  fork is not a rare place to work**, and that is the price of the default.

- **`--review-model <name>`, defaulting to `sonnet`.** The review runs on a light model; the fixing
  stays on whatever model is running the procedure. **This began as a cost change and is recorded as
  an evidentiary one**, because of something the project had already written down twice:
  [`docs/design-notes.md`](docs/design-notes.md) and
  [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) both said a local reviewer sharing the
  fixer's model is not an independent check, and that **only a different model makes it one** — and
  both then listed "a reviewer that runs a different model" as a candidate nobody had shipped. **That
  framing was wrong in a way worth naming: it treated the model as a property of which command you
  pick.** It is a property of how the command is invoked. So the cheap configuration and the more
  independent one turn out to be the same configuration, and it needed no new reviewer.

  **The model reaches the reviewer through a `{reviewModel}` placeholder in its `command`, and not by
  splicing a flag in.** Splicing guesses the command's CLI — one reviewer spells it `--model`, another
  `-m`, another an environment variable, another takes no model at all — and this project aborts
  rather than guesses everywhere else. The placeholder lets whoever wrote the command, the only party
  that knows, say where the model goes.

  **There is no configuration key for it, and for a sharper reason than the flags above.** Its value
  is **expanded into a command line**, so a key would be the first thing revloop interpolates into a
  shell command out of a repository-supplied file —
  [`docs/configuration.md`](docs/configuration.md) states the opposite as an invariant. It comes from
  the flag or the builtin, and is refused unless it matches `^[A-Za-z0-9][A-Za-z0-9._:-]*$`.

  **A flag that cannot act aborts rather than passing silently.** `--review-model` against an
  `invoke: skill` reviewer, or against a `subprocess` one whose command carries no placeholder, aborts
  with `reason=no-model-boundary` and names the fix. This is the rule `--accept-at` already follows
  against a reviewer with no ladder, and it bites harder: somebody typing `--review-model haiku` to
  spend less would otherwise be billed for the strongest model with nothing saying so.

- **`--no-publish` has no configuration key, and inheriting its neighbours' reason would have been
  wrong.** `--merge`, `--auto` and `--accept-at` have none because a repository you just cloned must
  not be able to **grant itself** an action. **Publishing is the default, so a key could only turn it
  off, and a key that removes an action grants nothing.** It stays flag-only because nothing measured
  says a project wants it — a _not yet_, not a _never_, and `tests/schema.test.sh` pins the rejection
  so that adding `defaults.localPublish` is a deliberate act with a test to delete.

Changed:

- **The two commands are named for where they run.**

  | Was                             | Is                        |
  | ------------------------------- | ------------------------- |
  | `/revloop:review-loop`          | `/revloop:remote-loop`    |
  | `/revloop:review-loop-local`    | `/revloop:local-loop`     |
  | `commands/review-loop.md`       | `commands/remote-loop.md` |
  | `commands/review-loop-local.md` | `commands/local-loop.md`  |

  The old pair named the axis once. The remote command carried no word for where it ran, so the local
  one read as a variant of it — and it is not one:
  [`docs/design-notes.md`](docs/design-notes.md) argues at length that these are two procedures with
  different reviewer classes and different scarce resources, one spending wall clock and the other
  tokens. The names now carry that distinction instead of leaving it to the documentation.

  **A command's name is its filename**, so this is a rename of the two files, of every reference to
  them, and of each procedure's own title: the remote one read `# revloop — the review-and-fix loop`,
  carrying the same silence about where it ran that its filename did. `.claude-plugin/plugin.json`
  globs `./commands/`, so no manifest was edited and **the version is unchanged**.

  **Nothing else moved.** The three fences are byte-identical — `tests/fence-hashes.txt` is untouched,
  so there is no re-approval to give — and so is each procedure's `allowed-tools` line, every flag,
  every default, and every key the schema accepts. The one thing to re-export is the Codex router's
  entry point: it resolves `commands/remote-loop.md` now, so `REVLOOP_PROCEDURE` points at the new
  path.

  **The released sections below still say `review-loop`, and that is deliberate.** They record what
  the files were called when each release was cut, so their prose is left as written; only the link
  targets were moved, so a click from an August entry still lands on the file that entry is about.

- **Both shipped local presets pin `{reviewModel}`, and `ecc-review-pr` moves from `invoke: skill` to
  `subprocess`.** A skill runs in the loop's own session, on the loop's model, spending the loop's
  context, and nothing inside a session can lower the model it is running on — so it was the one
  shipped preset that tripped the new abort. **The switch discards no measurement**, because
  [`reviewers/ecc-review-pr.md`](reviewers/ecc-review-pr.md) was written entirely from the installed
  command and never from a run. What it adds is unknown rather than measured, and the card says so:
  whether a subprocess reaches `gh` — which that reviewer needs — and whether the plugin's skills load
  in a `-p` session. `invoke: skill` remains supported for hosts that forbid the other.

- **`reviewers/code-review.md`'s five measured rounds no longer describe the shipped preset**, and the
  card leads with that. They ran `claude -p "/code-review medium"` with no `--model` at all; the
  preset now pins one. The finding counts, the wall clock, the output shape and the absence of repeats
  are kept because they are the only measurements that exist and most of what they establish is about
  the command rather than the model — but **the direction of the error is not knowable from that
  sample**: fewer findings from a lighter reviewer may mean fewer defects present or fewer defects
  found.

- **The local procedure is eleven steps rather than nine**, with publishing at 5 and at 10, and every
  internal citation renumbered. **`--max-rounds` is now checked wherever a round opens** — step 5 for
  a `requiresPr: true` reviewer, whose push is that round's first act, and step 6 for every other.
  The cap used to sit at the first step of a round that spent tokens; publishing put a step that
  pushes in front of it, so on the last permitted round the fix reached the pull request before the
  cap aborted, leaving a commit there that the loop never reviewed.
  `tests/procedure-refs.test.sh` permits step citations and forbids line numbers, so nothing but
  reading catches a stale one; they were swept by hand.

- **A `subprocess` command may not begin with `gh`, or with the `{reviewModel}` placeholder.** The
  first is the existing `git` rule applied to the second grant, and it is **deliberately wider than
  the four rules that motivate it** — banning the granted spellings instead would be four rules that
  have to track a grant list every future step can extend, and a ban that lags its grants by one
  release is the hole itself. The second closes the same hole reached through expansion:
  `{reviewModel} push --force` under `--review-model git` would otherwise become exactly the banned
  shape, since expansion happens after the prefix is checked. The procedure additionally re-checks the
  **expanded** string before running it, because a static rule about a template is not a rule about
  what ran. `tests/schema.test.sh` pins every axis of both.

- **Both shipped local presets have now been driven, and most of what that established is that the
  cards were wrong.** Eight rounds against `iwmaeda/revloop#22`: five of `ecc-review-pr`, which had
  never been run at all, and three of `code-review`, each of them a clean round — the first that
  reviewer
  has ever returned. Neither loop converged on `reviewers/README.md`'s bar, so **both cards stay
  `unverified`** — the third and fourth runs in this repository to end at a cap rather than at a clean
  round, after codex's two. What changed is the evidence under them.

- **`reviewers/code-review.md` derived that a push empties this reviewer's target, and a run in
  exactly that state disproves it.** The card read out of the installed command that `/code-review`
  diffs against the upstream and falls back to the base branch, so a pushed branch — upstream set,
  `HEAD` equal to it, tree clean — was expected to leave the reviewer nothing to read. Run there, it
  reviewed `main..HEAD`, named the changed file and described its diff. Zero findings came back, which
  is what the derivation predicted, for the opposite reason. **That card's `## Not measured` had asked
  for this run by name.** Step 5 of `commands/local-loop.md` cited the
  derivation as measured behaviour; **the publish placement does not move**, and what holds it is now
  stated as caution — one sample is not enough to relocate a step whose failure mode is a run
  finishing clean over a diff nobody read.

- **The output shape of `/code-review` is not stable, and three of them have now been seen.** The five
  rounds recorded for 0.5.0 ran with no `--model` and returned a `Findings (N):` list; under the
  `sonnet` pin the same command at the same effort returned a fenced JSON array, and then prose
  stating the count with no fence at all. **That is why an unrecognised shape is an abort and not a
  loose parse**, and it is the first evidence that the pin this release ships moves more than the
  price of a round.

- **`ecc-review-pr` emits the command's confidence words as headings, and its latency is the highest
  measured in this repository.** Five rounds returned 3, 10, 6, 7 and 7 findings — 33, all distinct,
  no repeat in any of them — in 5m09s, 9m17s, 9m17s, 12m05s and 11m29s, above `code-review`'s
  5m27s–8m39s and above the remote reviewer's 2:46–10:07 at the top end. Six dispatched agents are not
  the cheap end of the local loop.

- **Thirteen rounds across the two presets produced no repeat, so `repeat-findings` is still an abort
  nothing has entered**, and the repeat fingerprint is still unexercised — 73 findings, 73 distinct,
  counting the five `code-review` rounds recorded for 0.5.0. That is now measured rather
  than assumed, and it is recorded on both cards.

- **`tests/version.test.sh` compares the lockfile as well.** The version lived in five manifests and
  the changelog and was checked in all six; `package-lock.json` carries it too, npm regenerates it
  rather than taking an edit, and skipping that regeneration leaves a tracked, shipped file reporting
  the previous release. Nothing downstream complains — `npm ci` was measured installing a
  version-mismatched lockfile without a word, exit 0 — so this suite is where it is caught or nowhere.
  The comparison is a function now, and eleven self-checks drive it against a synthetic mismatch, an
  absent path, an absent file, a file that is not JSON, one that cannot be opened, an empty reference
  and five malformed rows: every row before this ran against manifests that already agreed, so the
  branch reporting a disagreement had never once been entered.

Removed:

- **`severityLevels` and `severityMap` from the `ecc-review-pr` preset**, from its card, and from
  [`examples/revloop.local-reviewer.json`](examples/revloop.local-reviewer.json). See the fourth item
  at the top: they described a ladder the reviewer does not emit. **`grade-over-ladder` is no longer
  reachable through a shipped preset** as a result, and is kept for a configured reviewer that has a
  ladder of its own.

## [0.5.0] - 2026-09-02

**No fence changed, so nothing here asks anything of you.** The three shell fences in
`commands/review-loop.md` are byte-identical to 0.4.0 and still match the
hashes in `tests/fence-hashes.txt`, which `tests/fence-guards.test.sh` reports on every run — so there
is **no re-approval to give**. The granted rule list in
[`docs/permissions.md`](docs/permissions.md) is unchanged as well, and the new command grants a
strict subset of it: `Bash(git:*)` and nothing else.

**That is not luck, and it is the reason this release looks the way it does.** The local loop runs a
command that comes out of `.revloop.json`, and the tempting shape for it was a fence — a fixed string
the permission system approves once. A fence is safe **because its bytes never change**, and this
string is per-project by construction, so a fence here would either prompt every round anyway or hand
a cloned repository a pre-approved slot. `verify` had already answered the question: show the string
in the step-1 table, keep it out of `allowed-tools`, and let the permission system see it every time.
The cost is one prompt per round for the one string most worth looking at.

Added:

- **`/revloop:review-loop-local`, a second procedure that drives a review command on your machine and
  ends at a commit.** It never calls `gh`, opens no pull request, and merges nothing. The failure it
  answers is arithmetic this repository had already written down and could not act on:
  `reviewers/codex.md` derives that **the number of remote rounds is roughly the number of defects
  present when the trigger fires**, and step 3 of the remote procedure has told you since 0.1.0 to run
  step 10's sweeps one step early for that reason — by hand, unaided, as "read the change you are
  about to push". This command is that instruction with a reviewer behind it.

  **It is a separate file rather than a `--local` branch**, and the argument against two code paths
  in [`docs/design-notes.md`](docs/design-notes.md) is what settles it rather than what stands in the
  way. That argument is about two ways of reaching the **same** outcome halving the coverage behind
  every claim. These are not the same outcome: roughly half of `review-loop.md` — the baseline
  timestamp, the trigger marker, the re-post budget, the two-trigger sweep, the wait fence — exists
  because a verdict arrives later, from elsewhere, possibly for someone else's trigger. None of that
  is true when the reviewer hands you its own output, and carrying it across would leave every one of
  those rules to be re-read as "does this still apply?" by whoever edits next. What the two share is
  the prepare phase, and the local procedure **cites it by step number rather than restating it**,
  because `CONTRIBUTING.md` forbids the copy and a restatement is three places to fix the next
  whitespace-preflight defect instead of one.

  **The scarce resource is different, and the procedure is shaped around that.** A remote round costs
  minutes of someone else's compute and a quota that runs out, and both are visible. A local round
  costs tokens, and **nothing in the room displays that** — so four rules exist only because of it: the review
  is not re-run while HEAD is unchanged and the tree is clean (the runaway invariant, transplanted for
  a different reason — remotely the cost is obvious, locally there is nothing else to notice it), a
  finding whose fingerprint this run already answered is counted and **not reasoned about again**, a
  round carries at most ten findings into the fix step, and `--max-rounds` defaults to 5 rather than
  10 because the cap is the only brake there is.

  **An unreadable result is its own abort, and never a clean round.** The built-in review command's
  output shape depends on the effort level and on the model running it — the same command returns a
  fenced JSON array in one configuration and one line per finding in another — so a parser written
  against the shape its author happened to see returns **zero findings** against the other. Zero
  findings is what a clean review looks like. Step 10 of the remote procedure states this rule three
  times for three different reads; it is stated here for the one read this command has.

- **`--accept-at <level>`, on both loops: the highest severity that may be left unfixed.** The failure
  is in this repository's own field notes, three times. `iwmaeda/revloop#13` hit `--max-rounds 10`
  still returning findings, was re-run at 20, hit that too with the last five rounds returning P1, and
  ended at a rate limit. The only exit the procedure had was `abort`, and there was no way to say
  "the top rung is clear, the rest is understood, this is done". `reviewers/gemini.md` records the
  same shape from the other end at 30–50 findings in a single round.

  **It is the first consumer `severityLevels` has ever had.** The schema says a key with no consumer
  is a promise the procedure does not keep, and for four releases this was that key: three cards
  filled the ladder in, nothing read it, and the one place that reasoned about severity — step 12's
  "lead the report with a declined P1" — named **codex's vocabulary** literally. On the
  `["blocker","major","minor"]` ladder shipped in `examples/revloop.custom-reviewer.json`, that rule
  named a rung that does not exist and therefore led with nothing, on a reviewer class nobody had
  driven. Step 12 now reads the top rung off the resolved reviewer.

  **It is off by default, and a run without the flag behaves exactly as 0.4.0 did.** It is flag-only
  for the reason `--merge` and `--auto` are: a repository you just cloned must not be able to lower
  its own review bar while the run still reports a clean convergence. `tests/schema.test.sh` now
  rejects it in both the `defaults` block and a reviewer entry.

  **Accepting is not skipping the read.** An accepted finding is still fetched, classified, recorded
  and listed; the floor decides only when the loop may stop. **"Recorded" rather than "replied to",
  because only one of the two loops has anywhere to reply**: the pull-request loop answers each
  acceptance in a reply, and the local loop writes the same rung-and-floor pair into the commit's
  `Accepted:` block and the report. That boundary is where the flag is safe,
  because `reviewers/codex.md` says outright **not to triage by the badge** — it measured one pull
  request returning 15 of 15 at P2 and another 15 of 15 at P1 — and a version of this flag that
  skipped fetching the accepted rungs would be exactly what that card forbids, and cheaper, which is
  why the rule is written into the procedure rather than left to judgement. The record for an
  acceptance is required to name the rung and the floor, so that it cannot read like a decline: a
  decline asserts the finding is wrong and carries a citation, an acceptance concedes it is right and
  unfixed, and the reader deciding whether to merge cannot recover the difference afterwards.

  **`--accept-at --merge --auto` aborts.** The floor's safety argument is that a person reads the
  accepted list before the merge, and `--auto` exists to delete that class of stop. With `--merge`
  alone, an accepted finding adds a third stop point that lists them.

  **The loop never supplies a ladder the reviewer did not.** Asked to accept from a reviewer that
  emits no severity, step 1 aborts with `no-severity-ladder` rather than ranking the findings itself.
  It is the party obliged to fix them, so a ladder it authors is one it can author its way out of the
  work with, and from outside the run that is indistinguishable from a reviewer that really graded
  them that way. This is not hypothetical: the built-in review command shipped as a preset below is
  exactly that reviewer.

- **Reviewers now have a `kind`, and the schema enforces which fields each may carry.** `kind` is
  absent from every configuration written before this release and absent means `github-comment`, so
  nothing changes meaning. A `local-command` reviewer requires `invoke` and `command`, may carry
  `requiresPr`, and **may not carry** `botLogin`, `trigger`, `markerTolerated`, `cleanPatterns` or
  `rateLimitPatterns`; the reverse holds too, so a `github-comment` reviewer may not carry `command`.
  Without the second direction `kind` would be a label rather than a discriminator, and a reviewer
  could be given a field its loop never reads — the same defect as a config key with no consumer.

  **`requiresPr` exists because "returned nothing" and "found nothing" are the same empty result.**
  A review command that resolves a pull request itself has no target when there is none, and reading
  that as a clean round is the failure mode this whole family of procedures is built around. **The
  loop cannot check whether a pull request exists** — it has no `gh` grant, which is the point of it
  — so the key does not buy an abort the way `markerTolerated: "no"` does. It buys two things that
  are checkable: a confirmation before the first round, and a standing rule in step 7 that **zero
  findings from such a reviewer is never a clean round**. An abort was the first design and it made
  a shipped preset unreachable on the branches where it actually works.

  **There is no `effort` key.** Whatever depth argument a review command takes belongs inside
  `command`, which is the string the step-1 table shows and the string the permission system matches.
  A separate key would put half the invocation where neither of those looks.

  **The one guard on that string — a `subprocess` command may not begin with `git` — is a plain string
  prefix, and two narrower spellings leaked before it got there.** The local command grants
  `Bash(git:*)` for its own probe, and `docs/permissions.md` states the model the whole rule rests on:
  **Claude Code matches a command-string prefix.** So the set to reject is every string starting with
  those three characters, and both earlier attempts instead asked where the _word_ `git` ends — a
  question the matcher never asks. `^\s*git(\s|$)` read only whitespace and end-of-string as ending
  it, so `git;rm -rf /`, `git&&rm -rf /`, `git&`, `git|tee`, `git>out`, `git<in` and `git"" push` all
  passed. `^\s*git($|[^A-Za-z0-9_.-])` closed those and still admitted `gitlint`, `git-review` and
  `git.exe`, on the reasoning that the shell would run a different binary — true, and irrelevant.
  **The prose in `docs/permissions.md`, `SECURITY.md` and the procedure said "may not begin with
  `git`" the whole time; the implementation is now that sentence and nothing else.** The cost is
  stated where a reader configuring a reviewer will meet it: a review command whose own name starts
  with `git` cannot be a `subprocess` reviewer, and has to be configured as a `skill` — which no
  `Bash` rule matches — or renamed. `tests/schema.test.sh` pins both axes.

- **Step 6 of the local loop buckets every finding, not every finding above the floor, and step 7's
  clean row is "no findings" rather than "none above the floor".** Both bounded _reading_ by the
  acceptance floor, when the floor is only allowed to bound _stopping_. A review consisting entirely
  of acceptable findings took the clean row straight to the report before step 8 had assigned a single
  `accepted` bucket — so the run announced a clean convergence over findings the reviewer raised, the
  command parsed, and nobody classified or recorded. That is the exact claim `--accept-at` is sold
  on ("accepting is not skipping the read"), broken in the one case where accepting is the whole
  round. A finding reaching the report with no bucket is **accepted by nothing but its absence from
  the fixed list**, which is the distinction the acceptance reply exists to preserve. A genuinely
  clean round is unaffected: it takes the new first row and reaches step 9 as before.

- **`--max-rounds` is checked where a round is opened — step 7 remotely, step 5 locally — and is
  decided from no verdict at all.** Three placements were tried and the first two are recorded here
  because each looked like the fix for the last. As the decision table's **last** row it was
  unreachable, since every ordinary verdict matched something above it. As the **first** row it
  aborts a round that came back clean on exactly the round the operator budgeted for, because the cap
  aborts a loop that _has not converged_. As a **rule over the row's outcome** it still fails in both
  directions: a `review` row says "go and read the findings", not "the loop has not converged", so
  capping it rejects a valid final round — and a clean comment or a reaction is waved through, while
  on a two-trigger round the mandatory step 10 sweep can then surface blocking findings and open the
  next round past the cap. **The cap is not a property of a verdict**, which is why no position in
  either table was ever going to be right. Deciding it where the round opens also costs nothing when
  it fires: the wait, the trigger and the reviewer's quota are all still unspent.

- **A verdict line carrying `marker_head=none` reaches the lost-baseline row instead of being
  demoted to `pending`.** Step 8 reconciles a mismatched `trigger=` by treating every form as
  `pending`, and step 7 states that a verdict line is the **only** positive evidence that the
  baseline is foreign — precisely because it carries `marker_head=` where a `pending` line carries
  nothing. So the reconciliation destroyed the one signal the recovery is defined in terms of. The
  ordinary way to lose a baseline is a newer hand-typed trigger, which produces exactly the shape the
  carve-out is for: `trigger=` not yours **and** `marker_head=none`. Without it that became three
  mismatches and `reason=foreign-baseline`, which promises no recovery, while the `marker_head=none`
  row — which promises a later run re-takes the baseline — was unreachable for its commonest cause,
  in spite of two places saying it takes precedence.

- **The `requiresPr` confirmation defers to the single stop, which previously only the `skill` half
  did.** Fixing one of a promised pair is not fixing the pair: a reviewer that is `skill`-invoked
  _and_ sets `requiresPr` is the case the "one stop" promise exists for, and it was the case that
  still stopped twice. The shipped `ecc-review-pr` preset is both.

- **The acceptance promise says "recorded" rather than "replied to", in all five places that made
  it.** A reply is a mechanism only the pull-request loop has; the local loop opens none, so the
  wording left it owing a reply it has nowhere to post. Its record is the commit's `Accepted:` block
  and the report, and step 8 now states the obligation where the bucket is assigned rather than only
  at step 4 — a record owed at one step and described at another is a record nobody writes.

- **Both decision tables say how they are read, and their guards sit where first-match reading
  reaches them.** Neither table stated that the first matching row wins, and both were written with
  the exhaustive outcome rows on top — so the cross-cutting guards beneath them could not fire. In
  the local loop nothing mitigated it, because that table is the entire decision: `No findings at
all` matched every zero-finding result, and an unreadable output, a command that never ran, and a
  `requiresPr` reviewer with no pull request **all parse as zero findings**. Each is a run finishing
  clean over a review that did not happen, which is the failure this whole family of procedures
  exists to prevent, and `unconfirmed-empty-review` asserted in its own prose that it takes
  precedence over the clean row while sitting below it. The three aborts now precede it. In the
  pull-request loop the equivalent cases are already caught by checks (a) to (e) before any row is
  read, and two ordering defects were not: `interim-loop` sat behind "any other bot body", a
  strictly wider description of the same comment that swallowed it and aborted with a reason that
  sends the reader hunting an unknown bot; and `EXTRA=`, whose whole content is the rule "rate limit
  takes precedence", was the **last** row, while the fence only ever emits it alongside a `review`
  whose rows are above. `EXTRA=` is now a rule read before the primary line, and `interim-loop`
  precedes the row that shadowed it.

- **`--max-rounds` is applied to the verdict in both loops, and is no longer a row in either table.**
  It was the last row of both, where every ordinary verdict matched something above it, so **the one
  brake that cannot be reached by waiting longer was the one thing waiting longer always skipped**.
  Moving it to the top is the obvious correction and is worse: the cap aborts a loop that **has not
  converged**, so a first row would abort a round that came back clean on exactly the round the
  operator budgeted for, and report a converged run as a failure. Neither position works, because
  the cap is not a signal the reviewer produces — it is a condition on what a signal is allowed to
  mean. The rule is now stated as one: read the table, and if the row it lands on says _continue_
  while the cap is reached, abort with `--max-rounds` as the reason; a clean finish at the cap is a
  convergence.

- **The local loop's `skill` confirmation no longer takes its own stop.** The bullet said "take
  confirmation of it before the first round" and the bullet below it promised that the `skill` and
  `requiresPr` confirmations are **one** stop — and step 1's judgements are read in order, so a
  reviewer setting both stopped twice. Two stops where one was promised teaches the operator that
  the stops are approximate, which is the wrong lesson about the only stop `--auto` cannot suppress.

- **Step 1 of the pull-request loop checks the reviewer's `kind` before it checks for a `trigger`.**
  `reason=not-a-github-reviewer` was added this release so a `local-command` reviewer passed to the
  wrong loop reports the right cause — but it sat _after_ the `no-comment-trigger` row, and the schema
  forbids a `local-command` reviewer from carrying a `trigger` at all. So the new row was unreachable
  for exactly the configuration it diagnoses, and every such run reported a missing field instead. The
  ordering is now stated in the row itself as the reason it exists. It unshadows
  `marker-not-tolerated` the same way, which such a reviewer also cannot carry.

- **`defaults.localReviewer`, because `defaults.reviewer` is one key and the two loops need different
  values.** Every configuration written before this release points `reviewer` at a `github-comment`
  reviewer, so the local loop reading that key would abort `not-a-local-reviewer` on every run until
  `--reviewer` was typed. Falling back to "the only local reviewer defined" would be a guess, which
  is what an unknown `--reviewer` already refuses to make.

- **`defaults.localMaxRounds`, for the same reason and a sharper one.** One key with a per-loop
  built-in was the first design, and it is wrong: a `maxRounds` written for the remote loop silently
  raised the local cap from 5 to whatever it said, and **the local loop's cap is the only brake it
  has** — a remote round announces itself with a push, a comment, a wait and a quota, and a local one
  announces nothing. Both stay settable from config, unlike `--accept-at`, because they bound spend
  rather than safety.

- **Two `local-command` presets, both `unverified`, with cards that say what that means here.**
  Each records **what the installed command declares**, read out of a named version, in a
  `### From the installed command` subsection. `reviewers/code-review.md` additionally carries five
  observed rounds in a subsection of their own, because the command was driven while this release was
  written; `reviewers/ecc-review-pr.md` has no such subsection, because it was not, and says so where
  the subsection would be. **Both stay `unverified`**, and `reviewers/README.md` now says why that
  word is narrower here: the bar for a local reviewer is the loop driven to convergence, and observing
  the command answer — five times or fifty — is not that.

  Two of those declarations are worth reading before choosing a preset. The built-in command's
  reporting surface **carries no severity field at all** — severity is only the order of the list — so
  its card carries no ladder and `--accept-at` aborts against it; its own per-round cap, 4 findings at
  the lowest effort rising to 15 at the highest, is the brake instead. And `ecc:review-pr`'s
  `critical` / `important` / `advisory` are a **confidence rule, not an output format**: they appear
  once each in a closing section, the command has no heading template, and the vocabulary that reaches
  the output comes from an agent it dispatches, which tags findings `CRITICAL` / `HIGH` / `MEDIUM` /
  `LOW`. That four-rung ladder is what the card carries, because a ladder taken from the documented
  three would name rungs the output never emits and `--accept-at important` would match nothing and
  block everything.

- **A third provenance form for reviewer cards: the artifact and its exact version, plus a month.**
  `ecc 2.2.0, 2026-09`. Neither existing form fits a local reviewer — it is not observed on a pull
  request and not inside a private repository — and an artifact version is **more** checkable than the
  anonymised form, since anyone can install that version and read the same file where nobody outside
  can open `repo C` at all. `tests/provenance.test.sh` pins it on the same axes as the other two, and
  `reviewers/README.md` states the limit the form carries: it cites a **declaration**, not a
  behaviour, and a card written from the artifact alone stays `unverified`.

  **A second limit is pinned rather than described**: the lowercase-name rule excludes capitalised
  prose before a version, and does **not** exclude this project's own name, so `revloop 0.4.0` plus a
  month passes as provenance for a bullet about somebody else's reviewer. Closing that means judging
  what a sentence is about, which is the judgement the per-sentence check was already declined for.
  There is a case asserting the gap exists, because a limit stated in a comment and contradicted by
  the code is worse than no comment — and this file had gone green on its own failure case once
  before.

**One thing this release does not claim, and the reason it is worth saying here.** The local
procedure and both its presets ship `unverified`. Rounds do exist: this release's own diff was put
through `claude -p "/code-review medium"` as the `code-review` preset specifies, five times, fixing
everything between rounds. It returned **9, 7, 6, 8 and 10 findings with not one recurrence among the
40**, and **every one was a real defect in this release's own new files**. **Every round after the
first found defects the previous round's fixes had introduced** — a stale claim left by a changed
rule, a rule interaction created by a fix, a truncation created by a budget, and a permission bypass
created by a grant.

**The run reached the local `--max-rounds` built-in of 5 without converging, with the last round
returning more than any before it.** That is the same outcome `.revloop/field-notes.md` records three
times for the remote reviewer, reached here in a fifth of the wall clock by a different reviewer.
**So "the reviewer eventually runs out of things to say" is not what ends either loop** — which is the
argument for `--accept-at` restated as a measurement rather than as a worry, on the release that adds
it. No run under the floor has been made yet, so whether it ends this one is the open question.

**The sample also corrected a premise this release was built on.** "A local round returns at once"
was written into the procedure, the design notes, the schema and both READMEs before anything was
measured, and it is false: the five rounds ran 5m27s to 8m39s, inside the remote reviewer's own
2:46–10:07. The
wall clock is not what separates the two loops. **What a round spends is** — and the local one spends
tokens, which nothing in the room displays. Every rule that had rested on "there is no cost to
notice" now rests on "the cost is invisible", which is the argument that was actually true.

**The sample contradicted the card it was written from, in two places.** The shape that came back was
neither shape read out of the binary, and round 1 returned nine findings where the documented cap for
that effort level is eight. **A card written from a declaration is a card that can be wrong**, which
is the limit `reviewers/README.md` now states for the artifact provenance form — demonstrated on its
first use, by the artifact it was added for.

**Both contradictions are the case `unparsed-review-output` exists for.** A parser written from the
declarations would have matched neither run, returned zero findings, and been read as a clean review.
That abort row was written before the sample and is the reason the sample cost nothing.

Changed:

- **Step 1 of the pull-request loop now aborts on a `local-command` reviewer, under its own reason.**
  Such a reviewer has no `trigger`, so the run already stopped — at `no-comment-trigger`, which names
  a missing field when the cause is a reviewer built for the other loop. `reason=not-a-github-reviewer`
  says which, and names the command that does drive it.

- **Step 12's report rule now has a no-ladder case, which the hardcoded-rung fix had not.** Replacing
  the literal `P1` with "the ladder's top rung" is correct for the three cards that carry a ladder and
  leads with nothing for `claude.md`, which carries none. With no ladder it leads with everything left
  unfixed.

- **Three tests now read every procedure in `commands/`, not the first one that existed.**
  `tests/permissions.test.sh`, `tests/fence-guards.test.sh` and `tests/procedure-refs.test.sh` each
  named `commands/review-loop.md` outright, so a second procedure would have been exempt from the
  granted-command check, the `allowed-tools` check and the line-number-citation check — **which is the
  same drift those files exist to catch, one level up**. The list is globbed rather than written out
  for that reason, and an unexpanded glob is failed on explicitly, because awk over a path that does
  not exist prints nothing and every subset check reads that as "no commands used". The marker guard
  stays scoped to the one procedure that posts a trigger; globbing it would report a missing marker as
  a defect in a file that posts none.

## [0.4.0] - 2026-08-31

**No fence changed, so nothing here asks anything of you.** The three shell fences in
`commands/review-loop.md` are byte-identical to 0.3.0 and still match the
hashes in `tests/fence-hashes.txt` — `tests/fence-guards.test.sh` reports all three matching, which is
the evidence for this paragraph — so there is **no re-approval to give**. The granted rule list in
[`docs/permissions.md`](docs/permissions.md) is unchanged too: the two new reads use
`gh api --paginate repos/{owner}/{repo}/`, a prefix the procedure already used and you already
granted, and `tests/permissions.test.sh` checks that in both directions. None of this is luck. The
re-post rule could have lived inside the wait fence, and putting it there would have cost every user a
Bash prompt for a rule a reader of step 9 can follow unaided; counting wait chunks against `--timeout`
was already the caller's job for exactly that reason.

Added:

- **A trigger that draws no verdict the loop can classify is now posted a second time, once.** The
  failure: a trigger comment is delivered, nothing the loop classifies comes back, and the round dies
  with the pull request, the diff and CI all healthy. (**"Classified" is the operative word** — a
  signal orphaned in the re-post gap leaves the round looking silent when it was not.) Step 8 returned
  `VERDICT=pending` until the budget ran out and step 9's table said `abort` — no path in the
  procedure sent the request again. Step 7 now carries one narrow
  exception to the runaway invariant, with five conditions that are all checkable from GitHub: the
  wait must have expired **and have spent at least three chunks watching your own trigger**, the
  `pending` line's baseline must be yours by both halves of the ownership test, no marker may already
  carry this round's `round=` with an `attempt` key, the round must have produced no classified verdict
  at all, and HEAD must not have moved.
  A rate-limit reply keeps its own row and that row still says **do not retry**; silence is the only
  signal the exception answers. The exception is carved **out of** step 9's exceeding-`--timeout`
  abort rather than standing beside it, so exceeding the budget always terminates the attempt and a
  round ends in at most two of them: written as several conditional aborts it left a hole, where a
  newer hand-typed trigger made every later `pending` a "continue" while blocking the re-post, and the
  caller polled forever.

  **The floor is three chunks — 24 minutes — and it is deliberately not a fraction of `--timeout`.**
  Deriving it from the flag was the first design and it is wrong: `--timeout 8m` would then re-post
  from inside codex's measured 2:46–10:07 range, which is the runaway the invariant exists to prevent,
  reachable by typing a flag. A fixed floor in the unit the caller already counts cannot be pushed
  below the measured ceiling by any flag value. Twenty-four minutes is about 2.4× the widest verdict
  ever measured, which leaves headroom on a card that records **every sample so far widening that
  range at one end or both**. Below the floor there is no re-post and the round aborts exactly as it
  did before, under a new reason, `timeout-before-retry`, that says so rather than blaming slowness.

  **The direction is the safety argument.** A re-post moves the baseline **forward**, so it can only
  reach the too-new row of the table in [`docs/design-notes.md`](docs/design-notes.md) — a verdict that
  arrived is dropped, a liveness failure for every class except the two abort-class comments, where
  ending clean rather than stopping makes it a safety one. It cannot reach the too-old row, where a previous round's
  "no issues" becomes this round's clean verdict. That makes it the mirror image of the refinement that
  document rejects — walking the baseline back to an older trigger — rather than a quiet
  reintroduction of it.

- **`attempt=` joins the trigger marker, and adding it cost no fence edit.** The fence parses the
  marker with a `case` over `key=value` pairs and has no default branch, so a key it does not know is
  skipped, and the jq program's character filter passes `attempt=2` through untouched. Both halves are
  now pinned rather than asserted — `tests/fixtures/verdict/retry-marker` through the shell, and the
  same fixture through `tests/jq-program.test.sh` for the filter. No fixture previously carried a
  marker with anything but the five documented keys — `v`, `reviewer`, `bot`, `head`, `round`, of which
  the fence parses the last four by name — so an unknown key was entirely unexercised.

  **The key is written only on a re-post.** Writing `attempt=1` on every trigger was the first draft
  and it is a cost with nothing bought: `reviewers/codex.md` records the marker being tolerated end to
  end against the five-key body, ten consecutive times, so a sixth key on every round would move every
  round onto a body shape nobody has watched a reviewer accept — to record a `1` that its absence
  already says. Confining it to the re-post also keeps the round count a presence test on one key
  instead of a comparison against a number, where `attempt=1` versus `attempt=10` is the input-space
  trap step 10 spends a paragraph on.

  **`v` stays at `1`, and step 7 now says when it would move**: only when an existing key changes
  meaning or disappears — when a reader of the old format would misread the new one. Adding a key does
  not qualify. That criterion did not exist before, which is the only reason the question was open;
  spending the version signal on an additive change teaches the next reader that `v` moves for
  anything, and makes a genuinely breaking change indistinguishable.

- **Step 7 shows the command it has always prescribed.** "Count the markers from GitHub" had no block
  behind it, which is the prose-prescribed-command drift `tests/permissions.test.sh` was written after
  finding three times over. One `--paginate` read now yields all three facts step 7 needs: the round
  number, whether this round has already been re-posted, and — on a run resuming in a fresh session —
  the `SINCE` steps 8 and 9 reconcile against. **`SINCE` on a resumed run was undefined**; both steps
  said "the `SINCE` you recorded in step 7" and a session that died recorded nothing. It is now the
  `created_at` of the newest marker on the pull request.

  The read filters `.user.type != "Bot"`, which is the fence's own `__typename != "Bot"` rule spelled
  for REST. Without it the read would be a second implementation of "who may anchor a trigger" that
  disagrees with the first: a bot quoting the marker literal would inflate the round number, and a bot
  body carrying `head=` and `attempt=` would satisfy the re-post condition and **suppress a re-post
  the round was owed**. The two spellings were measured on `iwmaeda/revloop#11` (2026-08) —
  `chatgpt-codex-connector[bot]` is `type=Bot`, `iwmaeda` is `type=User`. This was found by the
  definition sweep the procedure's own step 3 prescribes, before the reviewer saw the change.

Fixed:

- **A round that fires twice can be answered twice, and one of the two answers was being dropped.**
  This is the sharpest thing the re-post changes and nothing pre-existing caught it. If both reviews
  land before the retry chunk's first poll, the fence returns the newer one and never mentions the
  older — there is no `EXTRA=` for a second review, only for a comment — and step 10's filter is an
  equality test on that single `review_id`, so the other review's findings are lost for the life of the
  pull request, since the next round's baseline is newer than both. Step 9's "commit is an ancestor of
  HEAD" row cannot catch it: **both reviews name the same, current commit.** Step 10 now reads every
  review by the reviewer at the current HEAD, at or after the round's first trigger, on a two-trigger
  round, and fails closed if that read
  fails, because REST 404s for many minutes while GraphQL keeps answering and an empty result is
  indistinguishable from "only one review". `tests/fixtures/verdict/retry-both-answered` pins the fence
  returning one of two same-commit reviews with no signal that the other exists.

- **Step 8's `SINCE` reconciliation was unbounded, and could never terminate.** "If they differ,
  discard that verdict and re-fire step 8" has been in the procedure since before this change, and it
  has no bound. A mismatched **verdict** exits the fence on its **first** poll, so it burns no wall
  clock and accrues no chunk — which means that against a baseline that is permanently newer and
  already answered, such as a hand-typed trigger posted after yours, the re-fire never reaches
  `--timeout` and never sleeps. A mismatched `pending` is the other shape and does spend its chunk, so
  neither can be bounded on the clock: the first never reaches it, and the second would make the bound
  depend on what somebody else posted.
  That is the infinite loop `## Notes` names for the fence, reached from the caller instead. It was
  the last unbounded re-fire in the procedure; every other one already reads "once" or "a second time
  aborts". It is now two consecutive mismatches, then `reason=foreign-baseline`, and a matching
  `trigger=` resets the count. The rule also now covers `review`, `comment` and `reaction` explicitly
  rather than only a verdict: all four are treated as `pending` so step 9's rows decide, which is the
  same "one exception, one catch-all" shape as above.

- **The runaway invariant and step 9's `marker_head=none` recovery contradicted each other.** That row
  says to fire revloop's own trigger in step 7, at an unchanged HEAD — which the invariant, as this
  change first restated it, forbade. The premise is what the invariant actually protects: it bars a
  second trigger while one of yours can still bind a verdict. Two states end that premise, and **only
  one of them is recovered inside the run**: no verdict of yours classified, which is the re-post with
  `attempt=2` and the same `round=`. A newer trigger taking the baseline **aborts** — an abort is a
  stop, and the loop must not race a person for the newest comment, which is the runaway itself — and
  a later run re-takes the baseline with an **ordinary** trigger that advances the round, because the
  wait it replaces was spent. Getting this wrong the other way was itself caught in review: an earlier
  draft classified the lost baseline as an in-run recovery, which contradicted "an abort is a stop"
  in nine places at once. `marker_head=none` and `reason=foreign-baseline` now both read "report and
  finish", and so does `error reason=no-branch`, which had the same shape before this change.

- **A two-trigger round could finish clean without ever running the review sweep.** The sweep lives in
  step 10, which the table reaches from `VERDICT=review`, so a round whose terminal signal was a
  clean **comment** or a reaction went straight to step 12 — which is precisely the case the sweep
  exists for. A review of the current commit orphaned before the re-post was then never read, its
  findings never replied to, and with `--auto --merge` the loop merged on the second trigger's clean
  signal while an unread review of that same commit sat on the pull request. That is one of the two
  ways the re-post path could produce a wrong merge, and the only one closed here; the other is an
  orphaned abort-class comment answered clean on the second trigger. Step 9 now gates every clean
  finish on the sweep,
  because step 9 is the only place both the clean path and the findings path pass through. A
  single-trigger round is unaffected: there is no second answer to miss.

- **The lost-baseline recovery was unreachable after a restart, which made the abort permanent.** Step
  7's marker read selected only comments carrying the marker, so it could not see the hand-typed
  comment that took the baseline. A resumed run at unchanged HEAD found only its own marker, concluded
  the runaway invariant blocked it, waited, reached `reason=foreign-baseline` again and aborted —
  forever, with the recovery the entry above promises unreachable. The read now returns every non-bot
  comment and marks the unmarked ones, and step 7 says what to do with a newer one: **ask the fence**,
  by firing step 8 once and reading its `trigger=`, rather than replaying the fence's compatibility
  pattern outside it. That pattern under-matches custom triggers into the same deadlock and
  over-matches into licensing an extra trigger, so neither direction of guessing is available — which
  is the same reason the round number does not count hand-typed rounds.

- **Baseline ownership was decided by a second-resolution timestamp.** The fence sorts triggers by
  `createdAt` and, within a second, by `databaseId` — a tie-break this repository added in 0.3.0 and
  pinned with its own fixtures, because two triggers in the same second are a different input from two
  a second apart. Every ownership test this change introduced compared `trigger=` alone, so a
  hand-typed comment posted in the **same second** as the marker with a larger id wins the baseline
  while reporting a timestamp identical to yours: the lost-baseline recovery then never runs, and the
  re-post condition that exists to keep a retry off a foreign baseline is satisfied anyway. The test is
  now both halves — the timestamp, **and** no non-bot comment sharing that second with a larger id —
  and both come out of the read step 7 already performs, so nothing classifies a comment as a trigger
  outside the fence. Step 9's check (c) additionally compares `round=`, because a verdict line carries
  the winning marker's own fields and can say outright which trigger won.

  **A round that only ever sees `pending` under an unclaimable baseline aborts and is handed to a
  human**, and that corner is deliberately not auto-recovered: a `pending` line carries no marker
  fields, so closing it would mean teaching the fence to emit them — a re-approval for every user,
  against a case that needs a same-second collision to reach.

- **The retry budget was searched for as a substring, so `round=1` matched `round=10`.** The rule that
  decides whether this round has already spent its re-post said "substring search" in as many words,
  which means a marker from round 10, 11 or 100 satisfies a search for round 1 and the round is refused
  a re-post it was owed. This is the `attempt=1` versus `attempt=10` trap the procedure already names
  for a predicate's input space, reintroduced in the rule that spends the budget. Both the budget check
  and the round count now split the marker payload on whitespace and compare whole `key=value` tokens.

  The related read was checked and **deliberately left alone**: the marker scan selects on
  `contains("revloop:trigger ")` because that is exactly what the fence's own `TRIG` generator does, so
  a human comment quoting the literal anchors a baseline whatever this read thinks. Making the read
  stricter than the fence would be a second implementation of "what is a trigger" that disagrees with
  the first — the defect class this branch already fixed once. Agreement is the requirement; parsing is
  where the care goes.

- **Step 10's review sweep excluded a review sharing its second with the round's first trigger.** These
  timestamps have second resolution and the bound was strictly "after", and the two ways of being wrong
  are not equally bad: including a review that shares the second costs a re-read of findings that may
  already be answered, while excluding one drops a review of the current commit on the path that
  merges. The bound is now inclusive.

  What is **not** a hazard, and was checked rather than assumed: a review racing a clean comment. The
  fence returns a review whenever one exists **and is strictly newer than the trigger**, and demotes
  the comment to `EXTRA=`, so a clean comment cannot outrank findings that arrived after it. A review
  sharing the trigger's own second is the exception and is a known gap; see `## Notes`.

- **Two lookups were keyed on `head=` where they had to be keyed on the round.** Both became wrong the
  moment the lost-baseline state was allowed to open a **new** round on an unchanged HEAD, which is a
  consequence of this same branch. The re-post bound searched the pull request for any marker with
  this `head=` and an `attempt=`, so a previous round's re-post spent the new round's budget and
  reported `attempts=2` for a round that had sent one trigger; it now matches on this round's `round=`,
  and an unparseable marker counts as a match, because withholding a second trigger is the safe
  direction. Step 10's two-trigger read took every review whose `commit_id` was HEAD with no lower
  bound, so it swept in the previous round's reviews of the same commit and re-opened answered
  findings; it is now bounded below by the round's first trigger. The second was found by sweeping the
  class rather than by review.

- **Step 10's two-trigger sweep compared two values that can never match, so it swept up nothing.**
  The read emitted REST's `user.login` and `commit_id` raw and then asked for the reviewer's login and
  HEAD. REST carries the `[bot]` suffix the marker's `bot=` has stripped — the mistake `## Notes`
  records as having shipped once already — and `commit_id` is the full 40-character sha, while every
  other HEAD comparison in this procedure is the short-8 form the fence writes. Either one alone
  matches **zero** reviews on every run, and zero is indistinguishable from "only one review": the
  sweep this branch added would have reported nothing, the round would have finished clean, and
  `--auto --merge` would have merged past findings nobody read — silently reintroducing the defect the
  sweep exists to fix. Both fields are now normalized in the read itself, mirroring the fence's own
  `BOT=${BOT%"[bot]"}` and `.commit.oid[0:8]`, so the value the reader is handed is the comparable
  one. The fail-closed rule now names **both** reads rather than only the list: a failed per-review
  `comments` read is indistinguishable from "that review had zero inline comments", which is a clean
  review, and it runs once per review, so a two-trigger round takes that risk twice.

- **Step 7's new marker read had no failure rule, on the one endpoint this procedure says 404s.**
  `## Notes` records `repos/…/issues/<n>/comments` returning 404 continuously for many minutes while
  the same token's GraphQL kept answering, and an earlier REST-based wait reporting a pull request
  carrying 22 triggers as `no-trigger` — the wait is built on GraphQL for that reason. The new read is
  that endpoint. An empty result read as "no markers" restarts the round number at 1, hands the
  re-post condition an empty pull request and so refunds a budget the round has already spent, and
  leaves `SINCE` with no left-hand side. Failure is now decided from `gh`'s exit code alone, the way
  step 8 already decides it, and a failed read means do not fire and do not re-post.

- **"This round's `round=`" was undefined on a resumed run, which is the only run the bound matters
  on.** The procedure defines the round number once, as the count of round-opening markers plus one —
  a count that deliberately excludes a re-post. A session that died mid-wait therefore came back and
  computed N+1 for a round still at N, asked the re-post condition about a round that did not exist,
  found no `attempt=` marker, and re-posted a second time; the session after it would have done the
  same, because the marker it should have found is the one the count excludes. The whole bound rests
  on that condition — "it cannot re-post twice, because it reads that from the PR" — so this was the
  guarantee failing exactly where it was claimed. A resumed run now takes this round's number from the
  newest marker, the same marker `SINCE` already comes from, together with whether the round has been
  re-posted and which comment is its first trigger. This is the `SINCE` gap above, one field over, and
  it was left standing when that one was closed.

- **What a reconciliation mismatch costs was stated three ways, and the absolute one was wrong.** Step
  8 said a mismatch "burns no wall clock and accrues no chunk", while its own chunk-counting paragraph
  and step 9's table both said the chunk counts toward `--timeout`. The two are right about different
  inputs: a mismatched **verdict** exits the fence on its first poll and costs nothing, but a
  mismatched **`pending`** means the foreign trigger is itself unanswered, so the fence polls out all
  480 seconds before printing — and that is the only other shape a mismatch arrives in. Neither may be
  bounded on the clock, which is what the two-consecutive-mismatch rule is for. The false half had
  been copied into this changelog as well, and is corrected above. **Only step 8's re-fire paragraph
  and this changelog were corrected then**; the two normative statements named in the sentence above
  kept the absolute rule, and the entry below closes them.

- **The list of what the re-post gap can drop named two comment classes; there are four.** The window
  between an expiring chunk's last poll and the new trigger loses any signal landing in it, and the
  sweep recovers only reviews — it reads `pulls/<n>/reviews` and never comments. The accepted-cost
  argument, that the behaviour being replaced is an abort which loses the same signal **and** the round
  with it, holds for a clean verdict and a rate limit, because both repeat themselves. **It does not
  hold for the two abort-class rows.** An unrecognized bot body and an `interim-loop` exist to stop the
  loop and hand it to a human; losing one used to end in an abort anyway, but now, if the second
  trigger answers clean, the round finishes clean and merges. That is strictly worse than what it
  replaces and it is the one cost of this path that is not offset. It is written down rather than
  closed: closing it would mean classifying comments outside the fence, a second implementation of a
  rule the fence owns, which is the defect class this branch has already reported twice. The report
  now says a signal may have been orphaned on **any** two-trigger round, not only on `no-verdict`.

- **Two of this branch's own new tests could not fail for the reason their comments gave.**
  `fence-guards` checked each required marker key with a substring match, so a marker whose `head=` had
  been typo'd to `marker_head=` satisfied the test while parsing to exactly the `marker_head=none` the
  block exists to catch — the guard going green on its own failure case, by the same
  substring-for-token mistake the procedure states a rule against twice. It is anchored to a token
  boundary now. `fence-verdict`'s `retry-baseline` comment claimed its assertions pinned that a re-post
  does not advance the round; they cannot, because both triggers carry `round=3` by hand and the fence
  has no round-counting logic to get wrong. That comment now claims only what the assertion checks, and
  says plainly that the rule itself lives in prose this harness does not execute.

- **The mismatch-cost split was written in the paragraph that explains it and in neither that
  instructs.** The round before this one named three statements of what a reconciliation mismatch
  costs, worked out that they are right about different inputs, and then corrected one of them and
  this changelog. The two it left are the two a reader follows as instructions: step 8's
  chunk-counting paragraph and step 9's foreign-baseline row both still said flatly that the chunk
  counts toward `--timeout`. A mismatched **verdict** exits on the fence's first poll and spends no
  wall clock, so charging it a chunk overstates the wait by eight minutes each time — two instant
  foreign verdicts followed by two real `pending` chunks are charged the four chunks that stop an
  attempt at the built-in `30m`, so the round aborts its own trigger having actually waited sixteen
  minutes rather than thirty-two. Both now carry the split, and both keep the half that was never in
  doubt: a mismatch watched somebody else's baseline, so it never counts toward step 7's floor and
  can never authorise a re-post. **The class was named too narrowly rather than missed** — the
  previous entry's own first sentence lists all three sites — so it is recorded here as one fix
  applied at every site that states the rule, and the sweep that found them is a grep for the rule
  rather than for the wording.
  `docs/` states the floor and the budget arithmetic but never what a mismatch costs, so nothing
  there needed the same edit.

- **The same narrative-versus-normative split ran through four more rules, across seven files.** Asked
  to list every sibling of the class above rather than the first, the reviewer returned four sets, and
  all four held up against the text. **(1) The runaway invariant admits two firings at an unchanged
  HEAD, not one.** The silence re-post is recovered inside the run; the lost-baseline re-take is
  performed by a later run, once it can establish the baseline is foreign. Step 7's opening imperative,
  the `## Notes` bullet calling silence "the single exception", and `.agents/skills/revloop/SKILL.md`
  all admitted only the first, so following them literally prevents the recovery the same documents
  prescribe. **(2) "Never answered" overstates what the loop knows.** The operative condition is "no
  classified verdict", and a signal can be orphaned in the gap between an expiring chunk's last poll
  and the new trigger, so silence is what was _seen_ rather than what was _sent_. Step 7's prose, the
  re-post section, the field-notes sentence, step 9's re-post row, both READMEs and
  `docs/design-notes.md` all claimed literal silence. **(3) Exceeding `--timeout` does not always
  terminate the round**, only the attempt; the round ends in at most two. **(4) The re-post path can
  reach a wrong merge, and four places said otherwise** — the `## Unexercised paths` preamble claiming
  every listed branch fails closed "never toward a wrong merge" while listing the re-post,
  `docs/design-notes.md`'s too-new row and its "spends nothing it was not already spending", and
  `docs/configuration.md` calling 64 minutes "the whole cost". The procedure's own cost paragraph
  already says the opposite for the two abort-class signals: losing one used to end in an abort, and
  now a clean second answer can finish the round and merge past it. Every normative copy now carries
  the distinction its explanatory paragraph already required. **No behaviour changed and no fence
  changed** — this is the wording that instructs being brought level with the wording that explains.

- **Closing four sets left five more, two of them opened by the previous round's own edit.** The same
  request, repeated once the first four were closed, returned: **(1)** three places still saying step
  10 is reached only from `VERDICT=review` — step 9's pre-table gate, this changelog, and a comment in
  `tests/fence-verdict.test.sh` — when the gate that paragraph introduces is exactly what now routes a
  two-trigger clean comment or reaction into the sweep; **(2)** `docs/design-notes.md` crediting an
  orphaned review's survival to the reviewer answering the second trigger and to `commit=` pinning it,
  neither of which is guaranteed, when what recovers it is step 10's round-bounded sweep; **(3)** two
  copies still calling the missed-review case "the one way" the re-post could cause a wrong merge,
  which the abort-class orphan path contradicts; **(4)** the runaway invariant's bolded imperative
  still reading "fire only when HEAD differs" three lines above the sentence saying two firings at an
  unchanged HEAD are correct; and **(5)** `## Notes` and `SKILL.md` prescribing "every review at HEAD"
  without the configured-reviewer filter the operative rule in step 10 carries, which would sweep
  another bot's findings into this round's replies. **(3) and (4) were introduced by the previous
  round's fix** — it added each qualification next to an absolute statement it left standing, which is
  the same one-member-of-the-class failure that round was fixing. Sweeping the three shapes across the
  tree afterwards found **two more the review had not cited**, both in the same `## Notes` bullet: the
  stale control flow again, and an unfiltered "any review whose commit is HEAD". No behaviour and no
  fence changed.

- **Two of the next four were control flow, not wording.** **(1)** Step 9's pre-table check (c) said to
  abort whenever `marker_head=` or `round=` differs, which is true **only once the baseline is yours**:
  a foreign baseline carries a different `head=` and `round=` as a matter of course, so a reader
  performing the checks in order aborted on the first mismatch and never reached the
  "continue (twice)" reconciliation the table promises. (c) is now explicitly conditional on (b).
  **(2)** Step 10 opened with "step 8 already emitted `review_id=`", which the clean-comment and
  reaction gate had just made false — those rounds reach step 10 with no review id at all, and the
  ID-keyed query returns nothing. Step 10 now names both entries and sends the gated one straight to
  the two-trigger sweep. **(3)** Four more copies of the literal-silence claim sat beside the
  "no classified verdict" qualification. **(4)** The too-new drop was still classified as a liveness
  failure in three places, including the class column of the `docs/design-notes.md` row whose
  consequence column the previous round had already corrected — the same fix-one-column failure, one
  column over. It is a liveness failure for the classes that repeat or are recovered and a **safety**
  failure for the two abort-class comments, which end clean rather than stopping. Sweeping afterwards
  found one more the review had not cited: a comment in `tests/fence-verdict.test.sh` still carrying
  the unqualified "it is accepted" argument. No behaviour and no fence changed.

- **P1: the ordered pre-checks made the whole re-post path unreachable.** Step 9 said to "check five
  things before consulting the table", and the five were written as though every verdict carried every
  key. The fence does not work that way: `VERDICT=pending` emits only `pr=`, `trigger=` and `waited=`,
  so **(c) and (d) could not be satisfied by any `pending` line at all** — and read literally that is
  an abort on the first silent chunk, before either `pending` row is ever reached. The re-post this
  branch exists to add was unreachable, and so was plain "continue". The same mismatch reached three
  more forms: `reaction` carries no `login=`, so (d) stood between it and its clean row; the error
  forms carry neither `trigger=` nor a marker, so they aborted at the wrong check and reported the
  wrong reason rather than landing on their own rows; and on a compatibility baseline the marker
  carries no `bot=`, so the fence's filter admits any bot and (d) could classify a lost baseline as
  "another bot's verdict" — an abort either way, but one that loses the lost-baseline row's promise
  that a later run re-takes the baseline. Each check now names the forms it applies to, as (e) already
  did, over a table of which form emits which key; `marker_head=none` is given precedence over the
  login check in both the check and the table row. **The fence was already right** — this is the
  caller's reading of it being corrected, so no fence changed and no re-approval is owed.

- **P1: four more reads of values their producer does not always supply.** Read against the fence text
  rather than the prose: **(1)** "always reconcile the returned `trigger=`" applied to every output,
  but no `VERDICT=error` form emits `trigger=`, so an auth or connectivity failure was sent into the
  foreign-baseline retry instead of onto its own row; it is now scoped to the four forms that carry
  one. **(2)** The fence takes every review that is not `DISMISSED` and then drops the state from its
  output, and step 10 repeated the same rule — which admits a `PENDING` draft, a review with no
  findings and no `submitted_at`. Step 10 excluded `PENDING` explicitly at this point — **superseded
  two entries below**, where excluding it in the selection turned out to drop the very review whose
  state should stop the round; step 10 now keeps it and lets the state table abort. **(3)** "A clean comment
  cannot outrank findings that arrived in the same round" was stated in the procedure and in this
  changelog, but the fence selects reviews with `$2>t`, so **a review sharing the trigger's own second
  is not selected at all** and a later clean comment wins the round. The trigger selection solves that
  collision with a `databaseId` tie-break; the review selection has no equivalent. Both copies now say
  "strictly newer" and name the gap, which is recorded rather than closed because closing it is a
  fence edit. **(4)** "`MERGE=failed` means the PUT was fired and did not take" was stated in the
  procedure and in `SKILL.md`, but the fence also prints it when the post-PUT status read **fails** —
  `ST` is empty then, which a successful merge can also produce. Both now say the fence could not
  confirm it took, and say to read the pull request rather than re-fire. No fence changed.

- **A review arrived with zero inline comments and a P1 in its body, which two rules said was
  impossible.** Step 10 opened "a review body is boilerplate or empty; the findings are inline review
  comments", and step 9's table read a review with zero inline comments as a clean finish. Measured on
  this pull request's round 16, codex returned a `COMMENTED` review on the current commit whose
  `pull_request_review_id` matched **zero** rows in `pulls/<n>/comments` and whose body carried a
  complete P1 with a severity badge. Counting inline comments would have reported that round clean and,
  under `--auto --merge`, merged past it. Step 10 now reads the body as well as the comments and treats
  a body carrying a severity badge as findings; the table row is "not clean by itself"; and
  `reviewers/codex.md` records the observation as a tendency rather than a contract. **This was found
  by reading the body before acting on the count, not by the count.**

- **The `PENDING` exclusion had been added to one of the two paths.** The previous round excluded
  `PENDING` from step 10's two-trigger REST sweep and left the single-trigger path with nothing — the
  wait fence admits every review that is not `DISMISSED` and drops the state from its output, so a
  draft reaches `VERDICT=review` indistinguishable from a submitted one. Step 10's new body read
  doubles as the state check. Four prose/fence mismatches closed alongside it: step 12's text said
  everything that is not a pass "falls back to `retry`" when a fifth consecutive fetch failure is
  `CI_WAIT=error` and a completed failure is `CHECKS_FAILED`; `## Notes` forbade terminal exits for
  continue rows when the fence exits for **every** review including the ancestor row, which is bounded
  by the caller's one re-fire rather than by the fence; `## Notes` said every fence resolves the
  branch first when `wait-verdict` reads `gh repo view` first and can exit before the branch is
  looked at; and step 12 asked for the merge response body on every non-`ok` result when an abort
  exits before the PUT and has none. No fence changed.

- **Three P1s, all of them made by the fix in the entry above.** **(1) The body read went to one path
  again.** The two-trigger sweep returns metadata and then reads inline comments per `id`, so the
  direct review's body was the only body ever fetched — and the sweep is the **only** reader for a
  review orphaned in the re-post gap, and the only reader at all on a round entering step 10 from the
  clean-comment or reaction gate. The measured body-only finding was therefore still dropped on
  exactly the two paths that exist to recover it. The sweep now reads each selected review's body and
  state alongside its comments. **(2) The new `PENDING` handling was an infinite loop.** It said to
  treat a draft as `pending` and re-fire step 8; the fence keeps every non-`DISMISSED` review and
  exits on its **first** poll, so each re-fire re-selects the same draft with no wall clock spent, no
  chunk accrued and nothing bounding it — the exact loop `## Notes` names, introduced two paragraphs
  after the note that names it. `PENDING` now aborts with `reason=draft-review`, because a draft stops
  being one only when its author submits it. **(3) The state check enumerated one state and let the
  rest through.** `CHANGES_REQUESTED` with no inline comments and a body without a severity badge was
  read as clean and merged, though the state itself says otherwise; so was any state GitHub adds
  later. Step 10 now has a state table: `COMMENTED` and `APPROVED` are read for findings,
  `CHANGES_REQUESTED` **must** produce findings or abort, `PENDING` aborts, and an unrecognised state
  aborts with `reason=unknown-review-state`. No fence changed.

- **The two readers are now one read, because splitting them failed twice in opposite directions.**
  The round before last gave the direct path a body read and left the sweep reading comments only;
  the fix for that gave the sweep a body read and left it reading **only** that — so on a round
  entering step 10 from the clean-comment or reaction gate, where the direct query is skipped, an
  inline-only finding on an orphaned review was never loaded. One half missing on each path, one
  round apart, each introduced by the fix for the other. Step 10 now states **the per-review read**
  once — body and state, plus inline comments — and both paths invoke it by name on whichever `id` is
  in hand, rather than restating half of it each. The fail-closed rule covers both halves, and its
  reasoning is corrected too: it still said an empty `comments` read looks like "zero inline comments,
  which is a clean review", which stopped being true when zero inline comments stopped being clean.
  **Two of the three shapes this round asked about came back with no instances** — the state table's
  stop default holds, and every retry bound is stated where its retry is. No fence changed.

- **The sweep filtered out exactly the reviews whose state was supposed to stop the round.** Its
  selection read "the reviews whose `state` the table above does not abort on", which looks like an
  application of the state table and is its inverse: a `PENDING` or unrecognised review was **removed
  from the sweep instead of aborting**. On a two-trigger round whose second trigger came back clean,
  the reviews saying "do not finish" were the ones discarded and the clean path merged — the stop
  default defeated by running the selection before the check it defaults to. The selection now
  narrows by **identity only** — login, commit, round — drops `DISMISSED` alone, and hands every
  surviving review to the state table. A second hole in the same selection is closed with it: a
  `PENDING` review has no `submitted_at`, so the "at or after this round's first trigger" bound
  discards it too. The bound now applies only to reviews that have a timestamp, and a review by the
  reviewer at HEAD with none is a draft that aborts. No fence changed.

- **One copy of the superseded `PENDING` rule was left in `## Notes`.** The entry above changed step
  10 from excluding a draft review to keeping it and letting the state table abort; the note
  describing the same gap still read "step 10's own read excludes those explicitly". Following that
  copy reinstates the defect the entry above fixed — on a two-trigger round whose second trigger
  returns clean, the stopping review is dropped from the sweep and `--auto --merge` proceeds. The note
  now says keep, says why a selection that drops the stopping review defeats the stop, and records
  that its own earlier wording was the last instance of that mistake. **This was round 20, the run's
  cap: the fix is committed but no review round has seen it.** No fence changed.

- **Ten more latency samples, and the range's low end moved.** `iwmaeda/revloop#13` rounds 11–20 ran
  4:21, 4:18, 4:46, 3:51, 7:25, 6:57, 5:42, 4:55, **2:46** and 3:21 — trigger `createdAt` to review
  `submittedAt`, as the earlier samples were timed. Twenty-seven rounds in this repository now span
  **2:46 to 10:07**. `reviewers/codex.md` carries the sample, and the three operative copies of the
  figure — step 7's floor rationale, step 9's runaway argument, and both READMEs — are updated with
  it. **The three-chunk floor is unchanged and its derivation still holds**: it was chosen as roughly
  2.4× the **10:07** end, which this sample did not move. The card's "every sample has moved both
  ends outward" is corrected to "one end or both", since this one moved only the low end.

Changed:

- **`--timeout` now caps one trigger's wait rather than one round's.** A round fires at most two
  triggers, so its worst case is about twice the flag, rounded up to whole chunks each time: the flag
  is a threshold the chunk count must exceed rather than a stopwatch, so the built-in `30m` runs an
  attempt for 32 minutes and a re-posting round for **64, not 60**, where it used to be 32. That is the price of not
  losing a round to a single dropped comment, and `--timeout`
  is the dial that buys it back. Splitting the existing budget in half instead was considered and
  rejected: it judges a trigger dropped after 16 minutes, only 1.6× the widest measurement. The
  built-in value does not change, and neither does the schema — `"pattern": "^[0-9]+[smh]$"` already
  accepted every value this affects. [`docs/configuration.md`](docs/configuration.md) carries the same
  wording.

- **The round number now excludes re-posts.** It remains the count of `revloop:trigger` markers plus
  one, except that a marker carrying `attempt=` re-posts a round already open and is not counted.
  Without the exclusion a reviewer that drops one comment silently halves `--max-rounds`, which is a
  circuit breaker rather than a target and cannot afford to be spent on delivery failures. The count
  stays a one-line test anyone can reproduce, and it reads the marker's `attempt` key rather than
  searching the body: a raw search matches `notattempt=2` and a quoted `"attempt=2"` in a garbled
  payload, and either would undercount the round and suppress a retry it was owed.

- **The number of re-posts, and the silence threshold, are fixed and not configurable.** A budget above
  one has nothing measured behind it, and it spends the reviewer's quota — the same class as `--merge`,
  so not something the repository you happen to be standing in gets to raise.
  `docs/configuration.md`'s "deliberately not configurable" table says so, alongside the reason the
  threshold is not derived from `timeout`.

- **`reviewers/codex.md` no longer claims nothing in the loop depends on its latency figures.** That
  was true and is not: the three-chunk floor was chosen as roughly 2.4× the 10:07 end of the measured
  range, so a sample that widens that end is now a reason to revisit the floor. The card is still not
  read at runtime.

**This path has not been run against a live reviewer**, and `## Unexercised paths` says so. The
fixtures pin what the fence does with an `attempt=` marker, which trigger wins the baseline, what
happens to a signal orphaned between the two, and what the fence reports when both triggers are
answered — but no fixture can show that a reviewer answers the second trigger. The failure that
motivated the change is **reported rather than measured**: there is no PR, no date and no waited-for
duration to cite, so `reviewers/codex.md` gains no entry for it — a card claim with no source is worse
than no claim, and the only edit to that card is the correction noted above. Step 7 appends one line to
`.revloop/field-notes.md` on every re-post, successful or not; that is the sample that would turn the
floor from derived into measured. One thing checked and dismissed while writing this: the fence's
`comments(last:40)` window is a suffix, and a re-post adds one comment **before** the next verdict, so
the window is unaffected.

## [0.3.0] - 2026-08-25

**The `wait-verdict` fence changed, so every user owes one re-approval.** A fence is granted as its
own permanently identical command string, and this release edits that string; `wait-ci` and `merge`
are untouched and still match the hashes in `tests/fence-hashes.txt`. **There is nothing to
re-copy** — [`docs/permissions.md`](docs/permissions.md) is byte-identical to 0.2.0, so the granted
rule list is exactly the one you already have. The Bash prompt simply returns once, the next time the
loop reaches step 8, and approving it there restores zero prompts per round. That prompt is the point
rather than a cost of doing business: it is how you learn that the bytes you granted standing
permission to have changed. Nothing else asks anything of a reader who already installed 0.2.0 — the
command name, its flags, and the `.revloop.json` schema are unchanged.

Fixed:

- **wait-verdict fence: the baseline was chosen by position, not by time.** The fence's jq program
  builds one array from four generators, and array construction preserves generator order — so every
  compatibility (`compat=1`) row is emitted after every marker row, however much older it is. Taking
  the last `TRIG` row therefore selected the newest **hand-typed** trigger whenever one existed at all,
  rather than the newest trigger. On a pull request driven by hand before revloop was adopted those
  comments are permanent, so the baseline could never move forward. Measured on
  `MIRock-jp/hippoblogs#98` (2026-08): three hand-typed `@codex review` comments from one day and a
  revloop marker from the next produced `trigger=2026-08-24T04:13:01Z`, `marker_head=none`, and the
  **previous** round's review reported as this round's verdict. The cost was a skipped wait rather than
  a slow one — a review newer than an ancient trigger satisfies the exit condition on the first poll.
  Step 9's `SINCE` reconciliation caught it and the round failed closed, but no re-fire could converge,
  because the trigger that lost was revloop's own. Trigger rows are now sorted by `createdAt`, and
  within one second by `databaseId`, before the newest is taken; `LC_ALL=C` keeps a locale's collation
  out of it. Two consequences ride along: a compat baseline carries no `bot=`, and an empty `bot=`
  disabled the fence's bot filter, so a foreign bot's review could be read as the reviewer's — and step
  9's `marker_head=none` recovery, "let revloop fire its own trigger, then re-run step 8", now
  terminates instead of looping forever. The fence gained one utility, `sort`, alongside the `awk`,
  `grep` and `tail` it already used.

  The untriggered-verdict diagnostic had the same defect and is fixed in the same edit: it merged the
  review and comment generators, so `bot=` reported the newest **comment**, or a review only when no
  comment existed, never the newest signal. Diagnostic-only, and batched deliberately — fixing it later
  would have cost every user a second re-approval for a one-line improvement.

  **This changes fence bytes.**

  Verified against real data with the limit stated: `MIRock-jp/hippoblogs#98` is merged, so
  `gh pr list --state open` cannot resolve it and the fence could not be run end to end against it.
  Its real payload was fetched with the fence's own query and put through the fence's own jq program,
  which reproduced the inverted order; the fix was then applied to those real rows. The fixtures carry
  both representations — `graphql.json` for CI, where a real jq runs the program, and the recorded
  `rows` for machines without one, because the previous bug of this family was invisible to row-level
  fixtures.

  The `databaseId` tie-break is pinned by its own pair of cases, because the primary key decides every
  other case in the suite and would leave the secondary key unreachable: two triggers one second
  apart is a different input from two in the same second. Both orders are covered. With the sort
  removed, the first of the pair returns a **foreign bot's review as the reviewer's verdict** — a
  compatibility baseline carries no `bot=`, and an empty `bot=` disables the filter — so the two
  mechanisms compound, and `docs/design-notes.md` now records that they do. That document owns the
  baseline argument and stated the two failure directions without saying how "newest" is computed;
  it now says, and notes that the compatibility class anchors only while it is the newest trigger.

Changed:

- **The round number now says what it counts.** It remains the count of `revloop:trigger` markers plus
  one — the arithmetic is unchanged and no fence is involved — but step 7 and
  [`docs/configuration.md`](docs/configuration.md) now state that it counts revloop's rounds rather
  than the pull request's, so a pull request adopted mid-flight restarts at 1 while its commits and
  replies are already several rounds deep. Counting the hand-typed rounds too was considered and
  rejected: the compatibility pattern recognises a fixed set of reviewer names and matches no custom
  trigger at all, so it would trade a known undercount for an unknown one, and it would mean replaying
  a fence's classification outside the fence. Step 7 now requires both numbers to be named in the
  report and in the round's first reply whenever they differ.

## [0.2.0] - 2026-08-25

**No fence changed, so no re-approval is owed** — but **the granted rule list grew by one**, and
anyone who copy-pasted it needs to copy it again. Step 6 no longer runs `gh pr edit`, so
`Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` joins the list in all four places it is written. All
three fences still match the hashes in `tests/fence-hashes.txt`; `tests/fence-guards.test.sh` proves
it on every run.

Everything here came out of operating the loop on the previous release's own pull request, which ran
ten rounds and stopped on `--max-rounds` rather than on convergence. Three of these are defects that
review could not have found, because they are failures of the procedure as run rather than as read.

Fixed:

- **Step 6 told users to run a command that does not work.** Measured twice on `gh 2.4.0`, the
  version this procedure calls its verified floor: `gh pr edit <n> --body-file` exits 1 with
  `GraphQL: Projects (classic) is being deprecated … (repository.pullRequest.projectCards)` and
  leaves the body unchanged. The subcommand asks for that field to populate the pull request's
  current metadata and GitHub has retired it. The body now goes through
  `gh api -X PATCH "repos/{owner}/{repo}/pulls/<n>"`, which is not a new idea — it is why the merge
  already uses REST `PUT` and why CI status comes from `gh pr view --json`. The floor note used to
  say `gh pr create/edit --body-file` "all exist at 2.4.0"; **existing at the floor and working at
  the floor are different claims**, and it now separates them. `gh pr create` is left alone and
  **measured working** at the same floor (`iwmaeda/revloop#9`, 2026-08, exit 0) — it has no existing
  pull request to query, so it never reaches the retired field. That measurement was taken by this
  changelog's own pull request being opened, which is the cheapest experiment that was available.
- **The procedure prescribed an artifact that broke its own verify step.** `.revloop/field-notes.md`
  is git-ignored, but neither `.markdownlint-cli2.jsonc` nor `.prettierignore` excluded it, and the
  documented "one line per event" format runs past MD013 on the first line. Writing the field note
  the procedure asks for turned `npm run check:all` red. Both ignore lists now name **that file**,
  not the directory: excluding all of `.revloop/` would have let any other Markdown left there skip
  the checks, which is more than the collision needed.
- **`reviewers/codex.md` was stale in the file whose whole purpose is separating measured from
  assumed.** Its latency said 3–4 minutes; ten consecutive rounds on one pull request ran 3:04 to
  8:01, median 4:14, timed from each trigger's `createdAt` to its review's `submittedAt`. Both
  samples are kept and labelled, because the new one widens the range rather than replacing the
  centre. Its `## Not measured` still listed an end-to-end review with the marker attached, which
  those same ten rounds measure; that entry has moved into `## Measured` with its provenance. Both
  READMEs carried a copy of the latency figure and both are updated.

Added:

- **`tests/permissions.test.sh` now covers `gh api` as well as `git`.** A rule matches a
  command-string prefix and the flag precedes the path, so each verb needs its own rule — and the
  `-X PATCH` above arrived with none. The check is the same shape as the git half: extract from
  fenced blocks and compare, in both directions. `GRANTED` is read from the fenced `json` block alone rather than
  the page, because the prose names `Bash(gh api *)` in order to discourage it and a grep over the
  document would read that discouragement as a grant. A case pins that scoping. Verified by
  deleting the `-X PATCH` rule and watching the suite go red.

  **The extractor rejects rather than falls back, and it took three rounds to get there because the
  first two answers were the wrong shape.** Both matched a _method group_ and made it optional, so
  any line the group failed to recognise quietly became the bare form — which is granted. Each round
  then widened the alphabet and the next spelling walked straight through: `-XPOST`, then
  `--method PATCH` and a lowercase verb, then `-X  DELETE` with two spaces, `gh  api`, a tab, and
  `-X 'DELETE'`. **The alphabet was never the class. An optional group with a granted default is
  fail-open by construction**, and a permission check may fail closed and never open.

  So it now finds every line invoking `gh api` in any spelling, classifies each against the canonical
  forms alone, and treats anything unclassified as a failure — with the line count asserted equal to
  the number classified, so nothing can be dropped on the way to green. **The verb is matched as
  written, never normalised**: a rule matches a literal prefix, so `Bash(gh api -X PATCH …)` does not
  cover `-X patch`, and normalising would hide exactly that mismatch. Widening the alphabet is no
  longer how a new spelling is handled; rewriting it canonically is. Verified end to end by rewriting
  step 6 as `--method PATCH` and watching the suite go red.

  **The denominator counts invocations, not lines**, which a later round required twice over.
  Classifying one call per line with `head -1` let a second call on the same line go unseen —
  `gh api "repos/x" && gh api -X DELETE …` classified only the granted sibling — and a call split
  across a continuation (`gh \` then `api -X DELETE …`) matched no single-line pattern at all, so it
  was absent from the count rather than counted and rejected. Both fail now: the first as an
  ungranted verb, the second as a non-canonical invocation, each verified by putting it into the
  procedure and watching the suite go red.

  **It compares the whole prefix, scoped path included.** Matching only the verb let
  `gh api -X PATCH "users/example"` reduce to `-X PATCH`, which is granted — while
  `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` would not authorize that call at all. A rule is a
  whole prefix, and comparing half of one answers a question nobody asked.

  **And the direction is no longer one-way, because the reason it was is gone.** `git add` and
  `git commit` were prescribed in step 4's paragraph and `git fetch` in step 9's table, so no block
  held them and three hardcoded assertions named them by hand — a stand-in for a check rather than
  one. The answer was to move the commands rather than widen the grep: they are in fenced blocks now,
  which both steps wanted anyway, since step 4 told you to stage explicitly and never showed the
  command and step 9 buried its recovery in a table cell. With the sets equal, **a granted rule no
  block uses fails too** — a permission nobody needs is a sign the list and the procedure have
  drifted. Verified in both new directions: an off-scope path, and an unused grant.

  **That second direction went to the git half and not the gh half**, which left an unused
  `gh api -X DELETE` grant passing for a round — the same defect surviving because the fix reached one
  of the two places that needed it. Both halves check both directions now, and `docs/permissions.md`
  no longer calls the check one-way.

- **`tests/procedure-refs.test.sh` stopped declining three citation forms, because the reason for
  declining them was removable.** `makefile:12`, `R:12` and `foo+bar:12` were recorded as permanently
  out of reach: a lowercase bare word before a line number is indistinguishable from prose the file
  really contained — `floor: 2.4.0`, `measured: 0 resolved`, and two `(last:NN)` GraphQL slices. Two
  of those were prose and were rewritten to say the same thing without the shape; the other two are
  pagination arguments and are neutralised by name, `first`, `after` and `before` alongside `last`,
  since a fence edit could reach for any of them. With nothing left to collide with, the capital is
  unnecessary and two patterns collapse into one case-insensitive rule. The token must be letter-led
  and must not follow one, or `2026-08-24T07:59:33Z` reads `T07:59` as a file and a line — found by a
  negative case rather than by reasoning, and pinned. Three declined forms became three caught ones.

  **The first attempt skipped each fence wholesale and justified it by the hash guard, which does not
  hold.** `tests/fence-hashes.txt` is re-pinned whenever a fence legitimately changes, and the
  re-approval a fence edit costs is a human agreeing to new permission bytes, not an audit for
  citations. Skipping also discarded the lines _between_ a marker and its opener, which no hash covers
  at all: a citation injected there was invisible while the suite reported all green. The whole file
  is scanned now, and the neutralisation is anchored to the two fields that actually collide
  (`comments`, `reviews`). A bare `(last:40)` pattern would also have swallowed a prohibited prose
  citation written as `(first:12)` — the same over-broad exclusion, one level smaller, in the fix for
  it. An argument on any other field collides loudly instead.

- **`tests/provenance.test.sh` holds the reviewer cards to the grammar `reviewers/README.md`
  states.** **It checks the provenance half only, and says so**: deciding whether a sentence is an
  observation or an inference is the judgement that rule was rewritten to remove, so a test claiming
  to guard the whole grammar would be the overclaim the grammar exists to prevent. Provenance is the
  half that failed anyway — two `gemini.md` bullets stated observations with no citation and survived
  several reviews. The one exemption is the documented mechanical one, for a bullet opening
  `**Derived from …**`. Verified by injecting an uncited bullet and watching it fail.

  **The two provenance forms are not interchangeable fragments, and the first draft treated them as
  three.** The section gives a public form — cite the pull request — and a private one: anonymise as
  `repo X` **with the month**. Written as a flat alternation the check accepted `repo C` with no
  month, and a bare `2026-08` with no source at all, either of which is a bullet nobody can go and
  check. It is now a PR reference, or a repo tag and a month together.

  **Each form is matched whole rather than as a substring**, which a later round caught: a bare
  `#[0-9]+` is satisfied by `C#8` in ordinary prose, `repo [A-Z]` by `repo GitHub` — a name, not an
  anonymisation — and an unbounded month by `2026-99`. A PR reference now needs its `owner/name`, a
  repo tag needs a lone capital, and a month has to be one that exists. **The exemption was loose the
  same way**: `- **Derived from** …` closed the marker without naming anything and skipped the check
  entirely, so the bold span must now contain a source.

  **And a card the extractor could not parse used to pass in silence.** A `*` list marker or a
  `##  Measured` heading with two spaces yielded zero bullets, while the aggregate count stayed
  non-empty from the other cards — an entirely uncited new card would have gone green. Both markers
  are recognised now, and **each card asserts its own parseable section** rather than contributing to
  a total.

  **Each form is bounded at both ends**, which a later round required: without a left boundary
  `12026-08` supplies a month and `owner/repo#0suffix` a reference, and without a right one `#8x`
  does; a pull request is numbered from 1, so `#0` is not one. The derived exemption closed on
  whitespace alone (`- **Derived from   **`) and now needs something legible in the span.

  **One request is declined and recorded as declined**, in the test rather than only in a reply:
  checking provenance per sentence instead of per bullet. The rule is written per sentence, so the
  gap is real — a bullet holding two observations passes on one citation. Deciding which sentences
  are observations, as against derivations or connective prose, is the judgement the rule was
  rewritten to remove; a grep that guessed would either demand a citation on every sentence, which no
  card could satisfy, or guess at sentence roles and be wrong in the direction that matters. The unit
  is the bullet, and that is a limit rather than an oversight.

  Every existing bullet on all four cards satisfies each tightening, checked before it was applied,
  so the guard starts green.

Changed:

- **Step 3's untracked-file whitespace loop reports a status instead of only printing**, and
  **classifies that status rather than masking it with a bit test.** `--no-index` exits 1 for a clean
  new file and 3 for a dirty one, so `2` is the whitespace bit — but `git diff` also exits 128 when it
  cannot read a path, and `128 & 2` is zero, so a bit test calls an unreadable file clean. Measured on
  git 2.34.1: a single `chmod 000` file that `git ls-files -o` does list gives
  `error: open("only.txt"): Permission denied`, exit 128, and a `& 2` loop reports **status 0**. Only
  0 and 1 are clean now, 3 is the whitespace finding, and every other status is an operational failure
  that outranks it, because a check that could not read its input has not passed. `set -o pipefail`
  covers the producer side for the same reason. The braces are load-bearing as `-z` is — the `while`
  is the last stage of a pipeline and therefore a subshell, so a bare assignment would be discarded
  and the status would be the last file's. The output is still the report; the status says only
  whether to look, and at what.

The entries here come from two sources, and the difference matters when reading them.

**The originating measurement** is seven pull requests driven through this loop with codex in a single
repository (private, so `reviewers/codex.md` anonymises it as repo C, 2026-08). Their round counts
were 2, 3, 3, 8, 10, 21, and 30, and **a round returns roughly one finding** — 23 finding-bearing
rounds on one PR at a mean of 1.22, never more than 2. **The rounds a pull request needs is therefore
roughly the number of defects present when the trigger fires**, which is arithmetic on the measurement
rather than a separate observation, and is labelled derived wherever it appears. It is what the
entries below about steps 3, 7 and 10 were **originally written from**; several of them were then
corrected by the second source, and say so in place.

**The rest comes from this pull request reviewing itself.** Its review rounds on the branch that adds
these entries produced further defects in them, each fixed and recorded in place rather than as a
separate entry, and several were measured in throwaway git repositories built for the question — the
`--no-index` exit codes, the filename-handling table, and the `--follow` rename case. Those say
"measured" and name what was run. **This preamble said "everything here comes from one measurement"
until round 6, when the reviewer pointed out it had stopped being true several rounds earlier.**

Added:

- **Step 10 now names three sweeps instead of one, and asks which one matches the class.** The old
  advice was "sweep the whole codebase for its shape", and for the class that dominates the
  measurement it is wrong: **about 20 of one PR's 30 rounds were successive members of a single
  predicate's input space** — a particle, a comma-joined form, leading whitespace, whitespace around
  a joiner, an em dash, a compound particle — one form per round. **A codebase sweep returns zero for
  that class**, because the missing forms are inputs the predicate could receive and not text that
  exists in the tree, so the author concludes the class is closed and the reviewer names the next
  member next round. The three are a **corpus sweep** (instances exist; grep, fix, report count and
  method — the old bullet, now named), an **input-space sweep** (enumerate the form space along
  stated axes, close it as a set in one round, and pin every member with a synthetic case, because
  the corpus cannot witness this class and a test is the only evidence there is), and a **definition
  sweep** (find every other implementation of the predicate just changed and make them agree, or
  delete one — measured: a splitter and its consumer carried two grammars, and one of two gates read
  a different rule). Two guards ship with them: the input-space sweep is **bounded by what the
  predicate's real inputs can contain**, so the rule cannot generate speculative work of its own, and
  **a location already fixed in an earlier round of this PR means the class was named too narrowly**
  — widen and sweep again rather than patch in the new member (measured: four commit subjects on one
  PR name a prior round, and one line was fixed four separate times).
- **Step 3 now reads the pending change before step 4.** The procedure already asserted that the only
  way to spend fewer rounds is to have fewer defects at fire time, and then fired anyway. Step 3
  already argued the same thing about CI — a red run wastes a round, so pay for it before pushing —
  and the measurement makes the reviewer the more expensive of the two. **It is deliberately not a
  generic self-review**: on the measured PR the author was an LLM that had already missed those
  findings once, so a second general reading by the same reader is not supported by anything. It is
  step 10's sweeps, one step earlier. The pass must be reported, because a self-review nobody can see
  is indistinguishable from one that never happened.

  Two things about **what** it reads, both found by the reviewer on this branch's first round.
  **It reads the working tree, not a committed snapshot.** Step 4 has not committed yet and step 11
  re-enters step 3 with the fix unstaged, so the `git diff <base>...HEAD` and `git show HEAD` the
  step first shipped with read a history that does not contain the edits: round 1 could show an empty
  diff, and from round 2 `git show HEAD` shows the previous round's commit — the code the reviewer
  already found a defect in. `git status --porcelain` joins them because **no diff against a commit or
  the index lists an untracked file** — the `--no-index` form added later is the exception, and only
  because it is handed each path explicitly — and `git diff --check` gained an explicit `HEAD`: bare, it
  reads only what is unstaged. **And the change picks what to sweep for without bounding where to
  look.** The definition-sweep bullet asked for rules "this diff states in two places", which the
  diff can answer on its own and which therefore never fires for the drift the sweep exists to catch
  — a second implementation in a file the change never touched. It now searches the repository.

  Round 2 returned the same shape at two of the same locations, so the class was renamed from "reads
  a committed snapshot" to **a check whose actual input is a proper subset of what its stated rule
  covers**, and swept again. `git diff --check HEAD` reaches tracked content only, so a brand-new
  file — where a whitespace error is likeliest — passed it silently; each untracked path now goes
  through the same check against `/dev/null`, chosen over `git add -N .` because intent-to-add writes
  index entries for files step 4 has not decided to stage. `git status --porcelain` collapses a
  wholly-untracked directory into one `?? dir/` line, which is not something you can "read in full" —
  it now carries `-uall` at all three of its sites, and **step 4's is the one that matters**: staging
  a `?? dir/` line stages everything inside it, the blast radius `git add -A` is banned for. The
  re-sweep also reached step 1, where nothing read the repository's history even though steps 4 and 6
  both say commit style and the two languages are "detected" from it; two `git log` calls now do,
  because a row that says `detected` with no detector behind it is worse than an honest `builtin`.

  Round 3 found four more, all of them the mechanics rather than the intent, and three measured on
  throwaway repositories holding three awkward names — one beginning with two blanks, one called
  `-dashfile.txt`, and one with a newline in its name. The first two were run together; the newline
  case separately, which is why it is reported as what `git ls-files` printed rather than as what the
  loop then did. **The untracked loop skipped exactly
  the awkward names it existed to reach**: `read -r` without `IFS=` strips leading blanks
  (`Could not access 'leading-space.txt'`), `git ls-files` without `-z` renders an embedded newline as
  the quoted `"new\nline.txt"`, and a name beginning with `-` reaches `git diff` as options
  (`unknown switch 'd'`) — both files' whitespace errors went unreported while the loop printed
  complaints about their names. It is now `-z` with `IFS= read -r -d ''` and a `--` separator, and the
  procedure states that the **exit status of `--no-index` is not the signal**: every new file differs
  from `/dev/null`, so a clean one exits `1` and a dirty one `3`, and `$? -ne 0` would mark the
  preflight red whenever any untracked file exists. **Step 10's "was this already fixed in an earlier
  round" query gained `--follow`** — measured: a file fixed in round 1 and renamed in round 2 shows
  only the rename, so the question that exists to detect a too-narrow class answered a confident No.
  And step 1's trailer detection read three bodies, which is a sample of shape and not evidence of a
  convention; trailers are now grepped out of twenty.

  Round 4 closed the probe properly. All three `git log` calls read **the same twenty commits**, so
  the three agree with each other — round 3 had bumped the trailer read to twenty while keeping a
  three-body read and labelling it "read in full rather than sampled", which was a label contradicting
  its own command. **Twenty is still a window and not the history**, which is why the row says
  `detected` rather than proven; round 5 corrected the first version of this entry for claiming the
  sample away entirely. The unfiltered body read is the authority and the trailer grep is a
  convenience view of the same twenty, so **a token that grep fails to match still appears in the line
  above it**; the pattern had in fact been too narrow, dropping trailer tokens containing digits. Its
  comment says "lines shaped like a trailer" rather than "trailers", because an ordinary `Note:` line
  mid-body has the same shape.

- **Step 7's focus asks for every sibling in one comment.** The focus already named the class; it did
  not say what to ask for. That this raises findings per round is **derived, not measured** — what is
  measured is only that codex accepts the suffix — and the paragraph says so.
- **Step 7 forbids the literal `revloop:trigger` in the focus text.** The wait fence reads the marker
  as the text after the first occurrence of that literal, and the focus precedes the marker, so a
  focus containing it wins the split. **Measured** against the fence's own jq program: the marker
  string becomes `markers in the diff--`, carrying no `bot=`, `head=`, `reviewer=`, or `round=`.
  **Derived from that, not separately measured**: step 9 aborts on `marker_head=none` (fail-closed,
  one wait spent), and an empty `bot=` leaves the fence's bot filter matching every login, so any
  other bot on the pull request would have satisfied the wait had the round continued. The schema
  already rejects a configured `trigger` containing the literal; the focus is composed in the
  procedure, so the rule now exists there too. `tests/fixtures/jq/focus-carrying-marker` pins **the
  jq output only** — it runs the extracted jq program against one recorded payload that contains no
  bot verdict, so neither the shell that reads the row nor step 9's table is exercised by it. Round 5
  corrected both this entry and the fixture's own assertion labels, which named the step-9 abort as
  though the fixture reached it. The existing clean-comment fixture is the control that proves the
  assertions discriminate.
- **`reviewers/codex.md` carries a second findings-per-round sample** and four new measurements:
  findings concentrate (28 in 3 files, 30 in 5) and the next one repeats the previous file 39–52% of
  the time across four PRs; the severity mix moves per PR (15/15 P2 on one PR, 15/15 P1 on another,
  25 P1 + 3 P2 on a third, P3 zero throughout — from which "do not triage by badge" is derived, and
  marked so on the card); the per-PR round counts; and the input-form-per-round
  shape. **The second sample is not independent of the existing 37-round one** — same repository,
  same account — and is written as corroborating the centre rather than the range, because presenting
  two samples from one source as two sources is the "looks measured" failure `CONTRIBUTING.md` warns
  about.
- **`reviewers/README.md` states the rule the cards are written to**: a `## Measured` bullet opens
  with an observation and its provenance, and everything after that — inference, recommendation,
  remedy, design consequence — sits behind a `Derived:` marker. A bullet with no observation belongs
  under `## Not measured`, which all four cards now have; the single exception is mechanical, for a
  bullet that opens by naming what it derives from.

  **The rule took three rounds to hold, and the reason is the rule's first draft.** It exempted
  "design rationale signposted as such", and that exemption required deciding sentence by sentence
  whether something was rationale or a claim. The judgement went wrong in both directions in
  consecutive rounds: first leaving inferences unmarked, then defending the exemption for four
  sentences a later audit rejected. The exemption is gone, the rule is now mechanical, and it costs
  some `Derived:` markers on sentences whose status was never in doubt — the cheaper side of the
  trade. It also took three rounds because the first two applications only touched `codex.md` while
  the rule sat in a file governing every card, which is the same "stated in one place, not held to
  elsewhere" shape the rule exists to catch. All four cards are now written to it, `gemini.md` and
  `claude.md` and `copilot.md` gained the `## Not measured` sections the rule implies, and the
  focus-suffix bullet gained the provenance it never had.

  A further round found the rule itself still wrong at its boundary: "opens with an observation, and
  everything after that is `Derived:`" demands a marker on a bullet's **second** observation, and had
  put one in front of an exact quoted string on `codex.md`. It now reads sentence by sentence — every
  sentence is an observation with provenance or sits behind the marker — which is the same rule
  without the false ordering. Three cards were corrected under it, and `gemini.md`'s error
  observation gained the date it lacked.

- **`tests/permissions.test.sh` holds `docs/permissions.md`'s granular git list to the procedure.**
  That list is a copy of a fact living in `commands/review-loop.md`, and it had already drifted three
  times — `switch`, `fetch` and `ls-files` were each run by a step the list did not grant. An earlier
  round **declined to test it**, arguing that a grep for `git <word>` cannot tell a command from prose
  since the file says "makes git set the upstream" and names `git show HEAD` twice to forbid it.
  **That reason was wrong.** Runnable commands live in fenced `bash` blocks and prose does not, so
  extracting from the blocks alone yields neither `set` nor `show` and needs no exclusion list. The
  check compares both directions: every subcommand in a block must be granted, and every granted rule
  must be used by a block. It was one-way at first, because `git add` and `git commit` were prescribed
  in step 4's paragraph and `git fetch` in step 9's table, so no block held them and three assertions
  named them by hand. A later round moved the commands into blocks instead — which both steps wanted
  anyway — and the stand-ins went with them. Both extractions must be non-empty, because a broken one
  finds nothing missing and passes on no data.
- **`CONTRIBUTING.md` no longer says `tests/procedure-refs.test.sh` "enforces" the line-number rule.**
  The rule is absolute; the guard catches the forms it enumerates and once declined three it could not tell
  from prose. Tripwire, not proof — and the difference is now in the sentence that sends readers to it.
- **`tests/procedure-refs.test.sh`** fails if the procedure cites one of its own line numbers, and
  `CONTRIBUTING.md` states the rule beside it. **It took five review rounds to make the guard's claim
  match its behaviour, and the reason is worth more than the guard**: each round closed one axis of the
  notation and left the next one spelled by hand, which is the failure the procedure's own
  input-space sweep is written to prevent. The axes, in the order they were found — number of digits
  (`[0-9]{2,}` passed "line 9"), singular versus plural (`line` alone passed "lines 334 and 371",
  which is just the two citations the guard was written to catch, joined), letter case (`[Ll]` passed
  "LINE 132"), the separator (a literal space passed "line: 132", "line:132", "line number 132"), the
  notation (matching the word alone passed "#L132" and "review-loop.md:132"), and the file cited
  (matching only `.md:` passed "procedure-refs.test.sh:40", though the rule forbids citing any file by
  line). Round 4 added two more: the filename form (a 1–4 letter extension passed
  `package.jsonc:12`, and requiring an extension at all passed `Dockerfile:40` and `Makefile:12`) and
  case sensitivity — folding the filename half into the `grep -i` half **re-broke it**, because `-i`
  does not spare a bracket expression, and `floor: 2.4.0` matched again. Case is noise in `LINE 132`
  and signal in `Dockerfile:40`, so the guard is now two patterns, one grep each. The extensionless
  branch is the one axis with no syntax to derive from — an extensionless filename is lexically just a
  word — so it is derived from the corpus instead: every `word: digits` phrase the procedure really
  contains (`floor: 2.4.0`, `measured: 0 resolved`, and two `(last:40)` forms inside untouchable
  fences) is lowercase or has no dot or slash, and all four are pinned as must-not-match cases. Round
  5 added leading-dot paths (`.env:12`) and the hyphen form (`line-number 12`), for ten axes and 41
  assertions.

  **Round 5 also stopped the guard claiming to cover "any citation notation", which is the claim that
  kept being wrong.** No regex over English prose carries it, and the comment had asserted it for four
  rounds while the pattern did not. It now says it covers the enumerated forms, and it names the three
  it deliberately did not — `makefile:12`, `R:12` and `foo+bar:12` — on the ground that a lowercase
  extensionless filename is lexically identical to prose this file must not break. **A later round
  removed that ground and all three are caught**; see the entry above. **The guard is a tripwire, not
  a decision procedure, and the difference is written down.** The assertion was widened alongside
  the pattern — keying on a literal `line` would have let an `#L132` hit through unseen, the same
  defect one level up. The guard stays scoped to `commands/review-loop.md` so that this file can go on
  quoting the citations it records removing.

Changed:

- **`commands/review-loop.md` no longer cites its own line numbers.** `## Notes` named "step 10, line
  334" and "step 11, line 371". Both were correct when written and both were one insertion away from
  being silently wrong; the step numbers were already there, so the line numbers carried nothing.
- **Two copies of a measured number now point at the card that owns it** rather than restating it:
  the flags table said real PRs have needed 20+ rounds (the measured maximum is 30), and step 10's
  lead declared codex at 1–4 and gemini at 30–50 a second time.
- **Both README phase tables** describe the Prepare and Fix phases as they now behave — Prepare sweeps
  the pending change before pushing, and Fix runs the sweep that matches the class rather than "the
  codebase sweep", which is now one of three and the one that does not apply to the dominant class.
- **`docs/permissions.md`'s granular rule list gained `git switch`, `git fetch`, and `git ls-files`**,
  the first two of which step 2 and step 9's recovery row have always run while the list never granted
  them. The list is a copy of a
  fact that lives in the procedure, so it drifts; the section now says outright that no test holds the
  two together and why one would not help — a grep for `git <word>` cannot tell a command from prose,
  and the procedure names `git show HEAD` twice precisely to forbid it.

## [0.1.0] - 2026-08-23

First release. Everything below happened before it, so **no re-approval is owed to anyone**: there
was no earlier version for a fence to have changed from. The fence-related entries are recorded
anyway, because "record every fence edit" is the rule, and a rule that is skipped when it is
convenient is not one.

### Added

- **Both READMEs now describe the loop's flow, and say how long the wait is.** `## How it works` /
  `## 動作の流れ` sits ahead of the install section in each, giving the run as seven phases and then
  stating the part nobody was told: **after the trigger comment, several minutes pass in which nothing
  happens**, because the reviewer is a GitHub app and the loop can only poll it. A first-time user had
  no way to tell that from a hung command — the arrow chain that used to open the English README read
  as if the steps ran back to back. codex's **3–4 minutes to a verdict is measured and dated**
  ([`reviewers/codex.md`](reviewers/codex.md), 2026-08); gemini and claude are given no latency at all
  rather than codex's. The section summarises the procedure at phase level and does not restate it;
  `commands/review-loop.md` remains the only place the steps are written out, and the only place the
  shipped budgets — the 30-second poll, the 480-second chunk, the cumulative `--timeout 30m`, the
  `--max-rounds` circuit breaker, and the CI wait's ~18-minute worst case — are stated. Neither README
  repeats those numbers; `docs/install.md` links to both files from `## Prerequisites` instead.
- **`docs/permissions.md` now covers Codex.** It described only Claude Code's allowlist and never
  said so, which left Codex users to infer their setup from a note in the skill. There is now a
  `## Codex: approval policy and sandbox` section covering `approval_policy`, `sandbox_mode`,
  `sandbox_workspace_write.network_access`, and per-project `trust_level`, and the file opens by
  saying which sections belong to which host. The section states the failure it exists to prevent:
  **a `workspace-write` sandbox commonly runs with `network_access = false`, and every `gh` call in
  the procedure needs the network.** Its key names and value sets were read out of an installed
  `codex-cli 0.147.0` rather than from vendor documentation, and the claim that the configuration
  carries the loop end to end is **labelled derived**, because it has not been driven against a live
  pull request.
- **Both READMEs now state the reviewer prerequisite up front**, above the command block: the Codex or
  Claude GitHub integration must already be installed on the repository and answering comments. Why
  that is a separate thing to install — a `@codex review` comment goes to
  `chatgpt-codex-connector[bot]`, not to the session you are running — is spelled out once, in the new
  `## Prerequisites` section of `docs/install.md`, which the READMEs link rather than restate. This
  was previously one sentence at the tail of `## Requirements`, where the person who most needed it
  had already stopped reading; that sentence moved rather than being duplicated.

- Initial extraction of the review loop into a standalone, reviewer-agnostic tool.
- `.revloop.json` configuration with auto-detection for base branch, verify commands, branch
  prefixes, and commit conventions; JSON Schema and four worked examples.
- Reviewer presets for `codex`, `gemini`, `claude`, and `copilot`, each as a dated card recording
  what was measured and where.
- Fence tests that extract the shell fences from the procedure and replay recorded GitHub responses
  through a `gh` stub, plus structural guards and a fence-hash gate.
- Codex router under `.agents/skills/revloop/`, resolving the same procedure file.
- A **Limitations** section in the README. Forks, detached HEAD, squash and rebase merges, `copilot`,
  and reviewers that post a preamble are all outside what this drives; each is a stop with a named
  reason rather than something a user discovers.
- `tests/version.test.sh`, pinning the version string across the five manifests and the changelog.
- Issue templates (bug report, reviewer measurement), a pull request template, and a code of conduct.

### Changed

- **The install section is now structured identically in both READMEs**, as
  `### Claude Code` / `### Codex`. The English side had a flat `## Install` with Codex reduced to a
  single link, and the Japanese side had an **empty** `## Codex` heading at the wrong level, which
  broke `npm run check:docs`. Both now carry the same two subsections in the same order, and the
  permission setup lives inside the host it belongs to — the allowlist JSON under `### Claude Code`,
  the approval-policy-and-sandbox pointer under `### Codex` — rather than in a third section that had
  to name both.
- **The Japanese README moved to the repository root, and the English one was cut down to match it.**
  It was `docs/ja/README.ja.md`, a partial overview that covered install and design intent; it is
  `README.ja.md`, a standalone README, and `README.md` now mirrors it section for section — same
  headings in the same order, same tables, same examples — so the two can be compared line by line and
  drift is visible rather than quiet. **The parity was reached by shortening the English side, not by
  expanding the Japanese one.** **The old path is gone, not redirected**, so a link to it 404s; the
  only reference in this repository was the README's own documentation table, and it was updated.
  The procedure itself is unchanged and still English-only, and no fence changed, so **no
  re-approval is owed**.

- **Toolchain versions are stated once, in `mise.toml`.** CI installs them with
  `jdx/mise-action`, replacing `actions/setup-node` and the `node-version: 24` that was duplicated
  across both jobs. `jq` and `shellcheck` are now pinned there too — jq at 1.7.1 (the final patch of
  the 1.7.x series `ubuntu-latest` carried when this was written) and shellcheck at 0.9.0 (matching
  the image exactly) — so a runner image update can no longer change a lint verdict on its own.
  Dependabot does not track mise pins, so raising them stays a manual, deliberate step.

  This closes a real gap rather than only removing duplication. `tests/lint-shell.sh` and
  `tests/jq-program.test.sh` skip themselves when their binary is absent, so a contributor without
  `jq` and `shellcheck` saw `npm run check:all` pass having run neither — while CI ran both. After
  `mise install` the two agree.

- **The configuration surface now matches what the procedure consumes.** About twenty-five schema
  keys had no consumer in `commands/review-loop.md`, which is the single source of truth for
  behaviour — so configuring them did nothing while looking like it did something. Removed:
  `project.roundSource`, `project.commit.embedRoundNumber`, `project.pr.titleTemplate`,
  `project.pr.bodyUpdateMethod`, `project.pr.mergeMethod`, `project.pr.requireCleanCiForMerge`,
  `reviewers.*.triggerKind`, `reviewers.*.announce`, `reviewers.*.focusSuffix`,
  `reviewers.*.verdictOn`, and `reviewers.*.ignoreCommentPatterns`. What each of them was reaching
  for is now stated as a fixed property in `docs/configuration.md` under **What is deliberately not
  configurable**, with the reason it is fixed.

  The round number, which `roundSource` used to select a strategy for, is now defined in step 7:
  the count of `revloop:trigger` markers already on the PR, plus one.

- **Actions are pinned to commit shas** rather than to `@v5`/`@v4`, for the same reason `mise.toml`
  pins jq and shellcheck exactly. `actions/checkout` also moves to v7.

- **`npm audit` runs in CI as its own job**, and `.revloop.json`'s `verifyNotes` now names it as the
  gap `check:all` does not cover. `audit` needs the network and `check:all` has to stay runnable
  offline, so this repository demonstrates its own `verifyNotes` feature rather than claiming to have
  no gap.

- **`ajv-cli` replaced by `ajv` called directly** from `tests/validate-schema.mjs`. `ajv-cli` has not
  moved since 2021 and its dependency tree carried a high-severity prototype-pollution advisory
  through `fast-json-patch` (GHSA-8gh8-hqwg-xf34), which `npm audit fix --force` proposed to resolve
  by downgrading four major versions. The wrapper was the problem; the wrapper is now forty lines in
  this repository, and it distinguishes "the schema rejected it" from "the validator never ran" —
  the reject cases would otherwise pass for the wrong reason after a typo in a path.

### Removed

- **`README.md` no longer carries `## Why it is built the way it is`, `## Tests`, or the
  `### The wait is the slowest part of the loop` subsection.** Each was English-only, and keeping them
  is what made the two READMEs impossible to diff. Nothing was lost, only relocated to the file that
  already owned it: the design rationale is in [`docs/design-notes.md`](docs/design-notes.md), the
  check commands and the warning that `check:all` **goes green having skipped shellcheck and jq**
  without `mise install` are in [`CONTRIBUTING.md`](CONTRIBUTING.md), and the wait budgets are in
  `commands/review-loop.md`. All three are still reachable from the README's documentation table or
  from `docs/install.md`. **`--timeout` is the one flag no longer named anywhere in either README** —
  it remains in the procedure's flag table and in the command's `argument-hint`.

### Fixed

- **All three fences**: a detached HEAD made `git branch --show-current` print nothing, and
  `gh pr list --head ""` reads an empty value as **no filter** rather than as no match — so it
  answered with the first open PR in the repository. Measured here: the unguarded command returned an
  unrelated Dependabot PR (`iwmaeda/revloop#4`). The wait fence would have read a stranger's
  comments, step 12 would have reported a stranger's CI as green, and only the merge fence's `sha=`
  pin stood between that and a merge of someone else's branch — one interlock deep is not enough for
  a gate. Each fence now resolves the branch first and exits `no-branch` when it is empty; step 9's
  table and step 12's output list carry the new reason.

  This changes fence bytes in all three fences.

- **wait-verdict fence**: revloop's own trigger comment matched both trigger classes at once, so a
  single comment emitted two `TRIG` rows with identical timestamps. `tail -1` then took the
  compatibility row, discarding the marker — and with it the `bot=` filter that excludes other bots
  and the `head=` value the runaway check depends on. The compatibility class now excludes bodies
  that already carry a marker. Found by running the fence's jq program against a raw GraphQL payload;
  the row-level fixtures could not see it, because they were written by hand with one row per
  comment.

  This changes fence bytes.

- **A repository could grant itself an unattended merge.** `defaults.merge` and `defaults.auto` were
  configuration keys, and `.revloop.json` comes from whatever repository you are working in,
  including one you just cloned. A hostile or careless config could therefore turn on merging and
  delete both human confirmation points, while `SECURITY.md` claimed safety rules could not be
  switched off from config. Both keys are removed: `--merge` and `--auto` are settable by flag only,
  because the flag is the approval. `tests/schema.test.sh` now asserts both are rejected.

- **The command granted itself the wide permission rule its own docs warn against.** The frontmatter
  carried `Bash(gh api *)` — which reaches every repository the token can touch, and which
  `README.md`, `docs/permissions.md` and `SECURITY.md` all name as the rule to avoid — in a syntax
  (`Bash(git *)`) that did not match the documented one either. It is now the same rules the docs
  tell you to grant, and `tests/fence-guards.test.sh` fails if the frontmatter ever grants something
  `docs/permissions.md` does not list.

  The first pass narrowed to a single `Bash(gh api repos/{owner}/{repo}/:*)` rule and missed that a
  rule matches a command-string **prefix**: the reply-to-finding call and the merge fence both put
  `-X POST`/`-X PUT` before the path, so neither matched. Under `--merge --auto` that reintroduced
  exactly the stall the narrowing was meant to avoid. Two more rules, scoped the same way —
  `Bash(gh api -X POST repos/{owner}/{repo}/:*)` and `Bash(gh api -X PUT repos/{owner}/{repo}/:*)` —
  cover them. Found in review before release.

  The same gap existed one flag over: reading findings (step 10) and verifying a reply (step 11)
  both call `gh api --paginate "repos/{owner}/{repo}/..."`, and `--paginate` sits before the path
  the same way `-X POST`/`-X PUT` do, so none of the existing rules matched either. One more rule,
  `Bash(gh api --paginate repos/{owner}/{repo}/:*)`, covers them. Also found in review before
  release.

- **A hand-typed trigger produced a misleading abort.** A compatibility-class trigger carries no
  marker, so `marker_head=none`, which step 9's check (c) reported as "the runaway invariant is
  violated, or someone else pushed" — sending the reader hunting for a push that never happened. It
  has its own row now, and `docs/design-notes.md` states that anchoring a baseline is the whole of
  what the compatibility class does.

- **`copilot` is marked `unsupported`, not `unverified`.** It has no comment trigger, and the
  reviewer-request path it needs was never written, so `--reviewer copilot` could not run. Step 1
  now aborts with `reason=no-comment-trigger`. The card is kept for what it measured.

- **The claim that adding a reviewer never needs a fence change was false** for a reviewer that
  posts a preamble before its verdict — the drop list is inside the fence, where config cannot reach.
  `README.md` and `docs/adding-a-reviewer.md` now say so, and name the `interim-loop` abort as the
  signal that a fence edit is owed.

- **`docs/install.md` gave `git` no version floor.** It is 2.22 (`git branch --show-current`),
  labelled as derived from the feature rather than measured, next to the `gh` floor that was.

[0.6.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.6.0
[0.5.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.5.0
[0.4.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.4.0
[0.3.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.3.0
[0.2.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.2.0
[0.1.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.1.0
