---
description: Codex on a pull request — branch, split commits, push, PR, trigger @codex review, fix findings, until it converges
argument-hint: "[--merge] [--auto] [--accept-at <level>] [--max-rounds <n>] [--timeout <dur>]"
disable-model-invocation: true
allowed-tools: Bash(gh api repos/{owner}/{repo}/:*), Bash(gh api -X POST repos/{owner}/{repo}/:*), Bash(gh api -X PUT repos/{owner}/{repo}/:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Bash(gh api --paginate repos/{owner}/{repo}/:*), Bash(gh api graphql:*), Bash(gh pr:*), Bash(gh repo view:*), Bash(git:*), Read, Edit, Write, Grep, Glob
---

# revloop — the Codex pull-request loop

Carry the work tree's changes through **branch → verify → split commits → push → open a PR → trigger
Codex → classify and fix its findings**, and repeat until the review converges.

**The reviewer is fixed by which command you typed, not by a flag.** That is why this file exists and
why there is one like it per reviewer: a flag that selects a reviewer is a flag that can select the
wrong one, and the reviewer decides which bot login the wait filters on, which rungs your acceptance
floor is measured against, and which aborts are reachable at all.

**This command does not author the change.** Write the code or docs in ordinary work; this layer only
carries a finished change to a pull request and back.

## The reviewer

|            |                                                                                            |
| ---------- | ------------------------------------------------------------------------------------------ |
| Definition | `${CLAUDE_PLUGIN_ROOT}/reviewers/codex.json`                                               |
| Card       | `${CLAUDE_PLUGIN_ROOT}/reviewers/codex.md` — what was measured, when, and where            |
| Trigger    | `@codex review`, posted as a comment carrying the revloop marker                           |
| Severity   | `P1` > `P2` > `P3`, emitted and measured — so **`--accept-at` never starts a grader here** |
| Status     | `verified` — driven end to end through real pull requests by the maintainers               |

**Read the definition file.** It is the only place the reviewer's identity comes from, and the
procedure resolves everything about the reviewer out of it.

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

**`--accept-at` resolves natively here.** `--accept-at P2` leaves `P1` blocking and makes `P2` and `P3`
acceptable. A canonical rung resolves through the definition's `severityMap`. The procedure's
`## The acceptance floor` note states both passes and every abort between them.

## What differs for this reviewer

- **Terminal signals arrive as issue comments, and findings as a review** — and a review body can
  carry a complete finding with zero inline comments, so a round is never called clean by counting
  inline comments alone. The card records the round this was measured on.
- **This reviewer emits its own rungs**, so nothing on this command ever starts a grading subprocess.
  It is the cheapest of the remote family in permission prompts for that reason.
- **The rate-limit reply arrives in about ten seconds**, two orders of magnitude faster than a real
  verdict. The procedure aborts on it and never retries: the quota recovers with time, and another
  round spends the loop against a reviewer that cannot answer.

## Run the procedure

**Resolve `procedures/remote-loop.md` and read it in full before touching git, the GitHub API, or any
file.** Stop at the first hit:

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
- A previous run was interrupted. **Every step checks whether it is already done**, so re-running this
  same command resumes rather than restarting.
- Not for authoring a change, and not on a fork — the procedure aborts on one.
