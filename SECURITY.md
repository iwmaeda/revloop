# Security

## Reporting

Open a private security advisory on the repository, or an issue if the problem is not sensitive.

## Threat model

revloop runs shell commands, calls the GitHub API with your token, and can merge a pull request. The
local commands never merge, but they run one more supplied string: the review command.

### Repository-supplied configuration is untrusted

`.revloop.json` and `.revloop/config.json` come from whatever repository you are working in,
including one you just cloned. Both are read under the same rules.

- The procedure is never read from the repository. Each command reads it from
  `${CLAUDE_PLUGIN_ROOT}` and otherwise aborts with `reason=procedure-unresolved`. The Codex router
  reads `$REVLOOP_PROCEDURE`, its own relative path, or `~/.revloop`. Neither searches the working
  tree.
- No configuration value reaches a shell fence or a jq program.
- `--merge`, `--auto`, `--rigor` and `--config` are flags only. A repository cannot turn on merging,
  remove a confirmation, lower the review bar, or choose the reviewer. `--model` is a flag only
  because a model name from a repository file would be interpolated into a command line, and
  `--no-publish` because nobody has asked for a key.
- Verify commands and a subprocess reviewer's `command` are never pre-approved. Step 1 prints them
  before anything runs, and they are kept out of `allowed-tools`, so your permission system prompts
  for each unless you have granted that string yourself. A skill reviewer has no command string to
  match, so step 1 stops and shows it instead, and `--auto` does not skip that stop.
- A subprocess reviewer's `command` may not begin with `git`, `gh` or the `{reviewModel}` placeholder.
  Permission rules match a string prefix, and the local commands grant `Bash(git:*)` and four `gh`
  rules, so such a command would run without a prompt. The schema rejects it, and the procedure
  checks the expanded string again before running it.
- `{reviewModel}` is the only value interpolated into a command line. It comes from `--model` or the
  built-in `sonnet`, and must match `^[A-Za-z0-9][A-Za-z0-9._:-]*$`.
- A reviewer invoked as a skill has no command string for a permission rule to match. Step 1 shows
  the resolved command and asks for confirmation instead, and `--auto` does not skip that.
- At `minimal` and `standard`, a reviewer definition's `severityMap` decides which findings block; at
  `thorough` and `exhaustive` every finding does. Step 1 prints the rungs that block and the rungs
  that are acceptable before the first round.
- The schema constrains the remaining fields: `botLogin` by pattern, `trigger` by length and
  character set.

### Reviewer output is untrusted

A finding is text from an external system. The procedure reads it, classifies it and acts on its own
judgement; it does not follow instructions embedded in it. Bot bodies have `=` rewritten before they
are placed on an output line, so a body cannot forge a machine-readable key. A local reviewer's
output is treated the same way.

### Permissions

- The remote commands' `gh api repos/{owner}/{repo}/` rules cannot address another repository;
  `gh api graphql`, `gh pr` and `gh repo view` are not scoped to one.
- The local commands grant `Bash(git:*)` and four `gh` rules: `gh pr create`, `gh pr list`,
  `gh repo view` and `gh api -X PATCH repos/{owner}/{repo}/`. They do not grant `Bash(gh pr:*)`,
  which would cover `gh pr merge`. With `--no-publish` no `gh` call is made.
- `Bash(git:*)` is broad. [`docs/permissions.md`](docs/permissions.md) says what it allows.
- A reviewer you configure may reach GitHub on its own, and one invoked as a skill runs inside your
  session with the session's grants.
- The fences are inline in the procedure, so changing one requires every user to approve it again.

### Merging

`--merge` merges only when a CI check run inside the merge step reports every check `COMPLETED` and
`SUCCESS`. The merge pins the sha it checked, so a race returns 409, and the result is read back
before it is reported. `--merge` refuses to run when no verify command is configured or detected.
