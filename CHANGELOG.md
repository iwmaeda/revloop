# Changelog

All notable changes to this project are documented here.

**Fence changes are called out explicitly.** The shell fences in
[`commands/review-loop.md`](commands/review-loop.md) are matched by permission rules on their exact
text, so editing one costs every user a single re-approval. See
[`docs/permissions.md`](docs/permissions.md).

## [Unreleased]

### Changed

- **Toolchain versions are stated once, in `mise.toml`.** CI installs them with
  `jdx/mise-action`, replacing `actions/setup-node` and the `node-version: 24`
  that was duplicated across both jobs. `jq` and `shellcheck` are now pinned
  there too, at the versions `ubuntu-latest` happened to carry (jq 1.7,
  ShellCheck 0.9.0), so a runner image update can no longer change a lint
  verdict on its own.

  This closes a real gap rather than only removing duplication.
  `tests/lint-shell.sh` and `tests/jq-program.test.sh` skip themselves when
  their binary is absent, so a contributor without `jq` and `shellcheck` saw
  `npm run check:all` pass having run neither — while CI ran both. After
  `mise install` the two agree. No fence bytes changed; no re-approval is owed.

### Fixed

- **wait-verdict fence**: revloop's own trigger comment matched both trigger
  classes at once, so a single comment emitted two `TRIG` rows with identical
  timestamps. `tail -1` then took the compatibility row, discarding the marker —
  and with it the `bot=` filter that excludes other bots and the `head=` value
  the runaway check depends on. The compatibility class now excludes bodies that
  already carry a marker. Found by running the fence's jq program against a raw
  GraphQL payload; the row-level fixtures could not see it, because they were
  written by hand with one row per comment.

  This changes fence bytes. No re-approval is owed to anyone yet — nothing is
  released — but the entry is recorded because that is the rule.

### Added

- Initial extraction of the review loop into a standalone, reviewer-agnostic tool.
- `.revloop.json` configuration with auto-detection for base branch, verify commands, branch
  prefixes, and commit conventions; JSON Schema and four worked examples.
- Reviewer presets for `codex`, `gemini`, `claude`, and `copilot`, each as a dated card recording
  what was measured and where.
- Fence tests that extract the shell fences from the procedure and replay recorded GitHub responses
  through a `gh` stub, plus structural guards and a fence-hash gate.
- Codex router under `.agents/skills/revloop/`, resolving the same procedure file.
