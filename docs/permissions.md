# Permissions

The two hosts grant differently. Claude Code matches a command-string prefix against an allowlist, so
the unit of permission is a rule you write down. Codex decides with an approval policy and a sandbox,
so the unit is a mode plus the holes you open in it.

This page is what to grant. Why the rules are shaped this way is in
[`design-notes.md`](design-notes.md#permission-rules-and-fence-bytes).

**Which rules you need depends on which command you run.** `/revloop:review-loop` talks to GitHub and
needs the whole list below. **No step of `/revloop:review-loop-local` calls `gh`** — it ends at a
commit — and its `allowed-tools` grants `Bash(git:*)` and nothing else, so none of the `gh` rules
below are needed for the procedure itself. **A reviewer you point it at may still reach GitHub**: the
shipped `ecc-review-pr` preset resolves a pull request through `gh`, and a `skill`-invoked reviewer
does that inside this session under the grants this session already has.

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
      "Bash(gh api -X PATCH repos/{owner}/{repo}/:*)",
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
repository you are in. The flag variants are separate rules because a rule matches a prefix and the
flag precedes the path — `-X POST` for the reply, `-X PUT` for the merge, `-X PATCH` for step 6's
body update, and `--paginate` for the two reads. Prefer them over `Bash(gh api *)`, which reaches
**every repository your token can touch**. `tests/permissions.test.sh` holds the list to the
procedure's fenced blocks, so a verb used without a rule fails the suite rather than a user's run.

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
`Bash(git fetch:*)`, `Bash(git switch:*)`, `Bash(git ls-files:*)`, `Bash(git pull:*)` — and accept that the list will need
extending the first time a step reaches for something not on it. Nobody has measured which
repositories need which subset.

**`tests/permissions.test.sh` keeps this list in step with the procedures, in both directions**: every
git subcommand and every `gh api` prefix appearing in a fenced `bash` block must be granted here, and
every rule granted here must be used by one. So a drifted list fails the suite rather than a user's
run — and an unused grant fails too, because it is a permission nobody needs. The `gh api` half
compares the **whole** prefix, scoped path included; matching only the verb would let an off-scope
call reduce to a rule that was never meant to authorize it.

### Verify commands are not pre-approved

`.revloop.json` supplies the verify commands, so they are repository-supplied strings. Listing them in
`allowed-tools` would pre-approve whatever a cloned repository puts there. They are excluded so the
permission system always sees them, and step 1 prints them before anything runs.

### Nor is a local reviewer's command

The same rule for the string a `local-command` reviewer runs: it comes out of `.revloop.json`, it is
absent from the local command's `allowed-tools`, and step 1 prints it before the first round. **It is
deliberately not a fence** — a fence's "always allow" holds because its text never changes, and a
review invocation varies by reviewer and by depth. The cost is a prompt per round, which is the
correct price for the one string a local run is most about.

**With `invoke: "skill"` there is no prompt, because there is no command string to match.** The
`allowed-tools` line grants the `Skill` tool as a whole, and **granting a tool is not granting one
argument to it**. Step 1 therefore stops and shows the resolved command before the first round on that
path, and **`--auto` does not suppress that stop** — a substitute for a permission prompt that a flag
can delete is not a substitute. If you would rather have the prompt, configure the reviewer as a
subprocess.

**A `subprocess` command may not begin with `git`**, and the schema rejects one that does. The local
command grants `Bash(git:*)` for its own probe, and a rule matches a prefix, so such a command would
run with no prompt at all — see [`../SECURITY.md`](../SECURITY.md#repository-supplied-configuration-is-untrusted).

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

The flag names, config keys and accepted values above were read out of an installed Codex build rather
than from vendor documentation. **What nobody has done is drive the loop end to end under this
configuration** — it is the shape of the problem and a starting point, not a recipe. If you drive it
successfully, this section is worth a pull request. `codex --help` outranks this file whenever the two
disagree.

## Counting the prompts

After the first approval the remote loop should reach zero prompts per round, because every fence
takes no arguments and so has a permanently identical command string. **A local run is different by
design**: its review command is prompted for every round, as `verify` is.

Editing a fence costs every user one re-approval; the protocol is in
[`../CONTRIBUTING.md`](../CONTRIBUTING.md#editing-a-shell-fence).

If your install does not reach zero prompts on a remote run, that is a bug worth reporting — include
the prompt text and the rule you granted.

## Related docs

- [Design notes](design-notes.md#permission-rules-and-fence-bytes) — why prefix matching shapes all of
  the above
- [Install](install.md) — getting revloop in place first
- [`../SECURITY.md`](../SECURITY.md) — the threat model these grants sit inside
