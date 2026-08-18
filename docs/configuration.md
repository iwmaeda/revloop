# Configuration

`.revloop.json` at the repository root. Every field is optional. The
[schema](../schema/revloop.schema.json) is machine-readable; the
[examples](../examples/) are a faster start.

## Nothing is required

With no config, revloop detects everything and prints where each value came from:

| Value            | How it is detected when absent                                                                                                                                                                                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `baseBranch`     | `gh repo view --json defaultBranchRef`                                                                                                                                                                                                                                                                  |
| `verify`         | `package.json` scripts (`check:all` → `check` → `lint` + `typecheck` → `test`), `pyproject.toml` → `uv run pytest` / `ruff check`, `Makefile` targets `check`/`test`/`lint`, `Cargo.toml` → `cargo fmt --check && cargo clippy && cargo test`, `go.mod` → `gofmt -l . && go vet ./... && go test ./...` |
| `branchPrefixes` | The prefixes actually used in the repository's commit subjects                                                                                                                                                                                                                                          |
| `commit.*`       | The last 20 commit subjects and bodies: style, language, existing trailers                                                                                                                                                                                                                              |
| `reviewers`      | The four built-in presets                                                                                                                                                                                                                                                                               |

The `source` column of the step-1 table is `flag`, `config`, `detected`, or `builtin`. **Read it.**
It is how you tell a value you chose from a value revloop guessed, without reading any code.

## When config is missing or wrong

| Situation                             | Behaviour                                                         |
| ------------------------------------- | ----------------------------------------------------------------- |
| No `.revloop.json`                    | Detect everything. Normal.                                        |
| Malformed JSON                        | **Abort.** No fallback — see below                                |
| Unknown key                           | Warn, continue                                                    |
| Unknown `version`                     | **Abort**                                                         |
| `--reviewer` names nothing known      | **Abort** and list the available names. Never guess               |
| No verify command found or configured | Ask before continuing; record "no verification ran" in the report |
| ...and `--merge` was passed           | **Abort.** Do not merge code that nothing checked                 |

**Malformed config aborts rather than falling back**, because a silent fallback to the built-in
presets would ignore exactly the custom reviewer a user went to the trouble of configuring, while the
run still looked healthy.

## `project`

| Key              | Meaning                                                                             |
| ---------------- | ----------------------------------------------------------------------------------- |
| `baseBranch`     | PR base. `null` means detect                                                        |
| `verify`         | Commands run before pushing. Run them **exactly as CI runs them**                   |
| `verifyNotes`    | Which CI job the umbrella command does **not** reproduce. See below                 |
| `branchPrefixes` | Allowed topic-branch prefixes                                                       |
| `roundSource`    | `trigger-comments` (count what was fired) or `git-log-grep` (parse commit subjects) |
| `commit.*`       | Style, languages, scopes, trailers, whether a round number goes in the subject      |
| `pr.*`           | Title template and language, body-update method, merge method                       |

### `verifyNotes` is a question every project answers differently

Almost every repository has one umbrella command (`npm run check:all`, `make check`) that does _not_
cover everything CI runs. **The shape of the gap is universal; the answer is per-project**, and it is
sometimes empty:

- one project's umbrella command skipped the **tests**;
- another's skipped **`npm audit`**;
- a third's had no gap at all.

Write yours here so the loop closes it before pushing. A red CI costs a whole review round.

### `roundSource`

`trigger-comments` counts the triggers actually posted on the PR. It is more accurate than parsing
commit subjects — a round that ended with no findings still cost you the wait — and it does not
require you to put round numbers in commit messages. Use `git-log-grep` only if your history already
encodes them.

## `reviewers`

Adds to or overrides the presets. See [adding-a-reviewer.md](adding-a-reviewer.md) for the full field
list and how to fill it in from measurements.

**Every pattern here is used model-side only.** None of it is interpolated into a shell command or
into a jq program, which is what keeps a `.revloop.json` from a repository you just cloned from
becoming a code-execution path. The remaining surface is closed by rule:

1. `verify` entries are shown in the step-1 table and left out of `allowed-tools`, so the permission
   system always sees them.
2. `trigger` is posted verbatim to GitHub: control characters are rejected, length is capped, and a
   value that already contains `revloop:trigger` is rejected.
3. `botLogin` must match `^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$`.
4. Safety rules cannot be disabled from config.
