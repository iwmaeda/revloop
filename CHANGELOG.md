# Changelog

All notable changes to this project are documented here.

**Fence changes are called out explicitly.** The shell fences in
[`commands/review-loop.md`](commands/review-loop.md) are matched by permission rules on their exact
text, so editing one costs every user a single re-approval. See
[`docs/permissions.md`](docs/permissions.md).

## [0.1.0] - 2026-08-19

First release. Everything below happened before it, so **no re-approval is owed to anyone**: there
was no earlier version for a fence to have changed from. The fence-related entries are recorded
anyway, because "record every fence edit" is the rule, and a rule that is skipped when it is
convenient is not one.

### Added

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

[0.1.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.1.0
