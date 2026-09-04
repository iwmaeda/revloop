---
description: Claude on a pull request — branch, split commits, push, PR, trigger @claude review, fix findings, until it converges
argument-hint: "[--merge] [--auto] [--accept-at <level>] [--max-rounds <n>] [--timeout <dur>]"
disable-model-invocation: true
allowed-tools: Bash(gh api repos/{owner}/{repo}/:*), Bash(gh api -X POST repos/{owner}/{repo}/:*), Bash(gh api -X PUT repos/{owner}/{repo}/:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Bash(gh api --paginate repos/{owner}/{repo}/:*), Bash(gh api graphql:*), Bash(gh pr:*), Bash(gh repo view:*), Bash(git:*), Read, Edit, Write, Grep, Glob
---

# revloop — the Claude pull-request loop

Carry the work tree's changes through **branch → verify → split commits → push → open a PR → trigger
the reviewer → classify and fix its findings**, and repeat until the review converges.
The reviewer is the Claude GitHub app.

**The reviewer is fixed by which command you typed, not by a flag.** That is why this file exists and
why there is one like it per reviewer: a flag that selects a reviewer is a flag that can select the
wrong one, and the reviewer decides which bot login the wait filters on, which rungs your acceptance
floor is measured against, and which aborts are reachable at all.

**This command does not author the change.** Write the code or docs in ordinary work; this layer only
carries a finished change through review.

## The reviewer

|            |                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------- |
| Definition | `${CLAUDE_PLUGIN_ROOT}/reviewers/claude.json`                                               |
| Card       | `${CLAUDE_PLUGIN_ROOT}/reviewers/claude.md` — what was measured, when, and where            |
| Trigger    | `@claude review`, posted as a comment carrying the revloop marker                           |
| Severity   | **none.** `--accept-at` is resolved by grading — see below                                  |
| Status     | **`unverified`** — shipped as a starting point. Nobody has watched this one work end to end |

## Flags

| Flag                | Default        | Effect                                                                                 |
| ------------------- | -------------- | -------------------------------------------------------------------------------------- |
| `--merge`           | off, flag only | After convergence, wait for green CI and **then** merge                                |
| `--auto`            | off, flag only | Do not stop for confirmation. **The flag itself is the approval**                      |
| `--accept-at <lvl>` | off, flag only | Findings at `<lvl>` and below may be left unfixed. Everything above it still blocks    |
| `--max-rounds <n>`  | `10`           | Abort if the loop has not converged within this many rounds                            |
| `--timeout <dur>`   | `30m`          | **Cumulative** cap on waiting for **one trigger's** verdict. A round fires at most two |

**`--merge`, `--auto` and `--accept-at` have no configuration key, and adding one would be a defect.**
`--max-rounds` and `--timeout` may come from `.revloop.json`; these three may not. That file belongs to
whatever repository you are working in, including one you just cloned. A repository that could set
`auto` would delete both of your confirmation points, one that could set `merge` would grant its own
merge, and one that could set `accept-at` would lower its own review bar while the run still reported a
clean convergence. **The flag is the approval, so it has to come from the person typing it.**

**`--accept-at` names one of the four canonical rungs here, and starts a grader.** This reviewer
declares no severity vocabulary, so there is no native rung to name and nothing for the procedure to
match against. The rungs come from a **separate subprocess on the builtin `sonnet`**, specified in
`procedures/severity-grading.md`: it is not told the acceptance floor, it does not fix what it grades,
and every rung it produces is marked `graded` in the replies, the report and the commit.

**That costs one subprocess and one permission prompt per round**, and step 1 prints the grader's
command line in full and expanded, beside the resolved floor, before the first round runs. It is the
only command in the remote family that does this — `codex` and `gemini` emit their own rungs.

## What differs for this reviewer

- **It is the one remote preset with no severity ladder**, which is the whole of the paragraph above.
- **Its verdict surface has not been measured.** The card records `verdict on: unknown` — whether a
  finding arrives as a review, as an issue comment, or as both is exactly what a first driven run would
  establish, and the procedure reads both surfaces unconditionally for that reason.
- **Nothing is known about its clean phrase, its quota wording, or whether it tolerates the marker.**
  The definition therefore asserts none of them, and `markerTolerated` falls to its `unverified`
  default rather than to a claim.
- **Step 1 says the status out loud and the final report repeats it.** An unverified preset is a
  starting point, not a fault — but the reader of the report should not have to open a card to learn
  that nobody has watched it work.

## Run the procedure

**Resolve `procedures/remote-loop.md` and read it in full before touching git, the GitHub API, or any file.**
Stop at the first hit:

1. `${CLAUDE_PLUGIN_ROOT}/procedures/remote-loop.md`, when that variable expanded.
2. The nearest `procedures/remote-loop.md` found by searching upward from the working directory.

**If neither resolves, abort with `reason=procedure-unresolved` and say so. Do not reconstruct the
procedure from this file — it does not contain one**, and a procedure improvised from a flag table is
the one failure this split makes possible.

Then follow it, with two things this command supplies:

- **The reviewer definition above.** The procedure says "the reviewer's definition" throughout and
  never resolves one itself.
- **The flags, already parsed.** `$ARGUMENTS` is interpolated here and reaches no other file, so parse
  it against the table above — rejecting any flag not in it — and hand the procedure resolved values.

## When to run it

- The change is finished and verified locally, and you want it reviewed on a pull request.
- You are prepared for an unverified preset: **record what it does**, in `.revloop/field-notes.md` and
  on the card, because that is the only way its status ever changes.
- Not for authoring a change, and not on a fork — the procedure aborts on one.
