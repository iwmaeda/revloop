# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English ・ [日本語](README.ja.md)

A Claude Code plugin that repeats an AI review-and-fix loop until the review converges. Its guards
keep a run from spending more rounds, time and tokens than the review needs.

There is one command per reviewer:

| Command                       | Reviewer                        | Where it runs                |
| ----------------------------- | ------------------------------- | ---------------------------- |
| `/revloop:remote-codex-loop`  | `@codex review`                 | A bot on your pull request   |
| `/revloop:remote-gemini-loop` | `@gemini review`                | A bot on your pull request   |
| `/revloop:remote-claude-loop` | `@claude review`                | A bot on your pull request   |
| `/revloop:remote-custom-loop` | one you define, with `--config` | A bot on your pull request   |
| `/revloop:local-review-loop`  | Claude Code's `/code-review`    | A subprocess on your machine |
| `/revloop:local-ecc-loop`     | ECC's `/ecc:review-pr`          | A subprocess on your machine |
| `/revloop:local-custom-loop`  | one you define, with `--config` | A subprocess on your machine |

The remote commands need a reviewer whose GitHub integration is already installed on the repository
and answers comments.

The local commands post no comments and never merge. They push the branch and open a pull request
for it, before each round for a reviewer that cannot run without a pull request and after convergence for the
rest; `--no-publish` stops at the commit. A subprocess reviewer whose `command` carries `{reviewModel}`
reviews on `sonnet` by default, and `--model` changes that; a skill reviewer runs on the session's
model.

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

| Flag               | Commands        | Default    | What it does                                                        |
| ------------------ | --------------- | ---------- | ------------------------------------------------------------------- |
| `--rigor <level>`  | all             | `standard` | How strictly the run must finish (see below)                        |
| `--max-rounds <n>` | all             | 5 / 3      | Abort if the loop has not converged by then                         |
| `--auto`           | all             | off        | Run through the stop points, except a local reviewer's confirmation |
| `--merge`          | `remote-*`      | off        | After convergence, wait for green CI and merge                      |
| `--timeout <dur>`  | `remote-*`      | `30m`      | Cap on waiting for one trigger's verdict                            |
| `--model <name>`   | `local-*`       | `sonnet`   | The model a subprocess review with `{reviewModel}` runs on          |
| `--no-publish`     | `local-*`       | off        | End at the commit: no push, no pull request                         |
| `--config <path>`  | `*-custom-loop` | required   | The reviewer definition this run drives                             |

A default written as two numbers is remote / local. The default of `--max-rounds` comes from
`--rigor`.

## How it works

A run usually takes tens of minutes, most of it spent waiting for the reviewer.

| Phase       | Steps | What happens                                                                 |
| ----------- | ----- | ---------------------------------------------------------------------------- |
| **Resolve** | 1     | Probe the repository and print the resolved configuration                    |
| **Prepare** | 2–6   | Cut a topic branch, run verify, commit (first stop point), push, open the PR |
| **Trigger** | 7     | Post the review request                                                      |
| **Wait**    | 8     | Poll GitHub until the verdict for this trigger arrives                       |
| **Decide**  | 9     | Continue, finish or abort                                                    |
| **Fix**     | 10–11 | Read the findings, fix them, reply under each inline finding                 |
| **Finish**  | 12    | Report. With `--merge`, wait for green CI and then merge (second stop point) |

If a finding was fixed, the loop goes back to step 3 for the next round. `--auto` runs through both
stop points. A run that aborts, for example on a rate limit, resumes when you run the same command
again once the cause has cleared.

### The local loop

| Phase       | Steps   | What happens                                                           |
| ----------- | ------- | ---------------------------------------------------------------------- |
| **Resolve** | 1       | Probe and print the resolved configuration, including the review model |
| **Prepare** | 2–4     | Cut a topic branch, run verify, commit (the stop point)                |
| **Publish** | 5 or 10 | Push, and open a pull request if the branch has none                   |
| **Review**  | 6       | Run the review command and read its output                             |
| **Decide**  | 7–8     | Decide what happens next                                               |
| **Fix**     | 9       | Fix the findings, and answer the ones that are wrong                   |
| **Finish**  | 11      | Report, and write it into the pull-request body unless `--no-publish`  |

A reviewer that cannot run without a pull request is published to before every round (step 5). Every other
reviewer is published to once, after the loop converges (step 10). `--no-publish` skips both.

## Install

The details are in [`docs/install.md`](docs/install.md).

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The commands need an authenticated `gh`, except a local run with `--no-publish`.

Grant the permissions the loop needs by adding the following to `.claude/settings.local.json`. The
details are in [`docs/permissions.md`](docs/permissions.md).

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

### Codex (preview)

`codex plugin install` does not exist yet, so place the skill by hand:

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p ~/.agents/skills
cp -r ~/.revloop/.agents/skills/revloop ~/.agents/skills/
```

On Codex you get one skill, and only the pull-request loop. It has not been run end to end there.
The skill reads the procedure from `~/.revloop`; link a clone kept elsewhere with
`ln -s /path/to/your/clone ~/.revloop`. Codex uses a sandbox instead of an allowlist, which
[`docs/permissions.md`](docs/permissions.md) covers.

## Configure

By default revloop detects the base branch, the verify commands, the branch prefixes and the commit
conventions from the repository, and prints them with their source:

```text
key              value                              source
reviewer         codex (verified)                   builtin
rigor            standard                           builtin
severity source  reviewer                           builtin
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        5                                  rigor
```

To change a value that has a key, write `.revloop.json`. The flags that have no key are listed in
[`docs/configuration.md`](docs/configuration.md); see
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) for a reviewer of your own.

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "defaults": { "maxRounds": 15 }
}
```

## Keeping the loop from running away

An AI reviewer tends to keep producing small findings. `--rigor <level>` sets how strictly a run
must finish, and so when the loop may stop.

| Level                    | Blocking           | Acceptable       | Round cap (remote / local) |
| ------------------------ | ------------------ | ---------------- | -------------------------- |
| `minimal`                | `critical`         | `high` and below | 3 / 2                      |
| `standard` **(default)** | `critical`, `high` | `medium`, `low`  | 5 / 3                      |
| `thorough`               | every finding      | none             | 10 / 5                     |
| `exhaustive`             | every finding      | none             | 15 / 8                     |

```console
/revloop:remote-codex-loop --rigor minimal
/revloop:local-ecc-loop --rigor thorough
```

Severity is handled on one ladder for every reviewer, `critical > high > medium > low`. For a
reviewer that reports no severity, at `minimal` and `standard` a grading model in a separate process
estimates it. When the loop
converges, the run records whether the change is sufficiently reviewed for its level.

## Built-in reviewers

Each built-in is a definition (`reviewers/<name>.json`) and a card (`reviewers/<name>.md`).

| Preset          | Reviewer         | Severity     | Status     |
| --------------- | ---------------- | ------------ | ---------- |
| `codex`         | `@codex review`  | P1 / P2 / P3 | verified   |
| `gemini`        | `@gemini review` | P1 / P2 / P3 | verified   |
| `claude`        | `@claude review` | none         | unverified |
| `code-review`   | `/code-review`   | none         | unverified |
| `ecc-review-pr` | `/ecc:review-pr` | none         | unverified |

`verified` means the maintainers drove the reviewer end to end on real pull requests; `reported` means
someone reported it working and it has not been reproduced. To add your own, see
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

## Limitations

| Limitation                          | Detail                                                                                        |
| ----------------------------------- | --------------------------------------------------------------------------------------------- |
| Forks                               | Not supported; both loops abort in step 1. A local run with `--no-publish` works              |
| Branches                            | Same-repository topic branches, with one open pull request per branch                         |
| Merge method                        | Merge commits only. Squash and rebase are not available                                       |
| Reviewers without a comment trigger | Not supported by the pull-request loops, for example GitHub Copilot; local commands need none |
| The local loop                      | Never merges. Merge the pull request separately                                               |
| Codex as a host                     | Preview: one skill, the pull-request loop only, not run end to end                            |

## Documentation

| Guide                                          | What it covers                                                    |
| ---------------------------------------------- | ----------------------------------------------------------------- |
| [Install](docs/install.md)                     | Requirements, Claude Code, Codex (preview), verifying the install |
| [Permissions](docs/permissions.md)             | The rules to grant on Claude Code, and the sandbox on Codex       |
| [Configuration](docs/configuration.md)         | `.revloop.json` reference                                         |
| [Adding a reviewer](docs/adding-a-reviewer.md) | Writing a definition and a card for your own reviewer             |
| [Design notes](docs/design-notes.md)           | Why the loops work the way they do                                |
| [Contributing](CONTRIBUTING.md)                | Running the checks, and how to edit a fence                       |
| [Code of conduct](CODE_OF_CONDUCT.md)          | Contributor Covenant                                              |
| [Security](SECURITY.md)                        | The threat model                                                  |
| [日本語版 README](README.ja.md)                | This README in Japanese                                           |

## License

MIT
