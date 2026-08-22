# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Carry a finished change to a pull request and back: **branch → verify → split commits → push → open a
PR → trigger an AI reviewer → classify and fix its findings → repeat until it converges → merge**.

revloop does not write your change. It is the layer that puts a finished change in front of a
reviewer and drives the resulting conversation to a conclusion, without you babysitting it.

Works with **Claude Code** and **Codex**, against any GitHub repository you can push a branch to, with
any reviewer bot that answers a comment. The [limitations](#limitations) are listed rather than
discovered.

```console
/revloop:review-loop
/revloop:review-loop --reviewer gemini --max-rounds 15
/revloop:review-loop --merge --auto
```

## Install

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

Codex, and the manual layout, are covered in [`docs/install.md`](docs/install.md).

Then grant the permissions in [`docs/permissions.md`](docs/permissions.md). revloop asks for a
**narrower** rule than a hand-written version of this workflow needs, because every API call uses
`gh`'s `{owner}`/`{repo}` placeholders:

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/{owner}/{repo}/:*)",
      "Bash(gh api graphql:*)",
      "Bash(gh pr:*)",
      "Bash(gh repo view:*)",
      "Bash(git:*)"
    ]
  }
}
```

`Bash(gh api repos/{owner}/{repo}/:*)` **cannot address a repository other than the one you are in**.

## Configure

Nothing is required. With no config, revloop detects the base branch, the verify commands, the branch
prefixes, and the commit conventions from the repository itself, and prints a resolved-configuration
table with a `source` column before it does anything:

```text
key              value                              source
reviewer         codex                              flag
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        10                                 builtin
```

To pin any of it, or to add your own reviewer, write `.revloop.json`
([reference](docs/configuration.md), [examples](examples/)):

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

A reviewer that answers a comment and posts its verdict as its first reply needs **no change to the
procedure and no change to its fences**. One that posts a preamble before the real review is the
exception — see [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

## Built-in reviewers

| Preset    | Trigger                         | Status                      |
| --------- | ------------------------------- | --------------------------- |
| `codex`   | `@codex review`                 | verified                    |
| `gemini`  | `@gemini review` (see the card) | verified                    |
| `claude`  | `@claude review`                | unverified                  |
| `copilot` | reviewer request, not a comment | **unsupported** (see below) |

Each [card](reviewers/) records what was measured, when, and where — latency, findings per round,
which endpoint the verdict arrives on, and the exact terminal phrases. Reviewer products change, so a
dated card is the difference between a stale claim and a silently false one.

## Limitations

The loop is not general-purpose, and each of these is a deliberate stop rather than a rough edge:

| Limitation                                        | Why                                                                                                                                                                 |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Forks are unsupported**                         | `{owner}` resolves to your fork while the PR lives upstream, so every call would address the wrong repository. Step 1 aborts                                        |
| **Same-repo topic branches only**                 | One open PR per branch; a detached HEAD aborts rather than guessing which PR you meant                                                                              |
| **Merge commits only**                            | The merge fence takes no arguments so its command string never changes. Squash and rebase are not available                                                         |
| **`copilot` cannot be driven**                    | It has no comment trigger, and the reviewer-request path is not implemented. The card is kept for what it measured                                                  |
| **A reviewer with a preamble needs a fence edit** | The list of non-terminal bot comments to drop lives inside the wait fence, because config never reaches a fence — and a fence edit costs every user one re-approval |

Nothing here fails open. Each one stops the loop and says which one it was.

## Why it is built the way it is

The interesting problems here are not "call the GitHub API". They are:

- **A wait loop that cannot lie.** A failed fetch produces empty output, and empty output contains
  neither "pending" nor "fail" — so every naive negative check turns a failure into a pass. Green is
  asserted only from the positive shape of the data.
- **A merge gate that cannot be bypassed by forgetting.** Shell state does not survive between tool
  calls, so the merge step re-runs its own CI check rather than trusting an earlier result, and pins
  the sha it checked. A 409 is read back and reported as a failure, never as a merge.
- **A trigger that is reviewer-agnostic without being permissive.** revloop marks its own triggers,
  so the wait loop matches a string it wrote rather than a reviewer's name. A stray
  `@someone review this before merging` cannot become the baseline, and a reviewer you invented gets
  the same exactness the built-in presets get.
- **A permission surface that stays constant.** The wait scripts take no arguments and resolve the
  repository and PR themselves, so the command string never changes and "always allow" sticks once.

The reasoning is written down in [`docs/design-notes.md`](docs/design-notes.md), and the procedure's
own `## Notes` section states each invariant next to the failure that motivated it.

## Tests

The classification logic is pinned by tests that **extract the shell fences out of the procedure**
rather than restating them, and replay recorded GitHub responses through a `gh` stub:

```console
mise install      # node, jq, shellcheck — pinned in mise.toml, same versions CI uses
npm ci
npm test          # fence + schema tests
npm run check:all # docs + shellcheck + tests
```

Skip `mise install` and the suite still passes, quietly weaker: the shellcheck and jq tests announce a
skip and exit zero when their binary is absent.

The procedure is also explicit about what has **not** been exercised against live data — see its
`## Unexercised paths` section. That list is meant to shrink, and PRs that shrink it are welcome.

## Documentation

| Guide                                                        | What it covers                                                   |
| ------------------------------------------------------------ | ---------------------------------------------------------------- |
| [Install](docs/install.md)                                   | Claude Code, Codex, requirements, verifying the install          |
| [Permissions](docs/permissions.md)                           | The rules to grant, and why they are narrower than usual         |
| [Configuration](docs/configuration.md)                       | `.revloop.json` reference and what is detected when it is absent |
| [Adding a reviewer](docs/adding-a-reviewer.md)               | Measuring a new reviewer and writing it up                       |
| [Design notes](docs/design-notes.md)                         | Why the loop is shaped this way                                  |
| [Known environment quirks](docs/known-environment-quirks.md) | Non-normative observations, attributed and dated                 |
| [Contributing](CONTRIBUTING.md)                              | Running the checks, and the protocol for editing a fence         |
| [Code of conduct](CODE_OF_CONDUCT.md)                        | Contributor Covenant 2.1                                         |
| [Security](SECURITY.md)                                      | Threat model: untrusted config, untrusted reviewer output        |
| [日本語の概要](docs/ja/README.ja.md)                         | Japanese overview (non-canonical)                                |

## License

MIT
