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

| Baseline | Consequence                                                                                                                 | Class        |
| -------- | --------------------------------------------------------------------------------------------------------------------------- | ------------ |
| Too new  | A verdict that already arrived is dropped; the round times out and aborts — or, since the re-post, may finish clean instead | **liveness** |
| Too old  | A **previous** round's "no issues" satisfies the filter → false clean verdict                                               | **safety**   |

Findings arriving as a _review_ are protected by comparing `commit=` against HEAD. Terminal signals
arriving as a comment have no commit binding at all, so the timestamp is the only thing tying them to
this round. "Newest trigger" guarantees never-too-old at the price of being vulnerable to too-new,
which is why the tempting refinement — walk back to an older trigger when no verdict is found — is
rejected. It trades a liveness bug for a safety bug, and with `--auto --merge` a safety bug merges
unreviewed code.

**Posting a second trigger is the mirror of that, and it is allowed.** When a trigger's whole budget
passes with no verdict the run could classify — `--timeout` caps one trigger, not one round — and at least three
8-minute chunks were spent watching it, step 7 may post the trigger once more at the same HEAD. Both
halves are required, so a `--timeout` short enough to end before the floor never re-posts at all. That moves
the baseline **forward**, so it can only reach the too-new row of the table above — never the too-old
one. The direction is the entire argument: the rejected refinement reaches for a verdict that is older
than the baseline, which is how a previous round's "no issues" gets adopted, while a re-post can at
worst drop a signal that landed in the 30-second window between the expiring chunk's last poll and the
new comment. A review survives that window because the reviewer answers the second trigger too and
`commit=` still pins it to HEAD; a comment-only signal can be lost. The behaviour it replaces is an
abort, which loses that signal as well and the round with it — so for a clean verdict and for a rate
limit, both of which repeat themselves, the change spends nothing it was not already spending.
**For the two abort-class signals it is a real widening, and this is the one cost the direction
argument does not cover**: an unrecognized bot body and an `interim-loop` exist to stop the loop and
hand it to a human, losing one used to end in an abort anyway, and now a clean second answer can
finish the round and merge past it. Nothing recovers that, which is why a two-trigger round says in
the report that a signal may have been orphaned. The bound — **one re-post per round** — is stored in
the marker rather than in the session, for the same reason `head=` is.

**"Newest" is a computation, not a row position.** The fence's jq program builds one array from four
generators, and array construction preserves generator order — so every compatibility row is emitted
after every marker row, however much older it is. Taking the last row therefore selected the newest
_hand-typed_ trigger whenever one existed at all, and on a pull request driven by hand before revloop
was adopted those comments are permanent. That is the too-old row of the table above, reached without
anyone choosing it: the previous round's verdict came straight back, on the first poll
(`MIRock-jp/hippoblogs#98`, 2026-08). Trigger rows are now sorted by `createdAt`, and within one
second by `databaseId`, before the newest is taken. What the sort enforces is that **the trigger
posted later wins, whatever class it belongs to** — not that a marker outranks a hand-typed comment.
Only the two selections that merge generators are sorted; the review and comment selections each read
one generator and are already in the API's order.

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
  still anchors a baseline — anchoring is all it does, and only while it is the newest trigger. Such a
  trigger carries no `head=`, so the fence reports `marker_head=none` and step 9 aborts rather than
  adopting the verdict.
- **`bot=` filters every other bot at fetch time.** Deploy-preview, coverage, a second reviewer — all
  discarded before classification. A bot that comments on every push satisfies the wait's exit
  condition immediately, so the wait never waits. That was a real failure, caused by a Cloudflare
  Pages preview bot. The two mechanisms compound in one direction: a compatibility baseline carries no
  `bot=`, and an empty `bot=` disables the filter — so a round that lost its baseline to a hand-typed
  comment also stopped filtering bots, and could read a foreign bot's review as the reviewer's.
- **`head=` makes the runaway invariant checkable from GitHub alone**, with no local state a session
  restart can destroy. It also retired a trap: the earlier derivation used `git log --date=format:`,
  which renames a local wall-clock time to `Z` without converting it, shifting it by the UTC offset —
  always in the direction that permits the re-trigger the invariant exists to prevent.
  `--date=format-local:` converts; `--date=format:` does not.
- **`attempt=` puts the re-post bound in the same place, and cost no fence edit to do it.** The fence
  reads marker keys by name through a `case` with no default branch, so a key it does not know is
  skipped, and the jq program's character filter passes `attempt=2` through untouched. **That is the
  fact the whole design rests on**: a marker key can be added without changing a fence's bytes, so the
  retry rule reaches users without costing any of them a re-approval. The key appears only on a
  re-post — its absence means "first trigger of its round" — which keeps the round count a test on one
  key rather than a comparison against a number, and keeps every ordinary round on the five-key body
  `reviewers/codex.md` measured a reviewer accepting. The test reads the key rather than searching
  the body, because a payload garbled by a focus can carry `attempt=` inside a longer token. A bound
  counted in the session would be a bound a session restart refunds; this is the `head=` argument
  again, applied to how many times a trigger has been sent rather than to which
  commit it named.
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
