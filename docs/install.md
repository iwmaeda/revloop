# Install

Put revloop in place on Claude Code or Codex, then confirm a reviewer answers. Permission rules are
not here — they are in [`permissions.md`](permissions.md).

## Quickstart

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The commands are then `/revloop:review-loop` and `/revloop:review-loop-local`. Plugin-provided
commands are always namespaced as `/<plugin>:<command>`, so there is no bare `/revloop`.

**Both are deliberately not model-invocable**, and the plugin manifest ships no `skills` key. One
pushes, comments and can merge; the other commits and runs a command out of your configuration.
Neither should start except because a person asked for it.

### Codex

Codex plugin support is in preview. The reliable path today is to place the skill directly:

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p .agents/skills
cp -r ~/.revloop/.agents/skills/revloop .agents/skills/
export REVLOOP_PROCEDURE=~/.revloop/commands/review-loop.md
```

`.agents/skills/revloop/SKILL.md` is a router, not a copy of the procedure: it resolves
`commands/review-loop.md` and reads it. `REVLOOP_PROCEDURE` is what makes that work once the skill has
been copied away from the repository. **The router covers the remote loop only** — nobody has driven
the local one from Codex, so it is not claimed as supported.

Codex grants shell and network access through an approval policy and a sandbox rather than an
allowlist; see
[Codex: approval policy and sandbox](permissions.md#codex-approval-policy-and-sandbox).
`.codex-plugin/plugin.json` is already in place for when `codex plugin install` ships.

## Prerequisites

**This section is about the remote loop.** The local loop needs a review command installed on your
machine instead — the built-in one, or a plugin's — and nothing on GitHub at all.

The remote loop assumes a reviewer that already answers. It posts a trigger and waits for a verdict
only the reviewer can produce; **it installs nothing**. The trigger goes to the reviewer's own GitHub
App — never to the Codex or Claude Code session you are running, which cannot answer on its behalf —
and installing that App is outside this project's scope.

To confirm it works, comment your reviewer's trigger by hand on any open pull request and check that
the bot replies. The [card](../reviewers/) for that reviewer records how long an answer took.

## Requirements

| Tool  | Floor                | Note                                                                                            |
| ----- | -------------------- | ----------------------------------------------------------------------------------------------- |
| `gh`  | **2.4.0** (verified) | Authenticated. Only stable REST and GraphQL surfaces are used. **Not needed by the local loop** |
| `git` | **2.22** (derived)   | The release that introduced `git branch --show-current`                                         |
| `jq`  | **not required**     | `gh` embeds a jq implementation; the procedure never pipes to `jq`                              |

The two floors are graded differently on purpose. The `gh` floor is a version the procedure was
actually driven on; the `git` floor is derived from the one command every fence depends on, and
labelled as such. **One `gh` subcommand exists at the floor and does not work** — see
[`known-environment-quirks.md`](known-environment-quirks.md), which is also why the procedure prefers
the stable REST surface to a subcommand.

## Verify the install

```console
/revloop:review-loop
/revloop:review-loop-local
```

On a clean tree with no changes either should print its resolved-configuration table and stop. Read
the local one's **review command** row before you run it for real: it is the string that will be
executed, it comes out of `.revloop.json`, and it is deliberately not pre-approved. If the remote
loop prints a permission prompt for every step, work through [`permissions.md`](permissions.md).

## Related docs

- [Permissions](permissions.md) — what to grant once revloop is in place
- [Configuration](configuration.md) — `.revloop.json`, and what is detected without it
- [Known environment quirks](known-environment-quirks.md) — if `jq` or a version manager misbehaves
