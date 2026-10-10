---
description: Gemini Code Assist on a pull request — branch, split commits, push, PR, trigger @gemini review, fix findings, until it converges
argument-hint: "[--merge] [--auto] [--rigor <level>] [--max-rounds <n>] [--timeout <dur>]"
disable-model-invocation: true
allowed-tools: Bash(gh api repos/{owner}/{repo}/:*), Bash(gh api -X POST repos/{owner}/{repo}/:*), Bash(gh api -X PUT repos/{owner}/{repo}/:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Bash(gh api --paginate repos/{owner}/{repo}/:*), Bash(gh api graphql:*), Bash(gh pr:*), Bash(gh repo view:*), Bash(git:*), Read, Edit, Write, Grep, Glob
---

# revloop — the Gemini pull-request loop

Carry a finished change through branch → verify → commits → push → pull request → `@gemini review` →
fixes, and repeat until the review converges. This command does not author the change.

## The reviewer

|            |                                                               |
| ---------- | ------------------------------------------------------------- |
| Definition | `${CLAUDE_PLUGIN_ROOT}/reviewers/gemini.json`                 |
| Card       | `${CLAUDE_PLUGIN_ROOT}/reviewers/gemini.md`                   |
| Trigger    | `@gemini review`, posted as a comment with the revloop marker |
| Severity   | `P1`, `P2`, `P3`. No level starts a grader                    |
| Status     | `verified`                                                    |

Read the definition file before step 1. The reviewer's identity comes from it and from nowhere else.

## Flags

Arguments: `$ARGUMENTS`

Parse them against this table and reject any flag that is not in it.

| Flag               | Default    | Effect                                                             |
| ------------------ | ---------- | ------------------------------------------------------------------ |
| `--merge`          | off        | After convergence, wait for green CI and then merge                |
| `--auto`           | off        | Do not stop for confirmation                                       |
| `--rigor <level>`  | `standard` | How strictly the run must finish. See `procedures/rigor-levels.md` |
| `--max-rounds <n>` | `5`        | Abort if the loop has not converged within this many rounds        |
| `--timeout <dur>`  | `30m`      | Cap on waiting for one trigger's verdict                           |

`--max-rounds` and `--timeout` may also come from `.revloop.json`, as `defaults.maxRounds` and
`defaults.timeout`. The other flags have no configuration key. The `--max-rounds` default shown is
the one for `standard`: when neither the flag nor the key sets it, the level does.

## What differs for this reviewer

- Findings arrive as a review, and a round returns many more of them than Codex does.
- The definition ships `@gemini review`. `/gemini review` has also drawn a review. If your
  installation answers only that form, copy the definition, change `trigger`, and run
  `/revloop:remote-custom-loop`.
- The definition has no `cleanPatterns` and no `rateLimitPatterns`, so a quota reply reads as an
  ordinary bot comment.

## Run the procedure

Read `${CLAUDE_PLUGIN_ROOT}/procedures/remote-loop.md` in full before touching git, the GitHub API or any
file. Then follow it, with the reviewer definition and the parsed flags from this file.

If that variable did not expand, or the file cannot be read, abort with
`reason=procedure-unresolved`. Never search the working tree for the procedure, and never reconstruct
it from this file.
