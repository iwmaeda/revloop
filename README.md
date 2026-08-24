# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English ・ [日本語](README.ja.md)

A Claude Code / Codex plugin that runs the whole AI review-and-fix loop on a pull request from one
command, repeating it until the review converges.

**revloop assumes a reviewer that already answers.** Whichever reviewer you select — Codex, Claude,
Gemini, or a custom preset — its GitHub integration must already be installed on the repository and
responding to comments.

The commands are:

```console
/revloop:review-loop
/revloop:review-loop --reviewer gemini --max-rounds 15
/revloop:review-loop --merge --auto
```

## How it works

A run usually takes tens of minutes. **Most of that is time spent waiting for the reviewer.**

| Phase       | Steps | What happens                                                                                                                                      | Roughly how long             |
| ----------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| **Resolve** | 1     | Probe the repository and print the resolved-configuration table with its `source` column                                                          | seconds                      |
| **Prepare** | 2–6   | Cut a topic branch, run verify, sweep the diff for what the reviewer would find, propose a commit split (**first stop point**), push, open the PR | as long as your verify takes |
| **Trigger** | 7     | Post the trigger comment, carrying a `revloop:trigger` marker that records the reviewer, the bot, the head sha, and the round                     | seconds                      |
| **Wait**    | 8     | Poll GitHub until the verdict for _this_ trigger appears                                                                                          | **minutes — see below**      |
| **Decide**  | 9     | Classify the verdict as continue / finish / abort                                                                                                 | seconds                      |
| **Fix**     | 10–11 | Read the inline findings, fix them, run the sweeps that match the class, reply to every one                                                       | minutes                      |
| **Finish**  | 12    | Report; with `--merge`, wait for green CI and then merge (**second stop point**)                                                                  | CI-bound                     |

If even one finding was fixed, step 11 goes back to step 3 and the next round begins. `--auto` keeps
the loop running through both stop points instead of halting at them.

**A pull request carrying a large change can sit in the wait for tens of minutes.** codex returns a
verdict in **3–4 minutes** on average ([`reviewers/codex.md`](reviewers/codex.md), 2026-08).

If the review fails because of a rate limit or a similar API restriction, the loop aborts.

## Install

The details are in [`docs/install.md`](docs/install.md).

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

Grant the permissions the work needs at the same time, by adding the following to
`.claude/settings.local.json`. The details are in [`docs/permissions.md`](docs/permissions.md).

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/{owner}/{repo}/:*)",
      "Bash(gh api -X POST repos/{owner}/{repo}/:*)",
      "Bash(gh api -X PUT repos/{owner}/{repo}/:*)",
      "Bash(gh api --paginate repos/{owner}/{repo}/:*)",
      "Bash(gh api graphql:*)",
      "Bash(gh pr:*)",
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
export REVLOOP_PROCEDURE=~/.revloop/commands/review-loop.md
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

## Built-in reviewers

| Preset   | Trigger                         | Status     |
| -------- | ------------------------------- | ---------- |
| `codex`  | `@codex review`                 | verified   |
| `gemini` | `@gemini review` (see the card) | verified   |
| `claude` | `@claude review`                | unverified |

Each [card](reviewers/) records what was measured, when, and where. copilot (which is asked for a
review by reviewer request) is not supported at present.

## Limitations

The loop is not general-purpose, and each of these is a deliberate stop rather than a rough edge:

| Limitation                        | Why                                                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Forks are unsupported**         | `{owner}` resolves to your fork while the PR lives upstream, so every call addresses the wrong repository. Step 1 aborts |
| **Same-repo topic branches only** | One open PR per branch. A detached HEAD aborts rather than guessing which PR you meant                                   |
| **Merge commits only**            | The merge fence takes no arguments so its command string never changes. Squash and rebase are not available              |
| **`copilot` unsupported**         | It has no comment trigger, and the reviewer-request path is not implemented.                                             |

## Documentation

| Guide                                                        | What it covers                                                   |
| ------------------------------------------------------------ | ---------------------------------------------------------------- |
| [Install](docs/install.md)                                   | Prerequisites, Claude Code, Codex, requirements, verifying it    |
| [Permissions](docs/permissions.md)                           | Claude Code's rules to grant, and Codex's approval and sandbox   |
| [Configuration](docs/configuration.md)                       | `.revloop.json` reference and what is detected when it is absent |
| [Adding a reviewer](docs/adding-a-reviewer.md)               | Measuring a new reviewer and writing it up                       |
| [Design notes](docs/design-notes.md)                         | Why the loop is shaped this way                                  |
| [Known environment quirks](docs/known-environment-quirks.md) | Non-normative observations, attributed and dated                 |
| [Contributing](CONTRIBUTING.md)                              | Running the checks, and the protocol for editing a fence         |
| [Code of conduct](CODE_OF_CONDUCT.md)                        | Contributor Covenant 2.1                                         |
| [Security](SECURITY.md)                                      | Threat model: untrusted config, untrusted reviewer output        |
| [日本語版 README](README.ja.md)                              | This README in Japanese                                          |

## License

MIT
