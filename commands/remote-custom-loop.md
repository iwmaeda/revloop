---
description: A reviewer you define, on a pull request — branch, split commits, push, PR, trigger it, fix findings, until it converges
argument-hint: "--config <path> [--merge] [--auto] [--rigor <level>] [--max-rounds <n>] [--timeout <dur>]"
disable-model-invocation: true
allowed-tools: Bash(gh api repos/{owner}/{repo}/:*), Bash(gh api -X POST repos/{owner}/{repo}/:*), Bash(gh api -X PUT repos/{owner}/{repo}/:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Bash(gh api --paginate repos/{owner}/{repo}/:*), Bash(gh api graphql:*), Bash(gh pr:*), Bash(gh repo view:*), Bash(git:*), Read, Edit, Write, Grep, Glob
---

# revloop — the pull-request loop for a reviewer you define

Carry the work tree's changes through **branch → verify → split commits → push → open a PR → trigger
the reviewer → classify and fix its findings**, and repeat until the review converges.
The reviewer is a reviewer whose definition you supply.

**The reviewer is fixed by which command you typed, not by a flag.** That is why this file exists and
why there is one like it per reviewer: a flag that selects a reviewer is a flag that can select the
wrong one, and the reviewer decides which bot login the wait filters on, which rungs your acceptance
floor is measured against, and which aborts are reachable at all.

**This command does not author the change.** Write the code or docs in ordinary work; this layer only
carries a finished change through review.

## The reviewer

**`--config <path>` is required and there is no default.** It names a reviewer definition file — the
same format the shipped presets use, documented in `schema/reviewer.schema.json` and validated against
it. There is one format and one loader: the file you write is read exactly as `reviewers/codex.json`
is, and a built-in gets no special case.

**The file name is the name.** There is no `name` key, so there is nothing to drift; the stem becomes
the `reviewer=` value in the trigger marker, which is why it must match `^[a-z0-9][a-z0-9-]*$`.

Copy a shipped definition to start from — `reviewers/gemini.json` is the smallest `github-comment`
one — or `examples/reviewer.custom.json`.

**Four aborts belong to this command and to no built-in**, because a built-in's definition ships with it
and cannot be any of these things:

| `reason`                | Condition                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------- |
| `config-not-found`      | `--config` was absent, or names no readable file                                      |
| `config-invalid`        | The file fails `schema/reviewer.schema.json`. Print the validator's message           |
| `unsafe-reviewer-name`  | The file's stem does not match `^[a-z0-9][a-z0-9-]*$`, so it cannot go in the marker  |
| `not-a-github-reviewer` | The definition's `kind` is `local-command`. Name `local-custom-loop`, which drives it |

**The `kind` check comes before the `trigger` check the procedure makes, and that ordering is the whole
reason it exists.** The schema forbids a `local-command` definition from carrying a `trigger` at all, so
such a reviewer fails the later check on every run — and read in the other order this row is unreachable
for exactly the configuration it was added to diagnose, leaving the operator a missing field as the
cause when the cause is a reviewer built for the other procedure.

## Flags

| Flag               | Default        | Effect                                                                                 |
| ------------------ | -------------- | -------------------------------------------------------------------------------------- |
| `--config <path>`  | **required**   | The reviewer definition this run drives                                                |
| `--merge`          | off, flag only | After convergence, wait for green CI and **then** merge                                |
| `--auto`           | off, flag only | Do not stop for confirmation. **The flag itself is the approval**                      |
| `--rigor <level>`  | `standard`     | How strictly this run must finish. It decides when the loop may stop                   |
| `--max-rounds <n>` | `5`            | Abort if the loop has not converged within this many rounds                            |
| `--timeout <dur>`  | `30m`          | **Cumulative** cap on waiting for **one trigger's** verdict. A round fires at most two |

**`--merge`, `--auto` and `--rigor` have no configuration key, and adding one would be a defect.**
`--max-rounds` and `--timeout` may come from `.revloop.json`; these three may not. That file belongs to
whatever repository you are working in, including one you just cloned. A repository that could set
`auto` would delete both of your confirmation points, one that could set `merge` would grant its own
merge, and one that could set `rigor` would lower its own review bar while the run still reported a
clean convergence. **The flag is the approval, so it has to come from the person typing it.**
**`--max-rounds` still has one**, and the level supplies that number only where neither the flag nor
the key answered — see `procedures/rigor-levels.md`.

**`--config` is flag-only for the same reason and a sharper one.** `.revloop.json` no longer defines
reviewers at all: a repository that could choose your reviewer would choose which bot login the wait
filters on and which rungs your acceptance floor is measured against.

**`--rigor` measures its floor against whatever the definition declares.** With `severityLevels`, the
rungs are carried onto revloop's canonical ladder by the required `severityMap`. **Without
`severityLevels`, they come from grading** — a separate subprocess on the builtin `sonnet`,
specified in `procedures/severity-grading.md`, costing one permission prompt per round. **At
`thorough` and `exhaustive` neither happens**: nothing is acceptable, so no rung is consumed — **and
the default is neither of them**, so a definition with no ladder grades on every untyped run.
`procedures/rigor-levels.md` states the four levels and what else each one moves.

**A definition that omits `severityLevels` therefore weakens your floor rather than stopping the run**,
and that is worth knowing before you write one: a graded convergence is a weaker result than a reviewed
one. Step 1 prints `severity source` as `reviewer` or `grader (<model>)` before the first round, and
every graded rung says `graded` in every record the run writes.

## What differs for this reviewer

- **Everything about the reviewer comes out of your file**, so the honest summary of what this command
  does is: it is the built-in commands with the definition unpinned.
- **Nothing here is measured.** A definition you wrote has no card, no status and no provenance, and
  the procedure prints it as unverified for that reason. `docs/adding-a-reviewer.md` is the checklist
  for turning a definition that works into one that is recorded as working.
- **The definition is repository-supplied data and is treated as such.** Every pattern in it is used
  model-side only; none of it reaches a shell or a jq program, and the wait fence never parses it.

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

- You have a reviewer bot that answers a comment trigger on a pull request, and no shipped preset
  drives it.
- You want to run a shipped preset with one field changed — copy its definition, edit the field, and
  point `--config` at your copy.
- Not for a reviewer that is requested rather than commented at: the procedure has only the comment
  path, and step 1 aborts with `reason=no-comment-trigger`.
