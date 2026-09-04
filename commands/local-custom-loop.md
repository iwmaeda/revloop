---
description: A review command you define, on this machine — branch, verify, commit, review, fix findings, then push and open a PR
argument-hint: "--config <path> [--model <name>] [--no-publish] [--rigor <level>] [--auto] [--max-rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh repo view:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Read, Edit, Write, Grep, Glob, Skill
---

# revloop — the local loop for a reviewer you define

Carry the work tree's changes through **branch → verify → commit → run the review command on this machine →
classify and fix its findings**, and repeat until the review converges. Then push the branch and open a
pull request on it, unless `--no-publish` says to stop at the commit.
The reviewer is a review command whose definition you supply.

**The reviewer is fixed by which command you typed, not by a flag.** That is why this file exists and
why there is one like it per reviewer: a flag that selects a reviewer is a flag that can select the
wrong one, and the reviewer decides what runs on your machine, where this run publishes, and which
rungs your acceptance floor is measured against.

**This command does not author the change.** Write the code or docs in ordinary work; this layer only
carries a finished change through review.

## The reviewer

**`--config <path>` is required and there is no default.** It names a reviewer definition file — the
same format the shipped presets use, documented in `schema/reviewer.schema.json` and validated against
it. There is one format and one loader: the file you write is read exactly as
`reviewers/code-review.json` is, and a built-in gets no special case.

**The file name is the name**, and there is no `name` key to drift from it.

Copy `reviewers/code-review.json` or `examples/reviewer.local.json` to start from.

**Write `{reviewModel}` wherever your command takes a model.** The procedure expands it to the resolved
`--model`, or to the builtin `sonnet`. A command carrying no placeholder is simply not pinned, and
`--model` then aborts against it rather than passing silently — **splicing a flag into an arbitrary
command guesses that command's CLI**, and one reviewer spells it `--model`, another `-m`, another an
environment variable, and another takes no model at all.

**Four aborts belong to this command and to no built-in:**

| `reason`               | Condition                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------- |
| `config-not-found`     | `--config` was absent, or names no readable file                                        |
| `config-invalid`       | The file fails `schema/reviewer.schema.json`. Print the validator's message             |
| `unsafe-reviewer-name` | The file's stem does not match `^[a-z0-9][a-z0-9-]*$`                                   |
| `not-a-local-reviewer` | The definition's `kind` is `github-comment`. Name `remote-custom-loop`, which drives it |

**`kind` is checked before anything reads a `command`**, for the reason its sibling gives: a
`github-comment` definition has a `trigger` and a `botLogin` and no way to be run here, and failing
over to "review it yourself" would report a self-review as a review.

## Flags

| Flag               | Default        | Effect                                                               |
| ------------------ | -------------- | -------------------------------------------------------------------- |
| `--config <path>`  | **required**   | The reviewer definition this run drives                              |
| `--model <name>`   | `sonnet`       | The model **the reviewer** runs on. The fixing is unaffected         |
| `--no-publish`     | off, flag only | End at a commit. No push, no pull request, no `gh` call in any step  |
| `--rigor <level>`  | `standard`     | How strictly this run must finish. It decides when the loop may stop |
| `--auto`           | off, flag only | Do not stop for confirmation. **The flag itself is the approval**    |
| `--max-rounds <n>` | `3`            | Abort if the loop has not converged within this many rounds          |

**`--auto`, `--rigor`, `--no-publish` and `--model` have no configuration key.** Only
`--max-rounds` does, as `defaults.localMaxRounds` — **not `defaults.maxRounds`, which belongs to the
pull-request procedure alone.** One shared key let a remote-oriented value silently raise this loop's
cap, and this loop's cap is the only brake it has. **The level supplies that number only where
neither the flag nor the key answered** — see `procedures/rigor-levels.md`.

**`--model` is absent from that file for a second and sharper reason than the others.** Its value is
**expanded into a command line** at the `{reviewModel}` placeholder, so a key would be the first thing
revloop interpolates into a shell command out of a repository-supplied file. It comes from the person
typing it, or from the builtin, and from nowhere else.

**`--config` is flag-only for a sharper reason still.** `.revloop.json` no longer defines reviewers
at all, and a `subprocess` definition holds a **shell command line**: a repository that could choose it
would choose a string this procedure runs.

**`--rigor` measures its floor against whatever the definition declares** — the reviewer's own rungs
carried onto revloop's canonical ladder by the required `severityMap`, or, **when the definition
declares no ladder, by grading** on the resolved `--model`, per `procedures/severity-grading.md`.
**At `thorough` and `exhaustive` neither is read**, because nothing is acceptable at either — **and
the default is neither of them**, so a definition with no ladder grades on every untyped run, at a
second subprocess and a second permission prompt per round.
`procedures/rigor-levels.md` states the four levels and what else each one moves.

**A definition that omits `severityLevels` weakens your floor rather than stopping the run.** A graded
convergence is a weaker result than a reviewed one; step 1 prints `severity source` as `reviewer` or
`grader (<model>)` before the first round, and every graded rung says `graded` wherever a rung is
written.

## What differs for this reviewer

- **Your `command` string is never pre-approved.** It is absent from this command's `allowed-tools`
  exactly as the verify commands are, so the permission system sees it every round, and step 1 prints
  it in full and expanded before the first one.
- **It may not begin with `git`, with `gh`, or with `{reviewModel}`** — as a string prefix, with no
  exception for a longer name. Those are the prefixes this command already grants, so such a string
  would run with no prompt at all. The procedure re-checks the **expanded** string before running it,
  because a static rule about a template is not a rule about what ran.
- **`invoke: skill` has no model boundary.** The review then runs on this session's model, spending
  this session's context, and `--model` aborts against it with `reason=no-model-boundary` rather than
  passing silently. Prefer `subprocess`.
- **Set `requiresPr` from your command's behaviour**, not from whether a pull request happened to exist
  when you looked: it decides where this run publishes, and getting it wrong makes the reviewer read a
  stale diff or an empty range.

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

- You have a review command on this machine that no shipped preset drives.
- You want a shipped local preset with one field changed — copy its definition, edit it, and point
  `--config` at your copy.
- With `--no-publish` when the branch should end at a commit.
