# Design notes

Why the loop is shaped the way it is. The procedure's `## Notes` states each invariant next to the
failure that motivated it; this page covers decisions that span the whole design, and holds the
reasoning the task guides link out to.

## Provenance

revloop is the union of three independently hardened copies of the same procedure. None was best on
its own — each had fixed bugs the others still had:

- A reviewer's "no issues" phrase has a varying tail, so matching it for equality aborts clean rounds.
- `line` is null on most inline comments (31 of 33 on one PR) while `original_line` is always present,
  so a `line`-based reader drops nine findings in ten.
- A failure token named `NOT_ALL_PASS` contains `ALL_PASS`, so `grep -q ALL_PASS` is true on failure.
- A terminal exit on a non-terminal signal makes the wait loop exit on its first iteration every time
  it is re-fired — an infinite loop that never sleeps.
- REST returned 404 for many minutes while GraphQL served the same data, so a REST-based wait reported
  a PR with 22 triggers as having none.

The differences that were _not_ bugs became the configuration surface. `.revloop.json`'s field list is
therefore not a guess about what people might want, but the list of what actually differed between
three working installations.

## The baseline timestamp is the whole safety argument

The wait loop takes the newest trigger as its baseline and accepts a verdict arriving after it.
Getting that wrong fails in two directions, and they are not equally bad:

| Baseline | Consequence                                                                   | Class        |
| -------- | ----------------------------------------------------------------------------- | ------------ |
| Too new  | A verdict that already arrived is dropped; the round times out and aborts     | **liveness** |
| Too old  | A **previous** round's "no issues" satisfies the filter → false clean verdict | **safety**   |

Findings arriving as a _review_ are protected by comparing `commit=` against HEAD. Terminal signals
arriving as a comment have no commit binding at all, so the timestamp is the only thing tying them to
this round. "Newest trigger" guarantees never-too-old at the price of being vulnerable to too-new,
which is why the tempting refinement — walk back to an older trigger when no verdict is found — is
rejected. It trades a liveness bug for a safety bug, and with `--auto --merge` a safety bug merges
unreviewed code.

## Why the loop marks its own triggers

A configurable reviewer collides with that baseline: the fence must recognise triggers, and every
name-matching approach widens what it matches. `^[@/][a-z-]+ review` also matches
`@someone review this before merging`, which advances the baseline past a verdict that already
arrived and presents as "the reviewer never responded". So the fence matches a string revloop wrote:

```text
<!-- revloop:trigger v=1 reviewer=codex bot=chatgpt-codex-connector head=1a2b3c4d round=3 -->
```

- **Reviewer-agnostic without widening.** A reviewer you invented gets the same exact matching the
  presets get. A preset alternation survives as a compatibility class so a hand-typed `@codex review`
  still anchors a baseline — anchoring is all it does. Such a trigger carries no `head=`, so the fence
  reports `marker_head=none` and step 9 aborts rather than adopting the verdict.
- **`bot=` filters every other bot at fetch time.** Deploy-preview, coverage, a second reviewer — all
  discarded before classification. A bot that comments on every push satisfies the wait's exit
  condition immediately, so the wait never waits. That was a real failure, caused by a Cloudflare
  Pages preview bot.
- **`head=` makes the runaway invariant checkable from GitHub alone**, with no local state a session
  restart can destroy. It also retired a trap: the earlier derivation used `git log --date=format:`,
  which renames a local wall-clock time to `Z` without converting it, shifting it by the UTC offset —
  always in the direction that permits the re-trigger the invariant exists to prevent.
  `--date=format-local:` converts; `--date=format:` does not.
- **Config never reaches the fence.** Reviewer identity arrives via a comment revloop posted, not a
  file the fence parses, so a hostile `.revloop.json` has no path into a shell command or jq program.

## Permission rules and fence bytes

The reasoning behind [`permissions.md`](permissions.md). **A permission rule matches a command-string
prefix**, and that single fact shapes three decisions:

- **`{owner}/{repo}` instead of a literal slug.** `gh api` expands both from the current remote, so no
  call needs a `$(...)` substitution — which is what makes `Bash(gh api repos/{owner}/{repo}/:*)`
  possible. A blanket `Bash(gh api *)` would reach every repository your token can touch.
- **`-X POST`, `-X PUT`, and `--paginate` need their own rules.** The flag precedes the path, so the
  string starts with `gh api -X POST`, not `gh api repos/`. The procedure replies, merges via `PUT`,
  and pages through findings, so all three are used and each is narrowed the same way.
- **The wait scripts take no arguments.** A fence embedding the PR number, a timestamp, or a reviewer
  name would differ every round, "always allow" would never apply, and you would be prompted every
  round — exactly where `--auto` dies. The fences resolve the repository and PR themselves, so their
  text is permanently identical and one approval holds.

**A fence's bytes are the thing you granted.** Editing one costs every user a re-approval, and that
cost is a feature: the prompt is how a user learns the bytes changed. `tests/fence-hashes.txt` plus a
CI gate makes the edit deliberate rather than accidental.

That is also why the fences are not shipped as scripts and called by path. Behind
`bash "$PLUGIN_ROOT/scripts/wait.sh"` the command string never changes, so a plugin update could ship
arbitrary new content under a grant given once — for a public tool people auto-update from, that
converts a one-time grant into standing permission over future code. Two supporting reasons: the
install path contains the version (`cache/<marketplace>/<plugin>/<version>`), so path constancy would
depend on undocumented matcher behaviour; and Codex's workspace-scoped sandbox may refuse to execute a
script from outside the workspace, forcing a second implementation of the thing the design exists to
keep singular. The same rule is why the wait fence's drop list of non-terminal comments is a literal
alternation in its jq program rather than a config key.

## Field notes

When a round takes an unexercised path, aborts, or sees a latency outside the range on the reviewer's
card, the procedure appends one line to `.revloop/field-notes.md` — date, PR, reviewer, path, outcome.
Three rules make that safe: never read them as input to a classification (they are for humans, and for
upstreaming into `reviewers/*.md`); never stage them (`.revloop/` is git-ignored, and step 4's
explicit-staging rule keeps it out of commits anyway); and cap them at 500 lines, rotated.

A project's `.revloop/` is unrelated to `~/.revloop`, the clone path the Codex install suggests.

## Why there are tests, when the original shipped none

The procedure this grew from shipped no regression tests, reasoning that copying the classification
logic into a suite would duplicate the canonical artifact. That is right for a single-repository file
and wrong for a public tool: a 45-line fence whose output drives a 20-row decision table, used by
strangers, is not defensible without tests.

The duplication objection is answered by construction. `tests/extract-fences.sh` pulls the fences _out_
of the procedure and runs them against recorded API responses through a `gh` stub, so nothing is
restated — what is pinned is the interface the decision table consumes. Three paths the original could
only disclose as unexercised (`reaction`, `CHECKS_FAILED`/`SKIPPED`, legacy `StatusContext`) are now
exercised against recorded data. `## Unexercised paths` survives for what genuinely remains unobserved
against a live reviewer; keeping that list honest is more useful than making it short.

## No feature detection on `gh`

The verified floor is `gh` 2.4.0 (2022-03). At 2.4.0 `gh pr checks` has only `--web`, so CI status
comes from `gh pr view --json statusCheckRollup` and merging goes through REST `PUT` rather than
`gh pr merge`. Newer versions offer `--watch` and `--match-head-commit`; revloop uses neither. Two code
paths would halve the empirical coverage behind every claim — any given machine exercises only one —
and they buy nothing, since `--match-head-commit` is the `sha=` pin already in place and `--watch`
replaces a poll that has to run detached anyway. `gh --version` is printed in the step-1 probe table,
so the version is visible without being branched on.

## Related docs

- [Permissions](permissions.md) — the rules this reasoning produces
- [Configuration](configuration.md#what-is-deliberately-not-configurable) — what is fixed, and why
- [`../commands/review-loop.md`](../commands/review-loop.md) — the procedure, and its per-step `## Notes`
