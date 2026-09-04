---
description: Claude Code's /code-review on this machine — branch, verify, commit, review, fix findings, then push and open a PR
argument-hint: "[--model <name>] [--no-publish] [--accept-at <level>] [--auto] [--max-rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh repo view:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Read, Edit, Write, Grep, Glob, Skill
---

# revloop — the local /code-review loop

Carry the work tree's changes through **branch → verify → commit → run the review command on this machine →
classify and fix its findings**, and repeat until the review converges. Then push the branch and open a
pull request on it, unless `--no-publish` says to stop at the commit.
The reviewer is Claude Code's own review command, run as a subprocess.

**The reviewer is fixed by which command you typed, not by a flag.** That is why this file exists and
why there is one like it per reviewer: a flag that selects a reviewer is a flag that can select the
wrong one, and the reviewer decides what runs on your machine, where this run publishes, and which
rungs your acceptance floor is measured against.

**This command does not author the change.** Write the code or docs in ordinary work; this layer only
carries a finished change through review.

## The reviewer

|              |                                                                                       |
| ------------ | ------------------------------------------------------------------------------------- |
| Definition   | `${CLAUDE_PLUGIN_ROOT}/reviewers/code-review.json`                                    |
| Card         | `${CLAUDE_PLUGIN_ROOT}/reviewers/code-review.md` — what was measured, when, and where |
| Command      | `claude --model {reviewModel} -p "/code-review medium"`, run as a subprocess          |
| `requiresPr` | `false` — it reads the local range, so this run **publishes after convergence**       |
| Severity     | **none.** `--accept-at` is resolved by grading — see below                            |
| Status       | `unverified`                                                                          |

## Flags

| Flag                | Default        | Effect                                                                              |
| ------------------- | -------------- | ----------------------------------------------------------------------------------- |
| `--model <name>`    | `sonnet`       | The model **the reviewer** runs on. The fixing is unaffected                        |
| `--no-publish`      | off, flag only | End at a commit. No push, no pull request, no `gh` call in any step                 |
| `--accept-at <lvl>` | off, flag only | Findings at `<lvl>` and below may be left unfixed. Everything above it still blocks |
| `--auto`            | off, flag only | Do not stop for confirmation. **The flag itself is the approval**                   |
| `--max-rounds <n>`  | `5`            | Abort if the loop has not converged within this many rounds                         |

**`--auto`, `--accept-at`, `--no-publish` and `--model` have no configuration key.** Only
`--max-rounds` does, as `defaults.localMaxRounds` — **not `defaults.maxRounds`, which belongs to the
pull-request procedure alone.** One shared key let a remote-oriented value silently raise this loop's
cap, and this loop's cap is the only brake it has.

**`--model` is absent from that file for a second and sharper reason than the others.** Its value is
**expanded into a command line** at the `{reviewModel}` placeholder, so a key would be the first thing
revloop interpolates into a shell command out of a repository-supplied file. It comes from the person
typing it, or from the builtin, and from nowhere else.

**`--accept-at` names one of the four canonical rungs here, and starts a grader.** No run of this
command has ever emitted a severity, on any finding, in any form — that absence is measured across five
rounds and recorded on the card, and it is why the definition declares no ladder. The rungs come from a
**separate subprocess on the resolved `--model`**, specified in `procedures/severity-grading.md`: it is
not told the acceptance floor, it does not fix what it grades, and every rung it produces is marked
`graded` in the replies, the report and the commit.

**That costs one subprocess and one permission prompt per round, on top of the review itself.** Step 1
prints the grader's command line in full and expanded, beside the review command and the resolved
floor, before the first round runs.

## What differs for this reviewer

- **`requiresPr` is `false`, so publishing happens once, after the loop converges.** Pushing earlier
  sets an upstream, and a reviewer that resolves its own target may then resolve a different one. The
  placement is read off the definition rather than given a flag, so there is nothing to set wrong.
- **The output shape follows the model pin.** Three shapes have been observed from this one command —
  a `Findings (N):` list unpinned, a fenced JSON array under `sonnet`, and prose naming what it
  reviewed and stating a count. The card records all three, and the procedure refuses to parse loosely
  rather than accepting a fourth by widening.
- **This is a weaker signal than a pull-request reviewer, and the procedure says so.** A local reviewer
  sharing the fixing model is not an independent check, and **a different model is the only thing that
  makes it one** — which is why the cheap configuration and the more independent one are the same
  configuration.

## Run the procedure

**Resolve `procedures/local-loop.md` and read it in full before touching git or any file.**
Stop at the first hit:

1. `${CLAUDE_PLUGIN_ROOT}/procedures/local-loop.md`, when that variable expanded.
2. The nearest `procedures/local-loop.md` found by searching upward from the working directory.

**If neither resolves, abort with `reason=procedure-unresolved` and say so. Do not reconstruct the
procedure from this file — it does not contain one**, and a procedure improvised from a flag table is
the one failure this split makes possible.

Then follow it, with two things this command supplies:

- **The reviewer definition above.** The procedure says "the reviewer's definition" throughout and
  never resolves one itself.
- **The flags, already parsed.** `$ARGUMENTS` is interpolated here and reaches no other file, so parse
  it against the table above — rejecting any flag not in it — and hand the procedure resolved values.

## When to run it

- You want a review before anything reaches GitHub, or on a repository that has no reviewer bot.
- You want the cheapest round this plugin offers: one subprocess, no waiting on anyone else.
- With `--no-publish` when the branch should end at a commit. That run makes no `gh` call in any step.
