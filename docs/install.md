# Install

Put revloop in place on Claude Code or Codex, then confirm a reviewer answers. Permission rules are
not here — they are in [`permissions.md`](permissions.md).

## Quickstart

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The commands are then `/revloop:remote-codex-loop`, `/revloop:remote-gemini-loop`,
`/revloop:remote-claude-loop`, `/revloop:remote-custom-loop`, `/revloop:local-review-loop`,
`/revloop:local-ecc-loop` and `/revloop:local-custom-loop`. Plugin-provided commands are
always namespaced as `/<plugin>:<command>`, so there is no bare `/revloop`.

**Both are deliberately not model-invocable**, and the plugin manifest ships no `skills` key. One
pushes, comments and can merge; the other commits, runs a command out of your configuration, and —
unless `--no-publish` — pushes and opens a pull request of its own. **Neither merges but the first.**
Neither should start except because a person asked for it.

### Codex

Codex plugin support is in preview. The reliable path today is to place the skill directly:

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p ~/.agents/skills
cp -r ~/.revloop/.agents/skills/revloop ~/.agents/skills/
```

`.agents/skills/revloop/SKILL.md` is a router, not a copy of the procedure: it resolves
`procedures/remote-loop.md` and reads it. **It looks in `~/.revloop` by default**, so the clone path
above needs no variable. **The router covers the remote loop only** — nobody has driven the local one
from Codex, so it is not claimed as supported.

**Clone somewhere else and link it there**, so the default path still reaches it:

```console
ln -s /path/to/your/clone ~/.revloop
```

**The link is a file the router reads, not something a launcher has to pass on.** Measured: with
`~/.revloop` a symbolic link to a clone elsewhere, `$HOME/.revloop/procedures/remote-loop.md` reads
the clone's procedure. `REVLOOP_PROCEDURE` still overrides every other resolution, but only for a
session whose launcher hands it on — which a shell you configured does and an editor may not — so it
is an override and not the way to install. The router's other two resolutions do not reach
a clone from a copy placed outside it: the relative fallback from `~/.agents/skills/revloop/` points
at `~/procedures/`, from a project's `.agents/skills/` it points at that project's root, and the
upward search starts in the repository you are working in. **The default path is in the router rather
than in a line this page asks you to add to a startup file**, because no one file covers the shells
Codex is started from — bash reads `~/.bashrc` in a terminal and `~/.bash_profile` in a login shell
such as macOS's, zsh reads `~/.zshrc`, fish needs different syntax, and a session started from an
editor may read none of them. A bare `export` was the first form of this and is gone in the next
terminal; a line appended to `~/.bashrc` was the second and zsh never reads it; and the variable
alone, for a clone elsewhere, was the third and fails from any launcher that does not carry it.

**`~/.agents/skills` puts nothing in your repository.** It is the user scope Codex's skill
documentation lists, read in every repository, so the copy is one per machine rather than an
untracked directory in each checkout. The same copy under a project's own `.agents/skills/` works
too, and is the place for a team that commits it. The router resolves the procedure the same way from
either, since neither the variable nor the default path depends on where the copy sits; **nobody has
driven it from the user scope yet**, so that path rests on Codex's documentation rather than on a
run.

Codex grants shell and network access through an approval policy and a sandbox rather than an
allowlist; see
[Codex: approval policy and sandbox](permissions.md#codex-approval-policy-and-sandbox).
`.codex-plugin/plugin.json` is already in place for when `codex plugin install` ships.

## Prerequisites

**This section is about the remote loop.** The local loop needs a review command installed on your
machine — the built-in one, or a plugin's — and an authenticated `gh`, except under `--no-publish`.
What it does **not** need is a reviewer bot: nothing on GitHub has to answer it.

The remote loop assumes a reviewer that already answers. It posts a trigger and waits for a verdict
only the reviewer can produce; **it installs nothing**. The trigger goes to the reviewer's own GitHub
App — never to the Codex or Claude Code session you are running, which cannot answer on its behalf —
and installing that App is outside this project's scope.

To confirm it works, comment your reviewer's trigger by hand on any open pull request and check that
the bot replies. The [card](../reviewers/) for that reviewer records how long an answer took.

## Requirements

| Tool  | Floor                | Note                                                                                                                  |
| ----- | -------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `gh`  | **2.4.0** (verified) | Authenticated. Only stable REST and GraphQL surfaces are used. **The local loop needs it too, unless `--no-publish`** |
| `git` | **2.22** (derived)   | The release that introduced `git branch --show-current`                                                               |
| `jq`  | **not required**     | `gh` embeds a jq implementation; the procedure never pipes to `jq`                                                    |

The two floors are graded differently on purpose. The `gh` floor is a version the procedure was
actually driven on; the `git` floor is derived, and labelled as such — it is the highest release any
fence's commands require, rather than a version anybody ran. **It is not one command that every fence
depends on**, which is what this sentence said until the fourth fence arrived.
`git branch --show-current` is what sets the 2.22 and it appears in three of the four, while
`worktree-teardown` uses none of it. That fence's own highest is `git worktree remove` at **2.17**,
so it does not move the floor — worth stating rather than leaving to be re-derived, because the next
fence added may.
**One `gh` subcommand exists at the floor and does not work** — see
[`known-environment-quirks.md`](known-environment-quirks.md), which is also why the procedure prefers
the stable REST surface to a subcommand.

## Verify the install

```console
/revloop:remote-codex-loop
/revloop:local-review-loop
```

On a clean tree with no changes either should print its resolved-configuration table and stop. Read
the local one's **review command** row before you run it for real: it is the string that will be
executed, it comes out of the reviewer's definition, and it is deliberately not pre-approved. It is printed with
`{reviewModel}` already expanded, and the **review model** row beside it reads `sonnet` unless you
passed `--model`. If the remote
loop prints a permission prompt for every step, work through [`permissions.md`](permissions.md).

## What a run leaves in your repository

A run may create `.revloop/` at the top of your checkout: field notes for you to read later, and the
grader's input. **Nothing needs adding to your `.gitignore`.** The first file written there is
`.revloop/.gitignore`, holding `*`; nothing is written where git tracks anything under `.revloop`, or
where `git check-ignore` says git would show the file — so the directory stays out of `git status`
and `git add` in any repository, including one where revloop is installed only for you, through
`.claude/settings.local.json`. The worktree ledger is under `.git/` and never in the tree at all. The
reasons, and what this does not cover, are in [design notes](design-notes.md#field-notes).

**A configuration only you use goes in the same directory**, as `.revloop/config.json` — read in
place of `.revloop.json` when it exists, and kept out of git by the same ignore file, which a run
writes when it finds the directory without one. See
[Where the file lives](configuration.md#where-the-file-lives).

## Related docs

- [Permissions](permissions.md) — what to grant once revloop is in place
- [Configuration](configuration.md) — `.revloop.json` or `.revloop/config.json`, and what is detected
  without either
- [Known environment quirks](known-environment-quirks.md) — if `jq` or a version manager misbehaves
