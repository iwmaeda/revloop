# Permissions

Claude Code matches each command string against an allowlist of prefixes. Codex uses an approval
policy and a sandbox. Why the rules have this shape is in
[design notes](design-notes.md#permission-rules-and-fence-bytes).

| Run                               | What it needs                                                                                                                        |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Any `remote-*`                    | The whole list below                                                                                                                 |
| Any `local-*`                     | `Bash(git:*)`, `Bash(gh pr list:*)`, `Bash(gh pr create:*)`, `Bash(gh repo view:*)`, `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` |
| Any `local-*` with `--no-publish` | `Bash(git:*)` only                                                                                                                   |

A reviewer you configure may call GitHub itself. The shipped `ecc-review-pr` preset reads a pull
request, and a reviewer invoked as a skill runs inside your session with the session's grants.

## Claude Code: the rules to grant

Put these in `.claude/settings.local.json` (yours, git-ignored) or `.claude/settings.json` (shared).
A plugin cannot grant itself permissions, so this is a copy-and-paste list.

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

- `gh api` expands `{owner}` and `{repo}` from the current remote, so the scoped rules reach only
  the repository you are in. Prefer them to `Bash(gh api *)`, which reaches every repository your
  token can.
- Each flag variant is its own rule, because a rule matches a prefix and the flag comes before the
  path.
- `gh pr create` and `gh pr list` are listed separately because the local commands hold those two
  and leave out `Bash(gh pr:*)`, which would also cover `gh pr merge`.

### What `Bash(git:*)` still allows

`Bash(git:*)` matches every git subcommand, including `git push --force` and `git reset --hard`. The
procedures never force-push and they abort on a fork unless `--no-publish`, but the permission system does not enforce
either.

The one `--force` a procedure runs is `git worktree remove --force`, in the `worktree-teardown`
fence. It removes only worktrees that the run recorded in `revloop/worktrees.txt` under the
checkout's git directory and whose directory name begins with `revloop-wt-`. Any other worktree of
that name is reported as `WORKTREE=other` and left alone.

To grant subcommands individually instead, use `Bash(git status:*)`, `Bash(git diff:*)`,
`Bash(git log:*)`, `Bash(git add:*)`, `Bash(git commit:*)`, `Bash(git checkout:*)`,
`Bash(git branch:*)`, `Bash(git push:*)`, `Bash(git rev-parse:*)`, `Bash(git merge-base:*)`,
`Bash(git fetch:*)`, `Bash(git switch:*)`, `Bash(git ls-files:*)`, `Bash(git pull:*)`,
`Bash(git worktree:*)` and `Bash(git check-ignore:*)`.

## What is not pre-approved

The rules above cover the fences and the procedures' own `git` and `gh` calls. These strings are kept
out of `allowed-tools`, so Claude Code prompts for them unless you have granted the string yourself,
and step 1 prints each one before anything runs.

| String                            | Prompts                              | Comes from                           |
| --------------------------------- | ------------------------------------ | ------------------------------------ |
| A fence                           | Once, at its first approval          | The procedure. Its text never varies |
| A verify command                  | Every round                          | `.revloop.json`                      |
| A subprocess reviewer's `command` | Every round                          | The reviewer definition              |
| The grader, on a graded run       | Every round                          | The procedure. Only the model varies |
| A worktree creation, in step 3    | Every time, including under `--auto` | The procedure. It carries a path     |

- A reviewer with `invoke: "skill"` has no command string to match, so there is no prompt. Step 1
  stops and shows the resolved command instead, and `--auto` does not skip that stop. Configure the
  reviewer as a subprocess if you want the prompt.
- A run is graded when the level is `minimal` or `standard` and the reviewer declares no
  `severityLevels`. Among the built-ins that is `claude`, `code-review` and `ecc-review-pr`.
  `--rigor thorough` avoids the grader.
- Findings reach the grader through `.revloop/grading-input.txt` on standard input, never on its
  command line.
- A subprocess reviewer's `command` may not begin with `git`, `gh` or `{reviewModel}`. The match is on
  the string, so `gitlint` and `gh-review` are refused too: configure such a reviewer as a skill, or
  rename it. A skill's name is not matched against a permission rule and is not restricted this way. See [`SECURITY.md`](../SECURITY.md#repository-supplied-configuration-is-untrusted).
- The value of `--model` is the only value interpolated into a command line. It must match
  `^[A-Za-z0-9][A-Za-z0-9._:-]*$`.

There are four fences: `wait-verdict`, `worktree-teardown`, `wait-ci` and `merge`. Editing one costs
every user a re-approval; the protocol is in
[`CONTRIBUTING.md`](../CONTRIBUTING.md#editing-or-adding-a-shell-fence). A prompt for a fence you
already allowed is a bug: report it with the prompt text and the rule you granted.

## Codex: approval policy and sandbox

Codex has no allowlist. It decides separately when to ask before running a command
(`approval_policy`) and what a command can reach (`sandbox_mode`). Every `gh` call needs the network,
and a `workspace-write` sandbox usually runs without it, so the trigger, the waits, the reply and the
merge all fail until you open it.

Put this in `~/.codex/config.toml`:

```toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

The same values work as flags for a single run:

| Setting                                  | Flag                     | Values                                               |
| ---------------------------------------- | ------------------------ | ---------------------------------------------------- |
| `approval_policy`                        | `-a, --ask-for-approval` | `untrusted`, `on-request`, `never`                   |
| `sandbox_mode`                           | `-s, --sandbox`          | `read-only`, `workspace-write`, `danger-full-access` |
| `sandbox_workspace_write.network_access` | `-c <key>=<value>`       | `true`, `false`                                      |

To be asked once per repository instead of once per command, mark the repository trusted:

```toml
[projects."/absolute/path/to/your/repo"]
trust_level = "trusted"
```

Do not use `--dangerously-bypass-approvals-and-sandbox` or `danger-full-access`: both remove far more
than network access. To widen the writable set, use `--add-dir <DIR>`.

These settings were read from an installed Codex build and have not been used to run the loop end to
end. `codex --help` wins where the two disagree.
