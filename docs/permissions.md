# Permissions

The two hosts grant differently. Claude Code matches a command-string prefix against an allowlist, so
the unit of permission is a rule you write down. Codex decides with an approval policy and a sandbox,
so the unit is a mode plus the holes you open in it.

This page is what to grant. Why the rules are shaped this way is in
[`design-notes.md`](design-notes.md#permission-rules-and-fence-bytes).

## Claude Code: the rules to grant

Put these in `.claude/settings.local.json` (per-developer, git-ignored) or `.claude/settings.json`
(shared):

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

A plugin cannot grant itself permissions. No install-time hook merges anything into your settings,
which is why this is a copy-and-paste list.

`gh api` expands `{owner}` and `{repo}` from the current remote, so the scoped rules reach only the
repository you are in. The three flag variants are separate rules because a rule matches a prefix and
the flag precedes the path. Prefer them over `Bash(gh api *)`, which reaches **every repository your
token can touch**.

### What `Bash(git:*)` still allows

The narrowness argument above is about `gh api`; it does not extend to the `git` rule.

`Bash(git:*)` matches every git subcommand, including `git push --force`, `git reset --hard`, and
`git remote add`. The procedure forbids force-pushing — a rebase re-anchors every inline comment and
makes the `commit_id` comparison meaningless — but that is a rule the model follows, not one the
permission system enforces. The blast radius is your working tree and the branches your token can
write. Two things bound it: the procedure never constructs a `--force` push, and step 1 aborts on a
fork, so the branches are your own.

If that is not enough, grant subcommands individually — `Bash(git status:*)`, `Bash(git diff:*)`,
`Bash(git log:*)`, `Bash(git add:*)`, `Bash(git commit:*)`, `Bash(git checkout:*)`,
`Bash(git branch:*)`, `Bash(git push:*)`, `Bash(git rev-parse:*)`, `Bash(git merge-base:*)`,
`Bash(git pull:*)` — and accept that the list will need extending the first time a step reaches for
something not on it. Nobody has measured which repositories need which subset.

### Verify commands are not pre-approved

`.revloop.json` supplies the verify commands, so they are repository-supplied strings. Listing them in
`allowed-tools` would pre-approve whatever a cloned repository puts there. They are excluded so the
permission system always sees them, and step 1 prints them before anything runs.

## Codex: approval policy and sandbox

Codex has no allowlist. It gates two things separately — when it asks before running a command
(`approval_policy`) and what a command can reach once it runs (`sandbox_mode`). The second stops this
loop.

**The load-bearing fact:** every `gh` call needs the network. A `workspace-write` sandbox commonly runs
with `network_access = false`, and under it every step that talks to GitHub fails — trigger, waits,
reply, merge. None of it looks like a permission problem from inside the loop.

Put this in `~/.codex/config.toml`:

```toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

The same values work as flags for a single run, and as `-c` overrides:

| Setting                                  | Flag                     | Values                                               |
| ---------------------------------------- | ------------------------ | ---------------------------------------------------- |
| `approval_policy`                        | `-a, --ask-for-approval` | `untrusted`, `on-request`, `never`                   |
| `sandbox_mode`                           | `-s, --sandbox`          | `read-only`, `workspace-write`, `danger-full-access` |
| `sandbox_workspace_write.network_access` | `-c <key>=<value>`       | `true`, `false`                                      |

`-c` takes a dotted path and parses the value as TOML, so
`-c sandbox_workspace_write.network_access=true` opens the network for one invocation. To be asked
once per repository rather than once per command, mark it trusted:

```toml
[projects."/absolute/path/to/your/repo"]
trust_level = "trusted"
```

**Do not reach for `--dangerously-bypass-approvals-and-sandbox`.** It disables approvals _and_
sandboxing for the whole session, far wider than "let `gh` reach GitHub"; `danger-full-access` is the
same trade in a different shape. To widen the writable set without removing the sandbox, use
`--add-dir <DIR>`.

### What was measured, and what was not

| Claim                                                   | Status                                                         |
| ------------------------------------------------------- | -------------------------------------------------------------- |
| The flag names, config keys, and their accepted values  | **verified** — `codex-cli 0.147.0`, 2026-08                    |
| A `workspace-write` sandbox commonly denies the network | **derived** — the setting exists; the default was not read out |
| This configuration carries the loop start to finish     | **unverified** — never driven against a live pull request      |

Verified means the names and value sets were read out of the installed binary's `--help` and embedded
strings, not from vendor documentation, and each override confirmed accepted. The third row is the one
that matters: this is the shape of the problem and a starting point, not a recipe someone drove end to
end. If you drive it successfully, this section is worth a pull request. `codex --help` outranks this
file whenever the two disagree.

## Counting the prompts

The install should reach zero prompts per round after the first approval, because every fence takes no
arguments and so has a permanently identical command string.

Editing a fence therefore costs every user one re-approval. That is deliberate: the prompt is how you
learn the bytes you granted standing permission to have changed. CI enforces it by comparing each
fence against `tests/fence-hashes.txt`; recording a new hash is a separate, deliberate step documented
in [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

If your install does not reach zero prompts, that is a bug worth reporting — include the prompt text
and the rule you granted.

## Related docs

- [Design notes](design-notes.md#permission-rules-and-fence-bytes) — why prefix matching shapes all of
  the above
- [Install](install.md) — getting revloop in place first
- [`../SECURITY.md`](../SECURITY.md) — the threat model these grants sit inside
