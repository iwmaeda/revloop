---
description: Claude on a pull request — branch, split commits, push, PR, trigger @claude review, fix findings, until it converges
argument-hint: "[--merge] [--auto] [--rigor <level>] [--max-rounds <n>] [--timeout <dur>]"
disable-model-invocation: true
allowed-tools: Bash(gh api repos/{owner}/{repo}/:*), Bash(gh api -X POST repos/{owner}/{repo}/:*), Bash(gh api -X PUT repos/{owner}/{repo}/:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Bash(gh api --paginate repos/{owner}/{repo}/:*), Bash(gh api graphql:*), Bash(gh pr:*), Bash(gh repo view:*), Bash(git:*), Read, Edit, Write, Grep, Glob
---

# revloop — the Claude pull-request loop

Carry a finished change through branch → verify → commits → push → pull request → `@claude review` →
fixes, and repeat until the review converges. This command does not author the change.

## The reviewer

|            |                                                               |
| ---------- | ------------------------------------------------------------- |
| Definition | `${CLAUDE_PLUGIN_ROOT}/reviewers/claude.json`                 |
| Card       | `${CLAUDE_PLUGIN_ROOT}/reviewers/claude.md`                   |
| Trigger    | `@claude review`, posted as a comment with the revloop marker |
| Severity   | none. Findings are graded at `minimal` and `standard`         |
| Status     | `unverified`                                                  |

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

- This reviewer emits no severity. At `minimal` and `standard`, which is the default, a grader
  subprocess on `sonnet` ranks the findings every round, at one permission prompt per round. See
  `procedures/severity-grading.md`. `--rigor thorough` avoids it.
- This preset has not been run end to end. Whether its findings arrive as a review or as comments,
  its clean phrase, its quota wording and whether it tolerates the marker are all unknown. Step 1
  and the final report state the status.
- Say in the report what was observed of each of those, so that the card can be updated.

## Run the procedure

Read `${CLAUDE_PLUGIN_ROOT}/procedures/remote-loop.md` in full before touching git, the GitHub API or any
file. Then follow it, with the reviewer definition and the parsed flags from this file.

If that variable did not expand, or the file cannot be read, abort with
`reason=procedure-unresolved`. Never search the working tree for the procedure, and never reconstruct
it from this file.
