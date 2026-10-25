# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English ・ [日本語](README.ja.md)

A Claude Code plugin that repeats an AI review-and-fix loop until the review converges, with guards
against spending more rounds, time and tokens than the review needs.

| Command                       | Reviewer                        | Where it runs                |
| ----------------------------- | ------------------------------- | ---------------------------- |
| `/revloop:remote-codex-loop`  | `@codex review`                 | A bot on your pull request   |
| `/revloop:remote-gemini-loop` | `@gemini review`                | A bot on your pull request   |
| `/revloop:remote-claude-loop` | `@claude review`                | A bot on your pull request   |
| `/revloop:remote-custom-loop` | one you define, with `--config` | A bot on your pull request   |
| `/revloop:local-review-loop`  | Claude Code's `/code-review`    | A subprocess on your machine |
| `/revloop:local-ecc-loop`     | ECC's `/ecc:review-pr`          | A subprocess on your machine |
| `/revloop:local-custom-loop`  | one you define, with `--config` | A subprocess on your machine |

The remote commands need the reviewer's GitHub integration installed on the repository and answering
comments. The local commands post no comments and never merge.

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

| Flag               | Commands        | Default      | What it does                                                        |
| ------------------ | --------------- | ------------ | ------------------------------------------------------------------- |
| `--rigor <level>`  | all             | `standard`   | How strictly the run must finish (see below)                        |
| `--max-rounds <n>` | all             | by `--rigor` | Abort if the loop has not converged by then                         |
| `--auto`           | all             | off          | Run through the stop points, except a local reviewer's confirmation |
| `--merge`          | `remote-*`      | off          | After convergence, wait for green CI and merge                      |
| `--timeout <dur>`  | `remote-*`      | `30m`        | Cap on waiting for one trigger's verdict                            |
| `--model <name>`   | `local-*`       | `sonnet`     | The model a subprocess review with `{reviewModel}` runs on          |
| `--no-publish`     | `local-*`       | off          | End at the commit: no push, no pull request                         |
| `--config <path>`  | `*-custom-loop` | required     | The reviewer definition this run drives                             |

## How it works

A run usually takes tens of minutes, most of it waiting for the reviewer.

### The remote loop

| Phase       | Steps | What happens                                                                 |
| ----------- | ----- | ---------------------------------------------------------------------------- |
| **Resolve** | 1     | Probe the repository and print the resolved configuration                    |
| **Prepare** | 2–6   | Cut a topic branch, run verify, commit (first stop point), push, open the PR |
| **Trigger** | 7     | Post the review request                                                      |
| **Wait**    | 8     | Poll GitHub until the verdict for this trigger arrives                       |
| **Decide**  | 9     | Continue, finish or abort                                                    |
| **Fix**     | 10–11 | Read the findings, fix them, reply under each inline finding                 |
| **Finish**  | 12    | Report. With `--merge`, wait for green CI and then merge (second stop point) |

After a round that fixed a finding, the loop goes back to step 3. At `minimal` and `standard`, which
accept some findings, `--merge --auto` is refused and `--merge` stops once to confirm the accepted
findings; use `--rigor thorough` to merge unattended. To resume an aborted run, for example after a
rate limit, run the same command again.

### The local loop

| Phase       | Steps   | What happens                                                           |
| ----------- | ------- | ---------------------------------------------------------------------- |
| **Resolve** | 1       | Probe and print the resolved configuration, including the review model |
| **Prepare** | 2–4     | Cut a topic branch, run verify, commit (the stop point)                |
| **Publish** | 5 or 10 | Push, and open a pull request if the branch has none                   |
| **Review**  | 6       | Run the review command and read its output                             |
| **Decide**  | 7–8     | Decide what happens next                                               |
| **Fix**     | 9       | Fix the findings; record the ones declined or accepted in the report   |
| **Finish**  | 11      | Report, and write it into the pull-request body unless `--no-publish`  |

A reviewer that needs a pull request is published to before every round (step 5); any other, once
after convergence (step 10).

## Install

Requirements and troubleshooting are in [`docs/install.md`](docs/install.md).

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The commands need an authenticated `gh`, except a local run with `--no-publish`. Add the permissions
the remote commands need to `.claude/settings.local.json`; the local commands need only the subset in
[`docs/permissions.md`](docs/permissions.md).

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

After placing the skill, give the sandbox network access as in
[`docs/permissions.md`](docs/permissions.md#codex-approval-policy-and-sandbox).

#### Linux

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p ~/.agents/skills
cp -r ~/.revloop/.agents/skills/revloop ~/.agents/skills/
```

To use an existing clone, replace the `git clone` line with `ln -s /path/to/clone ~/.revloop`.

#### Windows (PowerShell)

```powershell
git clone https://github.com/iwmaeda/revloop.git "$HOME\.revloop"
New-Item -ItemType Directory -Force "$HOME\.agents\skills"
Copy-Item -Recurse -Force "$HOME\.revloop\.agents\skills\revloop" "$HOME\.agents\skills"
```

To use an existing clone, replace the `git clone` line with
`New-Item -ItemType Junction -Path "$HOME\.revloop" -Target C:\path\to\clone`.

## Configure

revloop detects the base branch, the verify commands, the branch prefixes and the commit conventions
from the repository, and prints each value with its source:

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

To change a value, write `.revloop.json`, or `.revloop/config.json`, which is read in its place when
present. [`docs/configuration.md`](docs/configuration.md) lists the keys, and the flags that have none.

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "defaults": { "maxRounds": 15 }
}
```

## Keeping the loop from running away

`--rigor <level>` sets which findings must be fixed and how many rounds a run may take.

| Level                    | Blocking           | Acceptable       | Round cap (remote / local) |
| ------------------------ | ------------------ | ---------------- | -------------------------- |
| `minimal`                | `critical`         | `high` and below | 3 / 2                      |
| `standard` **(default)** | `critical`, `high` | `medium`, `low`  | 5 / 3                      |
| `thorough`               | every finding      | none             | 10 / 5                     |
| `exhaustive`             | every finding      | none             | 15 / 8                     |

Every reviewer's severity is mapped to `critical > high > medium > low`. For a reviewer that reports
none, a grading model in a separate process estimates it at `minimal` and `standard`. On convergence,
the run records whether the change is sufficiently reviewed for its level.

## Built-in reviewers

| Preset          | Reviewer         | Severity     | Status     |
| --------------- | ---------------- | ------------ | ---------- |
| `codex`         | `@codex review`  | P1 / P2 / P3 | verified   |
| `gemini`        | `@gemini review` | P1 / P2 / P3 | verified   |
| `claude`        | `@claude review` | none         | unverified |
| `code-review`   | `/code-review`   | none         | unverified |
| `ecc-review-pr` | `/ecc:review-pr` | none         | unverified |

`verified` means the maintainers drove the reviewer end to end on real pull requests. To add your
own, see [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

## Limitations

| Limitation                          | Detail                                                           |
| ----------------------------------- | ---------------------------------------------------------------- |
| Forks                               | Not supported, except a local run with `--no-publish`            |
| Branches                            | Same-repository topic branches, one open pull request per branch |
| Merge method                        | Merge commits only                                               |
| Reviewers without a comment trigger | The remote commands cannot drive one, for example GitHub Copilot |
| Codex as a host                     | Preview: one skill, the remote loop only, not run end to end     |

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

## License

MIT
