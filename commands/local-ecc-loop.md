---
description: ECC's /ecc:review-pr on this machine — branch, verify, commit, push, PR, review, fix findings, until it converges
argument-hint: "[--model <name>] [--no-publish] [--rigor <level>] [--auto] [--max-rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh repo view:*), Bash(gh api -X PATCH repos/{owner}/{repo}/:*), Read, Edit, Write, Grep, Glob, Skill
---

# revloop — the local ECC review loop

Carry the work tree's changes through **branch → verify → commit → run the review command on this machine →
classify and fix its findings**, and repeat until the review converges. Then push the branch and open a
pull request on it, unless `--no-publish` says to stop at the commit.
The reviewer is the ECC plugin's review-pr command, run as a subprocess.

**The reviewer is fixed by which command you typed, not by a flag.** That is why this file exists and
why there is one like it per reviewer: a flag that selects a reviewer is a flag that can select the
wrong one, and the reviewer decides what runs on your machine, where this run publishes, and which
rungs your acceptance floor is measured against.

**This command does not author the change.** Write the code or docs in ordinary work; this layer only
carries a finished change through review.

## The reviewer

|              |                                                                                              |
| ------------ | -------------------------------------------------------------------------------------------- |
| Definition   | `${CLAUDE_PLUGIN_ROOT}/reviewers/ecc-review-pr.json`                                         |
| Card         | `${CLAUDE_PLUGIN_ROOT}/reviewers/ecc-review-pr.md` — what was measured, when, and where      |
| Command      | `claude --model {reviewModel} -p "/ecc:review-pr"`, run as a subprocess                      |
| `requiresPr` | **`true`** — it resolves a pull request itself, so this run **publishes before each review** |
| Severity     | **none.** A level with an acceptable band is resolved by grading — see below                 |
| Status       | `unverified`                                                                                 |

## Flags

| Flag               | Default        | Effect                                                               |
| ------------------ | -------------- | -------------------------------------------------------------------- |
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

**`--rigor minimal` and `--rigor standard` start a grader here.** This card once
shipped a four-rung ladder read out of an agent the command dispatches, and five measured rounds
disproved it: what the runs actually emitted were the command's own confidence words as headings, with
inline confidence percentages and no severity tag anywhere. **Ordering observed is not ordering
asserted**, so the definition declares no ladder rather than promoting section titles to rungs.

The rungs therefore come from a **separate subprocess on the resolved `--model`**, specified in
`procedures/severity-grading.md`, at one permission prompt per round on top of the review.

**The default level starts one.** `standard` has an acceptable band and this reviewer has no rungs,
so the grader is part of the ordinary run rather than of a flag; `--rigor thorough` removes it and
the floor together. `procedures/rigor-levels.md` states the four levels and what else each one moves.

## What differs for this reviewer

- **`requiresPr` is `true`, so the branch is pushed and a pull request opened _before_ each review**,
  because the reviewer resolves one itself and would otherwise read a stale diff. That also makes
  `unconfirmed-empty-review` reachable under `--no-publish`: with no pull request to read and a clean
  diff, this reviewer returns the same nothing either way, and zero findings must not be read as clean.
- **It needs a permission block installed to reach `gh`.** A checkout with no
  `.claude/settings.local.json` produced a 52-second run that returned prose asking which of two
  options to take — zero findings, no shape the card records — and the procedure correctly aborted on
  the parse rather than reading it as clean. The card records both that run and the working one.
- **It names its target.** Every working round opened by naming the pull request it reviewed, by number
  and title, and the blocked round said instead that it could not confirm one existed. That is the only
  signal outside the subprocess that the reviewer reached its target at all.

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

- You want ECC's multi-agent review against an open pull request, driven to convergence.
- **Not with `--no-publish` unless a pull request already exists** — this reviewer needs one, and step
  1 will ask you to confirm it.
- Not as a first look at a change: it is the slower and more expensive of the two local presets.
