# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English ・ [日本語](README.ja.md)

A Claude Code / Codex plugin that repeats an AI review-and-fix loop until it converges. Its fences
keep a run from spending more rounds — and so more wall clock and more tokens — than the review
needs.

Two commands are available:

- `/revloop:remote-loop` — remote. Summons a reviewer bot on GitHub, and can merge.
- `/revloop:local-loop` — local. Uses a review command that runs on your machine, and opens the pull
  request itself.

**The remote loop assumes a reviewer that already answers.** Whichever reviewer you select — Codex,
Claude, Gemini, or a custom preset — its GitHub integration must already be installed on the
repository and responding to comments.

**The local loop never touches a GitHub comment thread, and never merges.** It pushes the converged
branch and opens a pull request for it (`--no-publish` stops it at the commit). **Its review runs on a
light model by default** (`sonnet`, changed with `--review-model`). See
[`docs/design-notes.md`](docs/design-notes.md).

The basic invocations are:

```console
/revloop:remote-loop
/revloop:remote-loop --reviewer gemini --max-rounds 15
/revloop:remote-loop --merge --auto

/revloop:local-loop
/revloop:local-loop --no-publish
/revloop:local-loop --review-model opus --max-rounds 3
/revloop:local-loop --reviewer ecc-review-pr --accept-at HIGH
```

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
export REVLOOP_PROCEDURE=~/.revloop/commands/remote-loop.md
```

Codex controls permissions with an approval policy and a sandbox instead. The details are in
[`docs/permissions.md`](docs/permissions.md).

## Configure

By default, revloop detects the base branch, the verify commands, the branch prefixes, and the commit
conventions from the repository itself, and builds a configuration table with a `source` column:

```text
key              value                              source
reviewer         codex                              flag
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        10                                 builtin
```

To change any of it, or to add your own reviewer, write `.revloop.json`. The details are in
[`docs/configuration.md`](docs/configuration.md) and
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "reviewers": {
    "acme": {
      "trigger": "@acme review",
      "botLogin": "acme-reviewer[bot]",
      "cleanPatterns": ["^Acme Review: no issues found"]
    }
  }
}
```

## Keeping the loop from running away

**An LLM reviewing code tends to keep producing small findings.** To stop those from stretching a run
out, there is `--accept-at <level>`. It names **the highest severity that may be left unfixed**; once
every finding above that level is resolved, the loop may converge.

```console
/revloop:local-loop --reviewer ecc-review-pr --accept-at high   # only CRITICAL blocks
```

The level you pass is either one of the reviewer's own severities, named in its `severityLevels`, or
one of the severities revloop defines — `critical > high > medium > low`.

The `code-review` preset built into Claude Code emits no `severityLevels`. For a reviewer like that,
`--grade-severity` has a grading model, run as a separate process, estimate the severity instead.

```console
/revloop:local-loop --accept-at high --grade-severity
```

## Built-in reviewers

| Preset          | Kind             | Trigger or command                                      | Status     |
| --------------- | ---------------- | ------------------------------------------------------- | ---------- |
| `codex`         | `github-comment` | `@codex review`                                         | verified   |
| `gemini`        | `github-comment` | `@gemini review` (see the card)                         | verified   |
| `claude`        | `github-comment` | `@claude review`                                        | unverified |
| `code-review`   | `local-command`  | `claude --model {reviewModel} -p "/code-review medium"` | unverified |
| `ecc-review-pr` | `local-command`  | `claude --model {reviewModel} -p "/ecc:review-pr"`      | unverified |

`{reviewModel}` is expanded by the local loop before the command runs — to `--review-model` if you
typed it, otherwise to `sonnet`.

Each [card](reviewers/) records what was measured, when, and where. copilot (which is asked for a
review by reviewer request) is not supported at present.

## Limitations

These are the rough edges that remain.

| Limitation                        | Why                                                                                                                                                                                                 |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Forks are unsupported**         | The pull request lives upstream, so calls would address the wrong repository. Both loops abort in step 1 — the local one only when it is publishing, so `--no-publish` is the way to work in a fork |
| **Same-repo topic branches only** | One open PR per branch. If a loop looks one up and cannot identify it, it aborts                                                                                                                    |
| **Merge commits only**            | Squash and rebase are not available                                                                                                                                                                 |
| **`copilot` unsupported**         | It has no comment trigger, and the reviewer-request path is not implemented                                                                                                                         |
| **The local loop never merges**   | It ends at a pushed branch with an open pull request, or at a commit under `--no-publish`. Merge it separately                                                                                      |

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
