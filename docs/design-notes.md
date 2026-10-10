# Design notes

Why the loops work the way they do. The rules themselves are in [`procedures/`](../procedures/).

## The baseline timestamp

The wait takes the newest trigger as its baseline and accepts a verdict that arrives after it.

| Baseline | Consequence                                                                                                                          | Class                             |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------- |
| Too new  | A verdict that already arrived is dropped: the round times out, or finishes clean over a dropped comment that should have stopped it | Liveness; safety for that comment |
| Too old  | A previous round's "no issues" is accepted as this round's                                                                           | Safety                            |

Findings that arrive as a review are also bound to a commit. A terminal comment is bound only by
time, so the baseline never moves backwards: walking back to an older trigger when no verdict is
found would trade a timeout for a false clean result. Moving it forward is allowed, which is why a
round may re-post its trigger once, and why a later run may re-take a rate-limited trigger.

A review drawn by a hand-typed trigger is read only when it is by the configured reviewer and
GitHub's `commit_id` for it equals HEAD. Such a round never converges or merges; the loop then opens
an ordinary round. If no review by the configured reviewer stands at HEAD or at an ancestor of it,
the run aborts instead, and a later run opens that round.

## Why the loop marks its own triggers

The wait has to recognise a trigger, and matching by name also matches ordinary comments such as
`@someone review this before merging`. So revloop appends a marker to the trigger it posts, and
matches that:

```text
<!-- revloop:trigger v=1 reviewer=codex bot=chatgpt-codex-connector head=1a2b3c4d oid=<full commit sha> round=3 -->
```

- `bot=` filters out every other bot before classification, so a deploy-preview or coverage comment
  cannot end the wait.
- `oid=`, `round=` and `attempt=` keep the run's state on the pull request, so an interrupted run
  resumes without local state. `head=` is the short form of `oid=`, for display.
- Reviewer identity reaches the wait through this comment and never through a configuration file.
- A hand-typed `@codex review` still anchors a baseline, but it carries no `head=` and no `bot=`, so
  the bot filter admits any bot and a verdict behind it is not bound to a commit.

## Permission rules and fence bytes

A Claude Code permission rule matches the start of a command string. Three decisions follow.

- `gh api` calls use `repos/{owner}/{repo}/`, which `gh` expands from the current remote, so the
  rules can be scoped to one repository.
- `-X POST`, `-X PUT`, `-X PATCH` and `--paginate` have their own rules, because the flag comes
  before the path.
- The fences take no arguments. A script that embedded a pull-request number or a path would differ
  on every run and be prompted for every time. The fences resolve the repository, the branch and the
  pull request themselves, and the teardown fence finds the worktrees to remove in
  `revloop/worktrees.txt` under the checkout's git directory.

The fences are inline in the procedure instead of shipped as script files. Behind a path, a plugin
update could change what runs under a grant given once. Inline, an edit changes the command string
and asks every user to approve it again. For the same reason no configuration value reaches a fence,
and the list of interim comments the wait ignores lives inside the fence. A comment that list does
not name is marked on the pull request instead: the loop adds a reaction from your account under step
9's skip bullet, and a firing of the fence whose fetch shows one drops that comment. What a mark can
cost is ruled by that bullet, the marked-`cid=` bullet, step 7's condition (d), step 11's gate and
step 12.

## Two procedures, seven commands

The remote loop waits for a verdict that arrives later, from a GitHub App. The local loop reads the
output of a command on your machine. About half of the remote procedure handles the wait, so the
local loop is a separate procedure, and it cites the shared preparation steps by number.

The reviewer is chosen by the command you type. It decides which bot the wait listens to, which
severity rungs block and whether a merge is available, so each command offers only the flags that
apply to its reviewer. Every `remote-*` command runs one procedure and every `local-*` command runs
the other.

## The rigor level

`--rigor` sets the acceptance floor, the round cap, the sweeps a round owes after a fix, and a
sufficiency test before the run finishes. The specification is
[`procedures/rigor-levels.md`](../procedures/rigor-levels.md); the operator's summary is in
[Configuration](configuration.md#the-rigor-level).

- The floor decides when the loop may stop. It never decides what is read: every finding is
  fetched, classified, answered and listed in the report.
- The sufficiency test can keep a run going. It cannot end one early.
- The floor is measured on one ladder, `critical > high > medium > low`, and a reviewer's
  `severityMap` maps its own rungs onto it. `severityLevels` records what the reviewer emits; the map
  is a judgement, so step 1 prints the resulting floor before the first round.
- The loop never ranks findings itself, because it is the party that has to fix them. When a
  reviewer emits no severity, at `minimal` and `standard` a separate subprocess grades the findings.
  The grader is not told the floor and does not see the session, and every rung it assigns is marked
  `graded`. Nothing
  establishes that its rungs are accurate, so a graded convergence is a weaker result than one on the
  reviewer's own rungs.
- `--rigor`, `--merge` and `--auto` have no configuration key, because the configuration file comes
  from the repository under review. A level with an acceptable band refuses `--merge --auto`: the
  merge would follow accepted findings that nobody read.

## What a local run does not establish

A local reviewer on the same model that wrote the code is not an independent check. Running it as a
subprocess keeps it from reading the session's reasoning, and the default review model of a
subprocess with `{reviewModel}`, `sonnet`, is usually a different model from the one doing the
fixing. A skill reviewer runs on the session's model. It is still weaker than a separate reviewer.

A clean local run is a pre-flight. It reduces the defects present when the remote review starts; it
does not mean the change has been reviewed. That is why the local commands never merge.

## Where the local loop publishes

The local loop pushes the branch and opens a pull request unless `--no-publish` is given. When it
publishes depends on the reviewer's `requiresPr`.

| `requiresPr` | Publishes               | Why                                                                                                 |
| ------------ | ----------------------- | --------------------------------------------------------------------------------------------------- |
| `true`       | Before every round      | The reviewer cannot run without a pull request, which must exist and match HEAD                     |
| `false`      | Once, after convergence | A reviewer that resolves its own target may resolve a different one once the branch has an upstream |

On a fork, without an `origin`, or with a remote that is not GitHub, the run aborts and names
`--no-publish`.

## Field notes

When a round takes an unexercised path, aborts, or sees unexpected latency, the procedure appends one
line to `.revloop/field-notes.md`. The notes are for people: the loop never reads them as input,
never stages them, and caps the file at 500 lines.

`.revloop/` ignores itself. Unless git tracks anything under `.revloop/` or an existing
`.revloop/.gitignore` does not hide the file, in which case nothing is written there, the first
write into it is `.revloop/.gitignore` containing `*`, so the
notes, the grader's input and `.revloop/config.json` stay out of `git status` without a rule in your
own `.gitignore`. A tool that reads only the top-level `.gitignore`, such as prettier, still sees the
files unless you add a rule there.

The worktree ledger is not in that directory. It lives under the checkout's git directory, where no
git command reports it.

## Tests

`tests/extract-fences.sh` extracts the fences from the procedure and runs them against recorded API
responses through a `gh` stub, so the tests exercise the shipped text. `## Unexercised paths` in each
procedure lists what has not been observed against a live reviewer.

Only stable REST and GraphQL surfaces of `gh` are used, and the loop never branches on the `gh`
version.
