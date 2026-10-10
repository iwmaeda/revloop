# Install

Permission rules are in [`permissions.md`](permissions.md).

## Requirements

| Tool  | Minimum          | Note                                                          |
| ----- | ---------------- | ------------------------------------------------------------- |
| `gh`  | 2.4.0 (verified) | Authenticated. Not needed for a local run with `--no-publish` |
| `git` | 2.22 (derived)   | The release that added `git branch --show-current`            |
| `jq`  | none             | `gh` embeds its own                                           |

The remote commands need a reviewer that already answers. Its GitHub App must be installed on the
repository and must reply to its trigger comment; revloop installs nothing on GitHub. To check, post
the trigger (for example `@codex review`) by hand on an open pull request and confirm that the bot
replies.

The local commands need their review command on your machine: Claude Code's built-in `/code-review`,
or the plugin that provides the one you use.

## Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The commands are namespaced as `/revloop:<command>`. They run only when you type them; the model
cannot start one.

## Codex (preview)

`codex plugin install` does not exist yet, so place the skill by hand:

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p ~/.agents/skills
cp -r ~/.revloop/.agents/skills/revloop ~/.agents/skills/
```

The skill is a router that reads `procedures/remote-loop.md` from `~/.revloop`. If the clone lives
somewhere else, link it:

```console
ln -s /path/to/your/clone ~/.revloop
```

`REVLOOP_PROCEDURE` overrides that path, but only in a session whose launcher passes the variable on.
A team can commit the same copy under the project's own `.agents/skills/`; each user still needs
`~/.revloop` or `REVLOOP_PROCEDURE`.

Only the pull-request loop is available on Codex, and it has not been run end to end there. Codex has
no allowlist; see [Codex: approval policy and sandbox](permissions.md#codex-approval-policy-and-sandbox).

## Verify the install

```console
/revloop:remote-codex-loop
/revloop:local-review-loop
```

On a clean tree with no changes, each should print its resolved configuration table and stop. In the local table, read the
**review command** row before a real run: that string is what will be executed, and it is never
pre-approved (a skill reviewer stops for confirmation instead). If the remote loop prompts at every step, work through [`permissions.md`](permissions.md).

## What a run leaves in your repository

A run may create `.revloop/` at the top of the checkout, for field notes and the grader's input. It
writes `.revloop/.gitignore` containing `*` first, so nothing there appears in `git status` and you
add nothing to your own `.gitignore`. If git already tracks anything under `.revloop/`, or an
existing `.revloop/.gitignore` does not hide the file, nothing is written there and the run reports
instead.

A configuration only you use goes in the same directory, as `.revloop/config.json`. See
[Where the file lives](configuration.md#where-the-file-lives).

## Troubleshooting

- Verify commands behave differently from CI: write `verify` exactly as CI invokes the commands,
  including any version-manager prefix such as `mise exec --`. revloop runs the strings as written.
- CI is reported as failed after a push: a workflow with `concurrency: cancel-in-progress` cancels
  the run, and revloop reads a cancelled run as a failure. Do not push while a run is waiting on CI.
