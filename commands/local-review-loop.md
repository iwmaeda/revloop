---
description: Claude Code's /code-review on this machine — branch, verify, commit, review, fix findings, then push and open a PR
argument-hint: "[--model <name>] [--no-publish] [--rigor <level>] [--auto] [--max-rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh repo view:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Read, Edit, Write, Grep, Glob, Skill
---

# revloop — the local /code-review loop

Carry a finished change through branch → verify → commit → `/code-review` on this machine → fixes,
and repeat until the review converges. Then push the branch and open a pull request, unless
`--no-publish` is given. This command does not author the change.

## The reviewer

|              |                                                                              |
| ------------ | ---------------------------------------------------------------------------- |
| Definition   | `${CLAUDE_PLUGIN_ROOT}/reviewers/code-review.json`                           |
| Card         | `${CLAUDE_PLUGIN_ROOT}/reviewers/code-review.md`                             |
| Command      | `claude --model {reviewModel} -p "/code-review medium"`, run as a subprocess |
| `requiresPr` | `false`. The run publishes once, after the loop converges                    |
| Severity     | none. Findings are graded at `minimal` and `standard`                        |
| Status       | `unverified`                                                                 |

Read the definition file before step 1. The reviewer's identity comes from it and from nowhere else.

## Flags

Arguments: `$ARGUMENTS`

Parse them against this table and reject any flag that is not in it.

| Flag               | Default    | Effect                                                             |
| ------------------ | ---------- | ------------------------------------------------------------------ |
| `--model <name>`   | `sonnet`   | The model the reviewer runs on. The fixing is unaffected           |
| `--no-publish`     | off        | End at the commit: no push, no pull request, no `gh` call          |
| `--rigor <level>`  | `standard` | How strictly the run must finish. See `procedures/rigor-levels.md` |
| `--auto`           | off        | Do not stop for confirmation                                       |
| `--max-rounds <n>` | `3`        | Abort if the loop has not converged within this many rounds        |

`--max-rounds` may also come from `.revloop.json`, as `defaults.localMaxRounds`. The other flags have
no configuration key. The `--max-rounds` default shown is the one for `standard`: when neither the
flag nor the key sets it, the level does.

## What differs for this reviewer

- This reviewer emits no severity. At `minimal` and `standard`, which is the default, a grader
  subprocess on the resolved `--model` ranks the findings every round: a second subprocess and a
  second permission prompt per round. See `procedures/severity-grading.md`. `--rigor thorough`
  avoids it.
- The output shape depends on the model. The card lists the shapes under `## Output shape`. Do not
  parse a shape it does not list.

## Run the procedure

Read `${CLAUDE_PLUGIN_ROOT}/procedures/local-loop.md` in full before touching git or any
file. Then follow it, with the reviewer definition and the parsed flags from this file.

If that variable did not expand, or the file cannot be read, abort with
`reason=procedure-unresolved`. Never search the working tree for the procedure, and never reconstruct
it from this file.
