# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Each release says whether a shell fence changed. Permission rules match a fence by its exact text,
so a changed fence asks every user for one re-approval. See
[`docs/permissions.md`](docs/permissions.md).

## [Unreleased]

Fences: `wait-verdict` changed (one re-approval).

### Changed

- The procedures, commands, reviewer cards and user documentation were condensed, and this changelog
  was rewritten as short lists. Behaviour is unchanged; the earlier text is in the git history.
  `docs/known-environment-quirks.md` is gone, and its two remaining tips are in `docs/install.md`.
- `/revloop:local-ecc-loop` tells its reviewer that the run is non-interactive: never ask, never
  retry a refused call, stop if the pull request cannot be read, and otherwise finish and say what
  could not be run. The `ecc-review-pr` `command` gained `--append-system-prompt`, so an "always
  allow" given for the old string is asked for once more.
- When a subprocess reviewer ends by asking a question, the `unparsed-review-output` report says
  what it asked for.
- A pull-request loop waits past a reviewer comment it cannot classify instead of aborting on it at
  once. It adds a 👀 reaction to the comment from your account, a firing of the wait fence skips a
  comment whose fetch shows one, and the wait continues. It aborts with `reason=interim-loop`
  instead when three marks already stand, the reaction cannot be added, a second read does not list
  it, or that read returns more than three rows. A round whose pull request carries such a 👀 on a
  bot comment, from any earlier round or run, as far as the loop's reads observe, and then has
  nothing to fix stops with `reason=unclassified-comment`; remove the 👀 and run the command again to
  accept the verdict. Such a round does not re-post its trigger while the loop's read observes a
  mark, and a `--merge` run reads the marks again just before the merge. A marked comment that the
  reviewer later edits into its verdict is read only by a firing that fetches after you remove the
  👀, and every report lists the marks the loop's last read observed, whichever run made them.

### Fixed

- The wait fence ignores Codex's status card, an issue comment that opens with
  `<!-- codex-pull-request-review-summary -->`. A run used to read the card as the verdict and
  abort before the review arrived.
- `/revloop:local-ecc-loop` tells its reviewer to read the pull request with `gh pr view --json`
  and `gh pr diff`. On `gh` 2.4.0 a plain `gh pr view` fails, and a round that used it could not
  name the pull request and aborted with `unparsed-review-output`.
- The `ecc-review-pr` card lists the report shapes the reviewer emits: labels as `##` headings or
  bold lines, confidence percentages on some rounds only, and progress lines before the report.

## [0.16.0] - 2026-10-05

Fences: none changed.

### Changed

- Both procedures state that one session runs a loop: the session the command was invoked in. A
  session it starts, such as a subagent or a fork, does not run the procedure.
- Only the edit for a finding may be handed to another agent, which must start without the
  conversation. If `HEAD` moved while it worked, the runner stops it and resumes from step 1.

## [0.15.0] - 2026-10-04

Fences: none changed.

### Changed

- The remote loop reads a review, its findings and the replies under them in four calls per round,
  whatever the number of findings.
- The pull-request body update prints one line (`pr=`, `body_chars=`) in both loops.
- Development: `npm run lint:md` runs `markdownlint-cli` and lints dot-directories. Its ignore list
  is `.markdownlintignore`, which must match the list in `.markdownlint-cli2.jsonc`.

### Fixed

- Step 7's backstop compares the marker's full `oid=` with HEAD, as step 3 does. It falls back to
  `head=` only for a marker without `oid=`.

## [0.14.1] - 2026-09-30

Fences: none changed.

### Changed

- Development: `markdownlint-cli2` moves to 0.23.3 for two advisories in dev-only packages, and
  `tests/severity-ladder.test.sh` excludes `node_modules`.

## [0.14.0] - 2026-09-30

Fences: none changed.

### Changed

- **Breaking:** `/revloop:local-ecc-loop` reviews at `--effort medium` instead of the effort level
  in your Claude Code settings. To review at another level, copy `reviewers/ecc-review-pr.json`,
  change that token, and run the copy with `/revloop:local-custom-loop`.
- The `ecc-review-pr` review command is a new string, so a permission rule saved for the whole old
  string prompts once. A Claude Code version without `--effort` fails the round with
  `review-command-failed`.

## [0.13.0] - 2026-09-29

Fences: none changed.

### Added

- `.revloop/config.json` is read in place of `.revloop.json` when it exists, so a personal
  configuration stays out of git. Step 1 prints which file was read.
- Abort `config-not-ignored`: `.revloop/config.json` exists and git neither tracks nor ignores it.
- The Codex router finds a clone at `~/.revloop` without `REVLOOP_PROCEDURE`. Link a clone kept
  elsewhere with `ln -s <clone> ~/.revloop`.

### Changed

- The Codex install copies the skill to `~/.agents/skills/` instead of into the project.
- **Breaking:** nothing searches the working tree for the procedure any more. A command file run
  without the plugin (for example copied into `.claude/commands/`) aborts with
  `procedure-unresolved`.

## [0.12.0] - 2026-09-28

Fences: none changed.

### Added

- The first write into `.revloop/` is `.revloop/.gitignore` containing `*`, so field notes and the
  grading input stay out of `git status` with no rule in a shared `.gitignore`. An existing
  `.revloop/.gitignore` is left alone.
- Nothing is written into `.revloop/` where git would show it. A field note that cannot be written
  goes into the report, and a grading input that cannot leaves the round ungraded, which blocks.

### Changed

- If you grant git subcommands one by one, add `Bash(git check-ignore:*)`. `Bash(git:*)` already
  covers it.

## [0.11.0] - 2026-09-13

Fences: none changed.

### Added

- `foreign-baseline-adopt`: when a hand-typed trigger holds the baseline and the configured
  reviewer has since reviewed the checked-out HEAD, the remote loop reads that review, answers its
  findings and then posts an ordinary trigger. Such a run used to abort on every invocation.
- An adopted round does not count against `--max-rounds`, cannot converge the loop and never
  merges. Its replies carry the scope `adopted-<review_id>`.
- `foreign-baseline-retake`: when that review is on an ancestor of HEAD, the run posts a new
  trigger without reading it and names the discarded review in the report.
- Step 1 prints a line naming `defaults.maxRounds` when the round cap comes from the rigor level.

### Changed

- At `--max-rounds` a run posts no trigger but still waits one chunk for a verdict standing at
  HEAD and acts on it. `reason=max-rounds` fires only when there is nothing to read, and its report
  names the cap, its `source`, the marker count and the remedy.

## [0.10.0] - 2026-09-12

Fences: none changed.

### Added

- A rate-limited round can be recovered by running the command again. The run that meets the quota
  notice aborts with `reviewer-rate-limited`. A later run opens a new round at the same HEAD
  (`rate-limit-retake`), which counts against `--max-rounds`.
- Abort `pr-head-advanced`: the pull request's head moved while the run waited, so a clean verdict
  is not reported as a convergence.
- Step 1 runs `git fetch` and prints where the run stands: tree state, ahead/behind the upstream,
  the open pull request, and local HEAD against the pull request's head (`pr_head=`).
- The trigger marker carries `oid=`, the full commit id, and head comparisons use full ids.

### Changed

- A re-run on a clean, pushed branch whose HEAD equals the pull request's head skips verify, commit
  and push and goes to the standing review. Step 7 returns to step 3 when no marker names the
  current HEAD.
- Replies carry a `revloop:reply` marker with the round. Step 11 reads existing replies first, so a
  resumed round posts no duplicates.

### Fixed

- `rateLimitPatterns` are matched against the full comment body. A long or multi-line notice used
  to miss and abort as an unknown bot body.
- A clean `comment` or `reaction` verdict passes through the same convergence gate as a review,
  including the rigor sufficiency test.

## [0.9.0] - 2026-09-07

Fences: `worktree-teardown` added (one first approval).

### Added

- A run may create a git worktree to build or test another commit, which asks for permission every
  time, also under `--auto`. Step 3 creates it detached under the session scratchpad with a name
  beginning `revloop-wt-` and records its path in `revloop/worktrees.txt` inside the checkout's git
  directory.
- The `worktree-teardown` fence removes the recorded worktrees before the report, on every exit of
  both loops. A worktree named `revloop-wt-*` that the record does not list is reported as
  `WORKTREE=other` and left in place.
- The sweep prints `WORKTREE=swept`, `WORKTREE=partial` when a worktree could not be removed, or
  `WORKTREE=error` with a `reason=` when it refuses to run.

### Changed

- **Breaking:** if you grant git subcommands one by one in place of `Bash(git:*)`, add
  `Bash(git worktree:*)`. The teardown cannot run without it.

## [0.8.0] - 2026-09-04

Fences: none changed.

### Added

- `--rigor <level>` sets which findings block, the round cap and the sweeps owed after a fix. It
  has no configuration key and is specified in `procedures/rigor-levels.md`.
- Levels: `minimal` blocks `critical` (cap 3 remote, 2 local), `standard` also blocks `high`
  (5, 3), `thorough` and `exhaustive` block every finding (10, 5 and 15, 8).
- The report, and the pull-request body on a publishing run, carry a `Sufficiency:` block that says
  whether the change meets its level.

### Changed

- **Breaking:** the default level is `standard`, so `medium` and `low` findings may be left unfixed
  and the default round cap falls from 10 remote and 5 local to 5 and 3. Pass `--rigor thorough`
  for the earlier behaviour, or set `--max-rounds`, `defaults.maxRounds` or
  `defaults.localMaxRounds` to keep only the cap.
- **Breaking:** `--merge --auto` aborts with `unreviewed-accept-merge` at `minimal` and `standard`,
  the default included. Use `--rigor thorough --merge --auto`.
- At `minimal` and `standard` a grader subprocess runs every round against a reviewer without
  `severityLevels` (`claude`, `code-review`, `ecc-review-pr`), with one more permission prompt per
  round.
- A reviewer definition must declare `severityLevels` and `severityMap` together, which retires the
  abort `no-severity-map`. `bad-severity-map` is checked on every run at `minimal` and `standard`
  when the reviewer has a ladder.
- Running revloop from Codex is labelled a preview. Its router, `.agents/skills/revloop/SKILL.md`,
  now resolves the reviewer definition itself and requires a reviewer to be named.

### Removed

- **Breaking:** `--accept-at`. Use `--rigor minimal` for `high` or `P2`, `--rigor standard` for
  `medium` or `P3`, and `--rigor thorough` for `low`. The abort `unknown-accept-level` is now
  `unknown-rigor-level`.

## [0.7.0] - 2026-09-04

Fences: none changed.

### Added

- Reviewer definitions are files, `reviewers/<name>.json`, validated against
  `schema/reviewer.schema.json`. Start one of your own from `examples/reviewer.custom.json` or
  `examples/reviewer.local.json`.
- A `local-command` reviewer may declare `rateLimitPatterns`, and a match aborts with
  `reviewer-rate-limited` in place of `unparsed-review-output`. Both shipped local presets declare
  one, and step 1 prints a `rate-limit pattern` row.

### Changed

- **Breaking:** one command per reviewer replaces `/revloop:remote-loop`, `/revloop:local-loop` and
  `--reviewer`. Use `/revloop:remote-codex-loop`, `/revloop:remote-gemini-loop`,
  `/revloop:remote-claude-loop`, `/revloop:local-review-loop` (the `code-review` reviewer) or
  `/revloop:local-ecc-loop` (`ecc-review-pr`).
- **Breaking:** `.revloop.json` no longer defines reviewers: the `reviewers` map,
  `defaults.reviewer` and `defaults.localReviewer` are ignored. Move the reviewer object into its
  own file and pass it to `/revloop:remote-custom-loop` or `/revloop:local-custom-loop` with
  `--config <path>`.
- **Breaking:** `commands/remote-loop.md` and `commands/local-loop.md` moved to
  `procedures/remote-loop.md` and `procedures/local-loop.md`. Point `REVLOOP_PROCEDURE` and any
  link at the new paths.
- **Breaking:** `--review-model` is renamed `--model`. `--model` and `--no-publish` exist only on
  the `local-*` commands, `--merge` and `--timeout` only on the `remote-*` ones.

### Removed

- **Breaking:** `--grade-severity`. `--accept-at` alone now starts the grader
  (`procedures/severity-grading.md`) when the definition has no `severityLevels`, with one more
  permission prompt per round. The aborts `no-severity-ladder`, `grade-without-floor` and
  `grade-over-ladder` are gone.
- The `copilot` reviewer preset, `reviewers/copilot.md`.

## [0.6.0] - 2026-09-03

Fences: none changed.

### Added

- `--accept-at` also takes revloop's canonical ladder, `critical > high > medium > low`, carried
  onto the reviewer's own rungs by a new `severityMap` key. Step 1 prints which rungs block.
- Aborts `no-severity-map` and `bad-severity-map`: a canonical level was typed and the reviewer's
  ladder has no map, or a map that is partial, inverted or collapsed onto one rung.
- `--grade-severity` lets `--accept-at` work against a reviewer that emits no severity. A grader
  subprocess assigns the rungs, marked `graded`, with one more permission prompt per round. New
  aborts: `grade-over-ladder`, `grade-without-floor`, `grading-command-failed` and
  `unparsed-grading-output`.
- `--review-model <name>` sets the model a local review runs on, through a `{reviewModel}`
  placeholder in the reviewer's `command`. It aborts with `no-model-boundary` when the reviewer
  has no placeholder or uses `invoke: skill`.

### Changed

- **Breaking:** `/revloop:review-loop` is now `/revloop:remote-loop` and
  `/revloop:review-loop-local` is now `/revloop:local-loop`, with no alias. Point
  `REVLOOP_PROCEDURE` at `commands/remote-loop.md`.
- **Breaking:** `/revloop:local-loop` pushes the branch and opens a pull request by default, so it
  needs `gh` and the rules `Bash(gh pr create:*)` and `Bash(gh pr list:*)`. On a fork, without
  `origin` or off GitHub it aborts with `fork-unsupported` or `publish-unavailable`; pass
  `--no-publish` to end the run at the commit.
- **Breaking:** `--accept-at` against `ecc-review-pr` aborts with `no-severity-ladder`, because the
  preset no longer declares `severityLevels` and `severityMap`. Add `--grade-severity`.
- **Breaking:** both shipped local presets review on `sonnet` unless `--review-model` names another
  model, and `ecc-review-pr` runs as `invoke: subprocess`. Their command lines changed, so a
  permission rule written for the old strings no longer matches.
- `ecc-review-pr` aborts with `unparsed-review-output` in a checkout that lacks the permission
  block from `README.md` in `.claude/settings.local.json`.
- A `subprocess` reviewer's `command` may not begin with `gh` or with `{reviewModel}`.

## [0.5.0] - 2026-09-02

Fences: none changed.

### Added

- `/revloop:review-loop-local` runs a review command on your machine, fixes its findings and ends
  at a commit. It never calls `gh` and grants `Bash(git:*)` only, so the review command prompts
  once per round. `defaults.localReviewer` and `defaults.localMaxRounds` set its reviewer and cap.
- `--accept-at <level>` on both loops sets the highest severity that may be left unfixed. It is a
  flag only. Accepted findings are still read and recorded: in a reply on the pull request, or in
  the local commit's `Accepted:` block.
- Aborts for `--accept-at`: `no-severity-ladder` (the reviewer emits no severity),
  `unknown-accept-level`, and `unreviewed-accept-merge` (used with `--merge --auto`).
- Reviewers take a `kind`: `github-comment` (the default when absent) or `local-command`. A
  `local-command` reviewer requires `invoke` and `command` and may set `requiresPr`. The schema
  rejects the other kind's fields. A `subprocess` command may not begin with `git`.
- `local-command` presets `code-review` and `ecc-review-pr`, both `unverified`. `code-review`
  reports no severity, so `--accept-at` aborts against it.
- Local-loop aborts: `review-command-failed`, `unparsed-review-output`,
  `unconfirmed-empty-review` (a `requiresPr` reviewer returned zero findings), and
  `not-a-github-reviewer` / `not-a-local-reviewer` (the reviewer belongs to the other loop).

### Changed

- The report leads with unfixed findings at the top rung of the reviewer's `severityLevels`. It
  named `P1` literally before. With no ladder it leads with everything left unfixed.

### Fixed

- `--max-rounds` is checked when a round opens and aborts with `max-rounds`. No verdict reached its
  old row in the decision table. A clean result on the last allowed round still converges.
- A baseline lost to a newer hand-typed trigger reaches the `marker_head=none` abort, which a later
  run recovers from. It ended in `foreign-baseline` before.

## [0.4.0] - 2026-08-31

Fences: none changed.

### Added

- A trigger that draws no verdict is posted a second time, once per round. The re-post needs three
  wait chunks (24 minutes) spent on the loop's own trigger and an unchanged HEAD. Its marker
  carries `attempt=2`. The count and the threshold are fixed.
- Abort `timeout-before-retry`: `--timeout` ran out below the three-chunk floor, so nothing was
  re-posted. A re-posted round that still gets no verdict aborts with `no-verdict attempts=2`.
- Abort `foreign-baseline`: the wait returned another trigger's baseline twice in a row. The
  re-fire had no bound before. A later run takes the baseline back.
- Aborts `draft-review` (the reviewer left a `PENDING` review) and `unknown-review-state`. A
  `CHANGES_REQUESTED` review with no readable finding also aborts.

### Changed

- `--timeout` caps one trigger's wait. A re-posted round can wait about twice the flag: 64 minutes
  at the default `30m`.
- The round number skips markers that carry `attempt=`, so a re-post does not spend `--max-rounds`.

### Fixed

- A review whose body carries a severity badge counts as findings even with no inline comments. It
  was read as a clean round.
- A resumed session takes the round number and `SINCE` from the newest marker on the pull request.
  A failed marker read stops the round before any trigger is posted.
- `MERGE=failed` means the merge could not be confirmed. Read the pull request before merging
  again.

## [0.3.0] - 2026-08-25

Fences: `wait-verdict` changed (one re-approval).

### Changed

- The round number counts revloop's own trigger markers, so a pull request adopted after hand-typed
  rounds starts at round 1. The report and the round's first reply name both numbers when they
  differ.

### Fixed

- The wait picks the newest trigger by time (`createdAt`, then `databaseId`). An older hand-typed
  trigger such as `@codex review` used to win the baseline, so the round failed with
  `marker_head=none` and another bot's review could be read as the verdict.
- The `untriggered-verdict` diagnostic reports the newest signal in `bot=`.

## [0.2.0] - 2026-08-25

Fences: none changed.

### Added

- Step 3 reads the pending change, untracked files included, and runs step 10's sweeps before the
  push. Its whitespace check covers untracked files and fails on a file it cannot read.
- Step 10 names three sweeps for a finding's class: corpus, input-space and definition.
- Step 7's focus asks the reviewer for every sibling of a finding in one comment. The focus text
  may not contain the literal `revloop:trigger`.

### Changed

- **Breaking:** the granted rule list gained `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)`. If
  you copied the list from `docs/permissions.md`, copy it again. Its granular git list also gained
  `git switch`, `git fetch` and `git ls-files`.

### Fixed

- Step 6 updates the pull request body through `gh api -X PATCH`. `gh pr edit --body-file` fails
  on `gh` 2.4.0 and leaves the body unchanged.

## [0.1.0] - 2026-08-23

Fences: initial release.

### Added

- `/revloop:review-loop` (`commands/review-loop.md`) carries a change through branch, verify,
  commits, push, pull request, reviewer trigger and fixes until the reviewer returns no findings.
  Flags: `--reviewer`, `--merge`, `--auto`, `--max-rounds` (default 10), `--timeout` (default
  `30m`).
- `.revloop.json` configuration with a JSON Schema and four examples. The base branch, verify
  commands, branch prefixes and commit conventions are auto-detected.
- `--merge` and `--auto` are flags only. The schema rejects `defaults.merge` and `defaults.auto`.
- Reviewer presets `codex`, `gemini` and `claude`. `copilot` is `unsupported` and aborts with
  `no-comment-trigger`.
- Fences `wait-verdict`, `wait-ci` and `merge`. Each exits `no-branch` on a detached HEAD.
- The command grants four `gh api` rules scoped to `repos/{owner}/{repo}/`: plain, `-X POST`,
  `-X PUT` and `--paginate`. `docs/permissions.md` lists them and covers the Codex approval policy
  and sandbox, which must allow network access.
- Codex router skill under `.agents/skills/revloop/`.
- Requirements: `gh` 2.4.0, `git` 2.22, and the reviewer's GitHub integration installed on the
  repository. Forks and squash or rebase merges are unsupported.
- Development: tool versions are pinned in `mise.toml`. Run `mise install` before
  `npm run check:all`, or the `shellcheck` and `jq` checks are skipped.

[0.16.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.16.0
[0.15.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.15.0
[0.14.1]: https://github.com/iwmaeda/revloop/releases/tag/v0.14.1
[0.14.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.14.0
[0.13.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.13.0
[0.12.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.12.0
[0.11.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.11.0
[0.10.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.10.0
[0.9.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.9.0
[0.8.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.8.0
[0.7.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.7.0
[0.6.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.6.0
[0.5.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.5.0
[0.4.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.4.0
[0.3.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.3.0
[0.2.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.2.0
[0.1.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.1.0
