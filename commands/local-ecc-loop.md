---
description: ECC's /ecc:review-pr on this machine — branch, verify, commit, push, PR, review, fix findings, until it converges
argument-hint: "[--model <name>] [--no-publish] [--rigor <level>] [--auto] [--max-rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh repo view:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Read, Edit, Write, Grep, Glob, Skill
---

# revloop — the local ECC review loop

Carry a finished change through branch → verify → commit → `/ecc:review-pr` on this machine → fixes,
and repeat until the review converges. Then push the branch and open a pull request, unless
`--no-publish` is given. This command does not author the change.

## The reviewer

|              |                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------- |
| Definition   | `${CLAUDE_PLUGIN_ROOT}/reviewers/ecc-review-pr.json`                                      |
| Card         | `${CLAUDE_PLUGIN_ROOT}/reviewers/ecc-review-pr.md`                                        |
| Command      | `claude --model {reviewModel} --effort medium … -p "/ecc:review-pr"`, run as a subprocess |
| `requiresPr` | `true`. The run publishes before every review                                             |
| Severity     | none. Findings are graded at `minimal` and `standard`                                     |
| Status       | `unverified`                                                                              |

Read the definition file before step 1. The reviewer's identity comes from it and from nowhere else.

The `…` in the Command row stands for a literal the definition holds in full. Read the command from
the definition, never from this row.

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
- The reviewer reads the pull request itself. Under `--no-publish`, step 1 asks you to confirm that
  one exists, and zero findings are not read as clean (`unconfirmed-empty-review`).
- The definition pins `--effort medium`. To review at another level, copy the definition, change
  that token, and run the copy with `/revloop:local-custom-loop`.
- The reviewer needs the permission block from the README in the checkout's
  `.claude/settings.local.json` to reach `gh`. Without it the review returns no findings in a shape
  the card lists, and the round aborts with `unparsed-review-output`.
- The command carries an instruction telling the reviewer that the run is non-interactive, and to
  read the pull request with `gh pr view --json` and `gh pr diff`: a plain `gh pr view` fails on
  `gh` 2.4.0. A round can still end on a question, or without naming the pull request, and either
  aborts with `unparsed-review-output`.

## Run the procedure

Read `${CLAUDE_PLUGIN_ROOT}/procedures/local-loop.md` in full before touching git or any
file. Then follow it, with the reviewer definition and the parsed flags from this file.

If that variable did not expand, or the file cannot be read, abort with
`reason=procedure-unresolved`. Never search the working tree for the procedure, and never reconstruct
it from this file.
