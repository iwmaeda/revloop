# Permissions

The two hosts grant differently. Claude Code matches a command-string prefix against an allowlist, so
the unit of permission is a rule you write down. Codex decides with an approval policy and a sandbox,
so the unit is a mode plus the holes you open in it.

This page is what to grant. Why the rules are shaped this way is in
[`design-notes.md`](design-notes.md#permission-rules-and-fence-bytes).

**Which rules you need depends on which family of command you run, and on how you run it.** The list
is per family rather than per command because the grant is a property of the procedure, and every
command in a family runs the same one — `tests/commands.test.sh` asserts that the four `remote-*`
commands carry a byte-identical `allowed-tools` line, and that the three `local-*` ones do.

The `remote-*` commands talk to GitHub and need the whole list below. The `local-*` commands need a
strict subset — including four `gh` rules, since they push and open a pull request by default.

| Run                               | What it needs                                                                                                                             |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Any `local-*`                     | `Bash(git:*)`, plus `Bash(gh pr list:*)`, `Bash(gh pr create:*)`, `Bash(gh repo view:*)`, `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` |
| Any `local-*` with `--no-publish` | `Bash(git:*)`. **No step calls `gh`** — it ends at a commit                                                                               |
| Any `remote-*`                    | The whole list                                                                                                                            |

**A reviewer you point either family at may reach GitHub on its own account**: the shipped
`ecc-review-pr` preset resolves a pull request, and a `skill`-invoked reviewer does that inside this
session under the grants this session already has.

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
      "Bash(gh pr create:*)",
      "Bash(gh pr list:*)",
      "Bash(gh repo view:*)",
      "Bash(git:*)"
    ]
  }
}
```

**`gh pr create` and `gh pr list` are listed separately because the `local-*` commands hold those two
rather than the broad `Bash(gh pr:*)`**, which would pre-approve `gh pr merge` for a command that
never merges.

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
`git remote add`. The procedures forbid force-pushing — a rebase re-anchors every inline comment and
makes the `commit_id` comparison meaningless — but that is a rule the model follows, not one the
permission system enforces. The blast radius is your working tree and the branches your token can
write. Two things bound it: neither procedure ever constructs a `--force` push, and step 1 aborts on
a fork, so the branches are your own.

**The `local-*` commands hold this rule too, and push with it unless `--no-publish`.** The same shape
applies to its four `gh` rules: the grants are present on every run, and it is the procedure rather
than the permission system that keeps them within their purpose. That is why they are the narrow
ones.

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

**It also holds both `allowed-tools` lines, and this list, to the schema's ban list**: a procedure may
pre-approve only a binary that a repository-supplied review command is forbidden to begin with. That
is what keeps the review command and the grader — both of which start with a model CLI — outside
every grant, where the permission system sees them. **The check is one-way**: the schema's `gh` ban is
deliberately wider than the grants that motivate it, so a ban with no grant is the design rather than
a defect.

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

### Nor is the grader's command, and it is procedure-owned rather than repository-supplied

**A graded run starts a grader subprocess per round** — on **the local family's** resolved review
model, and on the builtin `sonnet` in the pull-request family, which has no `--model` to move it. A
run is graded when `--accept-at` was typed and the reviewer's definition declares no `severityLevels`,
which is three of the five shipped reviewers: `claude`, `code-review` and `ecc-review-pr`. The grader
is treated like the review command in every way but one: **its command line comes from the
procedure and never from `.revloop.json`.** A review command is what the operator chose to run and
the step-1 table shows it before it runs; a grader the repository could choose would be a shell
string nobody asked for, started in the one place whose purpose is to let findings go unfixed.
Only the model is interpolated into it, through the same `{reviewModel}` resolution and the same
`^[A-Za-z0-9][A-Za-z0-9._:-]*$` refusal — **in the local loop. The pull-request loop interpolates
nothing**, because its model is the builtin, so that refusal has no input there and cannot fire.

**The findings are the other thing that could reach that command line, and deliberately do not.**
They are written to `.revloop/grading-input.txt` and redirected in, never concatenated into the `-p`
argument. A finding's claim is reviewer output quoting repository content, so it carries whatever
characters the repository carries — building an argv out of it is the same hole `--body-file` closes
on the pull-request body and the pattern above closes on the model name, reached through the one
string this page had not yet accounted for. The instruction stays fixed in the argument, the
untrusted half arrives on standard input, and **the string you are prompted with therefore does not
grow with the findings**, which is what keeps the prompt readable enough to be a real decision.

**It is deliberately not a fence, for the reason the review command is not one**: a fence's "always
allow" holds because its bytes never change, and this string carries a model. So it is absent from
`allowed-tools`, the permission system sees it every round, and step 1 prints it in full and expanded
— beside the review command in the local loop, and on its own in the pull-request loop, which has no
review command to print it beside and where the grader is the only subprocess the run starts at all.
**What that costs differs by family, and the figure belongs to the procedure
rather than to a flag.** A graded local run costs **two** prompts a round where it costs one — the
review command and the grader. A graded pull-request run costs **one** where it costs none from a
process it started, because its reviewer is a GitHub app; grading is the only thing that puts a model
subprocess in that procedure at all. Both are the correct price for the string a graded run is
most about.

**A `subprocess` command may not begin with `git`, with `gh`, or with the `{reviewModel}`
placeholder**, and the schema rejects all three. The local command grants `Bash(git:*)` for its own
probe and four `gh` rules for publishing, and a rule matches a prefix, so such a command would run
with no prompt at all — see
[`../SECURITY.md`](../SECURITY.md#repository-supplied-configuration-is-untrusted).

**That covers a longer name too**, because the rule above is the one being applied: the matcher
compares strings, so `gitlint`, `git-review`, `git.exe`, `ghreview` and `gh.exe` each start with a
granted prefix however different a binary the shell would run. A review command named that way has to
be configured as a `skill`, which no `Bash` rule matches, or renamed.

**The `gh` ban is wider than the four rules that motivate it**, which is deliberate: banning the four
granted spellings instead would be four rules that have to track a grant list every future step can
extend, and a ban that lags its grants by one release is the hole itself.

**The placeholder ban exists because expansion happens after the prefix is checked.** `{reviewModel}`
is substituted before the command runs, so `{reviewModel} push --force` under `--model git`
becomes a string beginning with `git` — the first two bans defeated by a value that arrived after
them. The schema removes the shape, and the procedure re-checks the expanded string before running it.

### The review model is the one interpolated value

`--model <name>` is **expanded into a command line** at the `{reviewModel}` placeholder — the
only value either procedure splices into a shell command. It comes from the flag or from the builtin
`sonnet`, never from `.revloop.json`, and is refused unless it matches
`^[A-Za-z0-9][A-Za-z0-9._:-]*$`.

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

**Count them by string class rather than by loop, because a string class is what the permission
system matches on.** Three exist, and only the first is covered by the rules above:

| String                                             | Prompts                           | Why                                                           |
| -------------------------------------------------- | --------------------------------- | ------------------------------------------------------------- |
| A fence                                            | Once, at the first approval       | It takes no arguments, so its command string never varies     |
| A verify command, or a `subprocess` review command | Every round it runs               | Repository-supplied. Pre-approving it is the hole             |
| The grader, on a graded run                        | Every round, in **both** families | Procedure-owned, but it carries a model, so it is not a fence |

**"Zero prompts per round" was never a property of the pull-request loop; it is a property of the
fences.** A remote round runs the repository's verify commands exactly as a local round does — step
11 returns to step 3 — and those are excluded from `allowed-tools` on purpose. This page used to say
that loop reached zero, two sentences above saying the review command is prompted for "as `verify`
is"; both cannot be true.

**Grading adds one prompt per round to whichever family is running.** On a local run that is a second
prompt beside the review command. On a pull-request run it is the first and only model subprocess that
procedure has ever started, because its reviewer is a GitHub app rather than a process. **It needs no
flag of its own**: `--accept-at` against a reviewer with no ladder is what reaches it, so the prompt
count follows the reviewer as much as the invocation — which is why step 1 prints `severity source`
before the first round rather than at the first prompt. **The string you are prompted with is the
expanded one** — `{reviewModel}` already substituted in the local family, or the builtin `sonnet` in
the pull-request family, which has no `--model` and interpolates nothing — because that is the string
that will run, and being shown a template while a different string executes is the failure the whole
not-pre-approved rule is about.

Editing a fence costs every user one re-approval; the protocol is in
[`../CONTRIBUTING.md`](../CONTRIBUTING.md#editing-a-shell-fence).

**A prompt for a fence is the bug worth reporting** — include the prompt text and the rule you
granted. A prompt for a verify, review, or grader command is not one: those are the three strings
this page keeps out of `allowed-tools` deliberately.

## Related docs

- [Design notes](design-notes.md#permission-rules-and-fence-bytes) — why prefix matching shapes all of
  the above
- [Install](install.md) — getting revloop in place first
- [`../SECURITY.md`](../SECURITY.md) — the threat model these grants sit inside
