# Changelog

All notable changes to this project are documented here.

**Fence changes are called out explicitly.** The shell fences in
[`commands/review-loop.md`](commands/review-loop.md) are matched by permission rules on their exact
text, so editing one costs every user a single re-approval. See
[`docs/permissions.md`](docs/permissions.md).

## [Unreleased]

**No fence changed, so no re-approval is owed.** All three fences still match the hashes recorded in
`tests/fence-hashes.txt`; `tests/fence-guards.test.sh` proves it on every run.

Everything here comes from one measurement: seven pull requests driven through this loop with codex
in a single repository (private, so `reviewers/codex.md` anonymises it as repo C, 2026-08). Their
round counts were 2, 3, 3, 8, 10, 21, and 30, and **a round returns roughly one finding** — 23
finding-bearing rounds on one PR at a mean of 1.22, never more than 2. **The rounds a pull request
needs is therefore roughly the number of defects present when the trigger fires**, which is
arithmetic on the measurement rather than a separate observation, and is labelled derived wherever
it appears.

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
- **Step 3 now reads the diff before step 4.** The procedure already asserted that the only way to
  spend fewer rounds is to have fewer defects at fire time, and then fired anyway. Step 3 already
  argued the same thing about CI — a red run wastes a round, so pay for it before pushing — and the
  measurement makes the reviewer the more expensive of the two. **It is deliberately not a generic
  self-review**: on the measured PR the author was an LLM that had already missed those findings
  once, so a second general reading by the same reader is not supported by anything. It is step 10's
  sweeps aimed at the diff, one step earlier. The pass must be reported, because a self-review nobody
  can see is indistinguishable from one that never happened.
- **Step 7's focus asks for every sibling in one comment.** The focus already named the class; it did
  not say what to ask for. That this raises findings per round is **derived, not measured** — what is
  measured is only that codex accepts the suffix — and the paragraph says so.
- **Step 7 forbids the literal `revloop:trigger` in the focus text.** The wait fence reads the marker
  as the text after the first occurrence of that literal, and the focus precedes the marker, so a
  focus containing it wins the split. Measured against the fence's own jq program: the marker string
  becomes `markers in the diff--`, carrying no `bot=`, `head=`, `reviewer=`, or `round=`. Step 9 then
  aborts on `marker_head=none` (fail-closed, one wait spent) — but **an empty `bot=` disables the
  fence's bot filter**, so any other bot on the pull request would have satisfied the wait had the
  round continued. The schema already rejects a configured `trigger` containing the literal; the
  focus is composed in the procedure, so the rule now exists there too.
  `tests/fixtures/jq/focus-carrying-marker` pins it, with the existing clean-comment fixture as the
  control that proves the assertions discriminate.
- **`reviewers/codex.md` carries a second findings-per-round sample** and four new measurements:
  findings concentrate (28 in 3 files, 30 in 5) and the next one repeats the previous file 39–52% of
  the time across four PRs; severity predicts nothing (15/15 P2 on one PR, 15/15 P1 on another,
  25 P1 + 3 P2 on a third, P3 zero throughout); the per-PR round counts; and the input-form-per-round
  shape. **The second sample is not independent of the existing 37-round one** — same repository,
  same account — and is written as corroborating the centre rather than the range, because presenting
  two samples from one source as two sources is the "looks measured" failure `CONTRIBUTING.md` warns
  about.
- **`tests/procedure-refs.test.sh`** fails if the procedure cites one of its own line numbers, and
  `CONTRIBUTING.md` states the rule beside it.

Changed:

- **`commands/review-loop.md` no longer cites its own line numbers.** `## Notes` named "step 10, line
  334" and "step 11, line 371". Both were correct when written and both were one insertion away from
  being silently wrong; the step numbers were already there, so the line numbers carried nothing.
- **Two copies of a measured number now point at the card that owns it** rather than restating it:
  the flags table said real PRs have needed 20+ rounds (the measured maximum is 30), and step 10's
  lead declared codex at 1–4 and gemini at 30–50 a second time.
- **Both README phase tables** describe the Prepare and Fix phases as they now behave — Prepare sweeps
  the diff before pushing, and Fix runs the sweep that matches the class rather than "the codebase
  sweep", which is now one of three and the one that does not apply to the dominant class.

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

[0.1.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.1.0
