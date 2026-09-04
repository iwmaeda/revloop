# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English ・ [日本語](README.ja.md)

A Claude Code / Codex plugin that repeats an AI review-and-fix loop until it converges. Its fences
keep a run from spending more rounds — and so more wall clock and more tokens — than the review
needs.

**There is a command of its own for each reviewer, and for where it runs — remotely or on your
machine.** These are the commands available today:

| Command                       | Reviewer                        | Where it runs                |
| ----------------------------- | ------------------------------- | ---------------------------- |
| `/revloop:remote-codex-loop`  | `@codex review`                 | A bot on your pull request   |
| `/revloop:remote-gemini-loop` | `@gemini review`                | A bot on your pull request   |
| `/revloop:remote-claude-loop` | `@claude review`                | A bot on your pull request   |
| `/revloop:remote-custom-loop` | one you define, with `--config` | A bot on your pull request   |
| `/revloop:local-review-loop`  | Claude Code's `/code-review`    | A subprocess on your machine |
| `/revloop:local-ecc-loop`     | ECC's `/ecc:review-pr`          | A subprocess on your machine |
| `/revloop:local-custom-loop`  | one you define, with `--config` | A subprocess on your machine |

Seven commands, but **two procedures**: every `remote-*` command runs
[`procedures/remote-loop.md`](procedures/remote-loop.md) and every `local-*` command runs
[`procedures/local-loop.md`](procedures/local-loop.md). The commands differ only in which reviewer
they name and which flags they offer, so there are seven front doors and not seven code paths.

**The remote commands assume a reviewer that already answers.** Its GitHub integration must already be
installed on the repository and responding to comments.

**The local commands never touch a GitHub comment thread, and never merge.** It pushes the converged
branch and opens a pull request for it (`--no-publish` stops it at the commit). **Its review runs on a
light model by default** (`sonnet`, changed with `--model`). See
[`docs/design-notes.md`](docs/design-notes.md).

The basic invocations are below. Which flags are available differs from command to command.

```console
/revloop:remote-codex-loop
/revloop:remote-gemini-loop --max-rounds 15
/revloop:remote-codex-loop --rigor thorough --merge --auto

/revloop:local-review-loop
/revloop:local-review-loop --no-publish
/revloop:local-review-loop --model opus --max-rounds 3
/revloop:local-ecc-loop --rigor minimal

/revloop:local-custom-loop --config ./my-reviewer.json
```

| Flag               | Commands        | Default    | What it does                                   |
| ------------------ | --------------- | ---------- | ---------------------------------------------- |
| `--rigor <level>`  | all             | `standard` | How strictly the run must finish (see below)   |
| `--max-rounds <n>` | all             | 5 / 3      | Abort if the loop has not converged by then    |
| `--auto`           | all             | off        | Run through the stop points without halting    |
| `--merge`          | `remote-*`      | off        | After convergence, wait for green CI and merge |
| `--timeout <dur>`  | `remote-*`      | `30m`      | Cap on waiting for one trigger's verdict       |
| `--model <name>`   | `local-*`       | `sonnet`   | The model the review runs on                   |
| `--no-publish`     | `local-*`       | off        | End at the commit — no push, no pull request   |
| `--config <path>`  | `*-custom-loop` | required   | The reviewer definition this run drives        |

A default written as two numbers is remote / local. `--max-rounds` takes its default from `--rigor`,
so changing the level moves it too.

## How it works

A run usually takes tens of minutes. **Most of that is time spent waiting for the reviewer.**

| Phase       | Steps | What happens                                                                                                                  | Roughly how long        |
| ----------- | ----- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| **Resolve** | 1     | Probe the repository and build the resolved-configuration table with its `source` column                                      | seconds                 |
| **Prepare** | 2–6   | Cut a topic branch, run verify, commit (**first stop point**), push, open the PR                                              | about 3 minutes         |
| **Trigger** | 7     | Post the trigger comment, carrying a `revloop:trigger` marker that records the reviewer, the bot, the head sha, and the round | seconds                 |
| **Wait**    | 8     | Poll GitHub until the verdict for _this_ trigger appears                                                                      | **minutes — see below** |
| **Decide**  | 9     | Classify the verdict as continue / finish / abort                                                                             | seconds                 |
| **Fix**     | 10–11 | Read the inline findings, fix them, reply to every one                                                                        | minutes                 |
| **Finish**  | 12    | Report the outcome; with `--merge`, wait for green CI and then merge (**second stop point**)                                  | CI-bound                |

If even one finding was fixed, step 11 goes back to step 3 and the next round begins. `--auto` keeps
the loop running through both stop points instead of halting at them.

How long a wait runs is recorded, as a measurement, on the [card](reviewers/) of the reviewer you
chose. If the review fails because of a rate limit or a similar API restriction, the loop aborts.

If the wait reaches its budget with no verdict the loop can classify, it posts the trigger once more
before giving up — so a pull request can legitimately carry two review-request comments for one
round. The conditions, and why re-posting is safe, are in
[`docs/design-notes.md`](docs/design-notes.md).

### The local loop

The spine is the remote loop's. With no waiting phase, it finishes in eleven steps.

| Phase       | Steps   | What happens                                                               |
| ----------- | ------- | -------------------------------------------------------------------------- |
| **Resolve** | 1       | Probe and print the resolved table, including which model will review      |
| **Prepare** | 2–4     | Cut a topic branch, run verify, commit (**the stop point**)                |
| **Publish** | 5 or 10 | Push, and open a pull request if the branch has none                       |
| **Review**  | 6       | Run the review command on the light model, and read its output             |
| **Decide**  | 7–8     | Fingerprint the findings and decide what happens next                      |
| **Fix**     | 9       | Fix, and answer the findings that are wrong                                |
| **Finish**  | 11      | Report — and write that report into the pull-request body, if it published |

**Which of the two publish steps runs is read off the reviewer, not off a flag.** A reviewer that
resolves its own pull request is published to at 5, before every round; every other reviewer once at
10, after the loop converges — because a push would otherwise empty the range the shipped default
reviewer diffs. `--no-publish` skips both.

## Install

The details are in [`docs/install.md`](docs/install.md).

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

**Both commands need an authenticated `gh`** (except a local run with `--no-publish`).

Grant the permissions the work needs at the same time, by adding the following to
`.claude/settings.local.json`. The details are in [`docs/permissions.md`](docs/permissions.md).

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/{owner}/{repo}/:*)",
      "Bash(gh api -X POST repos/{owner}/{repo}/:*)",
      "Bash(gh api -X PUT repos/{owner}/{repo}/:*)",
      "Bash(gh api -X PATCH repos/{owner}/{repo}/:*)",
      "Bash(gh api --paginate repos/{owner}/{repo}/:*)",
      "Bash(gh api graphql:*)",
      "Bash(gh pr:*)",
      "Bash(gh pr create:*)",
      "Bash(gh pr list:*)",
      "Bash(gh repo view:*)",
      "Bash(git:*)"
    ]
  }
}
```

### Codex

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p .agents/skills
cp -r ~/.revloop/.agents/skills/revloop .agents/skills/
export REVLOOP_PROCEDURE=~/.revloop/procedures/remote-loop.md
```

Codex controls permissions with an approval policy and a sandbox instead. The details are in
[`docs/permissions.md`](docs/permissions.md).

## Configure

By default, revloop detects the base branch, the verify commands, the branch prefixes, and the commit
conventions from the repository itself, and builds a configuration table with a `source` column:

```text
key              value                              source
reviewer         codex                              flag
rigor            standard                           builtin
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        5                                  rigor
```

To change any of it, or to add your own reviewer, write `.revloop.json`. The details are in
[`docs/configuration.md`](docs/configuration.md) and
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "defaults": { "maxRounds": 15 }
}
```

## Keeping the loop from running away

**An AI reviewing code tends to keep producing small findings.** To stop those from stretching a run
out, `--rigor <level>` says **how strictly the run must finish**. It is the argument that decides when
the loop may stop.

| Level                    | Blocking           | Acceptable       | Round cap (remote / local) | Sweeps                              |
| ------------------------ | ------------------ | ---------------- | -------------------------- | ----------------------------------- |
| `minimal`                | `critical`         | `high` and below | 3 / 2                      | Name the class, check already-fixed |
| `standard` **(default)** | `critical`, `high` | `medium`, `low`  | 5 / 3                      | + corpus                            |
| `thorough`               | every finding      | none             | 10 / 5                     | Every sweep that applies            |
| `exhaustive`             | every finding      | none             | 15 / 8                     | + input-space closed as a set       |

```console
/revloop:remote-codex-loop --rigor minimal
/revloop:local-ecc-loop --rigor thorough
```

Severity is managed through `severityMap` as the same four rungs for every reviewer —
`critical > high > medium > low`. Against a reviewer that reports no severity, **a grading model in a
separate process** estimates it.

**On convergence, the run judges whether the change is sufficiently reviewed for its level.**

## Built-in reviewers

Each preset is made of a **definition** (`reviewers/<name>.json`) and a **card**
(`reviewers/<name>.md`).

| Preset          | Driven by                     | Trigger or command                                      | Severity | Status     |
| --------------- | ----------------------------- | ------------------------------------------------------- | -------- | ---------- |
| `codex`         | `/revloop:remote-codex-loop`  | `@codex review`                                         | P1/P2/P3 | verified   |
| `gemini`        | `/revloop:remote-gemini-loop` | `@gemini review` (see the card)                         | P1/P2/P3 | verified   |
| `claude`        | `/revloop:remote-claude-loop` | `@claude review`                                        | none     | unverified |
| `code-review`   | `/revloop:local-review-loop`  | `claude --model {reviewModel} -p "/code-review medium"` | none     | unverified |
| `ecc-review-pr` | `/revloop:local-ecc-loop`     | `claude --model {reviewModel} -p "/ecc:review-pr"`      | none     | unverified |

`{reviewModel}` is expanded by the local procedure before the command runs — to `--model` if you typed
it, otherwise to `sonnet`.

**A reviewer of your own is written the same way, as a definition and a card.** The details are in
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

## Limitations

These are the rough edges that remain.

| Limitation                            | Why                                                                                                                                                                      |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Forks are unsupported**             | The pull request lives upstream, so calls would address the wrong repository. Both loops abort in step 1; a local loop can still run in a fork with `--no-publish`       |
| **Same-repo topic branches only**     | One open PR per branch. If a loop looks one up and cannot identify it, it aborts                                                                                         |
| **Merge commits only**                | Squash and rebase are not available                                                                                                                                      |
| **Reviewers with no comment trigger** | One summoned by reviewer request rather than by a comment — GitHub Copilot is the example — posts nothing for the loop to anchor a round's baseline to, so step 1 aborts |
| **The local loop never merges**       | It ends at a pushed branch with an open pull request, or at a commit under `--no-publish`. Merge it separately                                                           |

## Documentation

| Guide                                                        | What it covers                                                              |
| ------------------------------------------------------------ | --------------------------------------------------------------------------- |
| [Install](docs/install.md)                                   | Prerequisites, Claude Code, Codex, the work required, verifying the install |
| [Permissions](docs/permissions.md)                           | Claude Code's permission rules, and Codex's approval settings               |
| [Configuration](docs/configuration.md)                       | `.revloop.json` reference                                                   |
| [Adding a reviewer](docs/adding-a-reviewer.md)               | How to configure a custom reviewer                                          |
| [Design notes](docs/design-notes.md)                         | How the review loops are designed                                           |
| [Known environment quirks](docs/known-environment-quirks.md) | Known limitations, bugs, and similar notes                                  |
| [Contributing](CONTRIBUTING.md)                              | Running the checks, and the protocol for editing a fence                    |
| [Code of conduct](CODE_OF_CONDUCT.md)                        | Development guidelines                                                      |
| [Security](SECURITY.md)                                      | Security considerations                                                     |
| [日本語版 README](README.ja.md)                              | This README in Japanese                                                     |

## License

MIT
