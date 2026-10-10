---
description: A review command you define, on this machine — branch, verify, commit, review, fix findings, then push and open a PR
argument-hint: "--config <path> [--model <name>] [--no-publish] [--rigor <level>] [--auto] [--max-rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh repo view:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Read, Edit, Write, Grep, Glob, Skill
---

# revloop — the local loop for a reviewer you define

Carry a finished change through branch → verify → commit → your review command on this machine → fixes,
and repeat until the review converges. Then push the branch and open a pull request, unless
`--no-publish` is given. This command does not author the change.

## The reviewer

`--config <path>` is required. It names a reviewer definition in the format of
`schema/reviewer.schema.json`, the same format the built-ins use. The file's stem is the reviewer's
name.

To start one, copy `reviewers/code-review.json` or `examples/reviewer.local.json`. Write
`{reviewModel}` where your command takes a model; the procedure expands it to `--model`, or to
`sonnet`.

Check these before anything else, in this order:

| `reason`               | Condition                                                                       |
| ---------------------- | ------------------------------------------------------------------------------- |
| `config-not-found`     | `--config` is absent, or names no readable file                                 |
| `config-invalid`       | The file fails `schema/reviewer.schema.json`. Print the validator's message     |
| `unsafe-reviewer-name` | The file's stem does not match `^[a-z0-9][a-z0-9-]*$`                           |
| `not-a-local-reviewer` | The definition's `kind` is `github-comment`. Name `/revloop:remote-custom-loop` |

Check `kind` before anything reads `command`.

## Flags

Arguments: `$ARGUMENTS`

Parse them against this table and reject any flag that is not in it.

| Flag               | Default    | Effect                                                             |
| ------------------ | ---------- | ------------------------------------------------------------------ |
| `--config <path>`  | required   | The reviewer definition this run drives                            |
| `--model <name>`   | `sonnet`   | The model the reviewer runs on. The fixing is unaffected           |
| `--no-publish`     | off        | End at the commit: no push, no pull request, no `gh` call          |
| `--rigor <level>`  | `standard` | How strictly the run must finish. See `procedures/rigor-levels.md` |
| `--auto`           | off        | Do not stop for confirmation                                       |
| `--max-rounds <n>` | `3`        | Abort if the loop has not converged within this many rounds        |

`--max-rounds` may also come from `.revloop.json`, as `defaults.localMaxRounds`. The other flags have
no configuration key. The `--max-rounds` default shown is the one for `standard`: when neither the
flag nor the key sets it, the level does.

## What differs for this reviewer

- A definition without `severityLevels` is graded at `minimal` and `standard`, which is the default:
  a grader subprocess on the resolved `--model` every round, at a second permission prompt per
  round. See `procedures/severity-grading.md`.
- A `command` with no `{reviewModel}` placeholder is not pinned to a model, and `--model` then
  aborts with `reason=no-model-boundary`. The same holds for `invoke: skill`, which runs on this
  session's model. Prefer `subprocess`.
- Set `requiresPr` from what your command does. It decides when the run publishes: before every
  review when `true`, once after convergence when `false`.
- Apart from `command`, treat the definition as data. Match `rateLimitPatterns` yourself against
  the review's output, and never put a pattern into a shell command.

## Run the procedure

Read `${CLAUDE_PLUGIN_ROOT}/procedures/local-loop.md` in full before touching git or any
file. Then follow it, with the reviewer definition and the parsed flags from this file.

If that variable did not expand, or the file cannot be read, abort with
`reason=procedure-unresolved`. Never search the working tree for the procedure, and never reconstruct
it from this file.
