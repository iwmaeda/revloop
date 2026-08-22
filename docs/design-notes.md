# Design notes

Why the loop is shaped the way it is. The procedure's `## Notes` section states each invariant next
to the failure that motivated it; this file covers the decisions that span the whole design.

## Provenance

revloop is the union of three independently hardened copies of the same procedure, developed in three
different repositories. None of the three was best on its own — each had fixed bugs the others still
had:

- One had measured that a reviewer's "no issues" phrase has a **varying tail**, so the other two were
  matching a non-constant string for equality.
- One had measured that `line` is null on most inline comments (31 of 33 on one PR) while
  `original_line` was always present, so the other two were dropping nine findings in ten.
- One had found that a failure token named `NOT_ALL_PASS` **contains `ALL_PASS`**, so `grep -q
ALL_PASS` was true when CI failed.
- One had found that a terminal exit on a _non-terminal_ signal makes the wait loop exit on its first
  iteration every time it is re-fired — an infinite loop that never sleeps.
- One had recorded that REST returned 404 for many minutes while GraphQL served the same data, so a
  REST-based wait reported a PR with 22 triggers as having none.

The differences that were not bugs turned out to be the configuration surface. That is where
`.revloop.json`'s field list comes from: it is not a guess about what people might want to change, it
is the list of things that actually differed between three working installations.

## The baseline timestamp is the whole safety argument

The wait loop takes the newest trigger as its baseline and accepts a verdict that arrives after it.
Getting that baseline wrong fails in two directions, and they are **not** equally bad:

| Baseline | Consequence                                                                   | Class        |
| -------- | ----------------------------------------------------------------------------- | ------------ |
| Too new  | A verdict that already arrived is dropped; the round times out and aborts     | **liveness** |
| Too old  | A **previous** round's "no issues" satisfies the filter → false clean verdict | **safety**   |

Findings arriving as a _review_ are protected by comparing `commit=` against HEAD. **Terminal signals
arriving as a comment have no commit binding at all** — the timestamp is the only thing tying them to
this round. So "newest trigger" is not negotiable: it guarantees never-too-old, at the price of being
vulnerable to too-new.

This is why the tempting refinement — "if no verdict is found, walk back to an older trigger" — is
rejected. It trades a liveness bug for a safety bug, and with `--auto --merge` a safety bug merges
unreviewed code.

## Why the loop marks its own triggers

Making the reviewer configurable collides with that: the fence has to recognise triggers, and the
obvious approaches all widen what it matches. A permissive pattern like `^[@/][a-z-]+ review` matches
`@someone review this before merging` — an ordinary human comment — which advances the baseline past
a verdict that already arrived, and presents as "the reviewer never responded".

So the fence stops matching reviewer names and matches a string revloop wrote:

```text
<!-- revloop:trigger v=1 reviewer=codex bot=chatgpt-codex-connector head=1a2b3c4d round=3 -->
```

Consequences, in rough order of value:

1. **Reviewer-agnostic without widening.** A reviewer you invented gets the same exact matching the
   built-in presets get. A preset alternation is kept as a compatibility class so a hand-typed
   `@codex review` still anchors a baseline. **Anchoring is the whole of what it does.** A
   compatibility trigger carries no `head=`, so the fence reports `marker_head=none` and step 9
   aborts instead of adopting the verdict. That is the correct trade: the baseline is a _safety_
   function — it stops an older round's "no issues" from being read as this round's — while binding a
   verdict to a commit needs the marker, and no amount of pattern-matching on a human's comment can
   supply one.
2. **`bot=` filters every other bot at fetch time.** Deploy-preview bots, coverage bots, a second
   reviewer — all discarded before classification. This matters more than it sounds: a bot that
   comments on every push satisfies the wait's exit condition on its first iteration, so the wait
   never actually waits. That was a real failure, caused by a Cloudflare Pages preview bot.
3. **`head=` makes the runaway invariant checkable from GitHub alone.** "Never re-trigger without new
   commits" no longer needs local state that a session restart destroys. It also **retired a genuine
   trap**: the earlier derivation compared HEAD's commit date against the trigger time using
   `git log --date=format:`, which renames a local wall-clock time to `Z` without converting it —
   shifting it by the UTC offset, and **always in the direction that permits the re-trigger the
   invariant exists to prevent**. `--date=format-local:` converts; `--date=format:` does not. Both the
   derivation and the trap are gone.
4. **Config never reaches the fence.** Reviewer identity arrives via a GitHub comment revloop posted,
   not via a file the fence parses. A hostile `.revloop.json` therefore has no path into a shell
   command or a jq program.

## Why the fences are not shipped as scripts

The obvious cleanup is to move the two long fences into `scripts/` and call them by path, which would
make the command string constant across edits. revloop deliberately does not.

Permission rules match on a command-string prefix, so a fence's bytes _are_ the thing you granted
standing permission to. Editing one costs every user a single re-approval — and **that cost is a
feature**: the prompt is how a user learns the bytes changed. Behind
`bash "$PLUGIN_ROOT/scripts/wait.sh"` the string never changes, so a plugin update can ship arbitrary
new script content under a grant the user gave once. For a personal repository that is a shrug; for a
public one that people auto-update from, it converts a one-time grant into standing permission over
future code.

Two supporting reasons: the plugin install path contains the version
(`cache/<marketplace>/<plugin>/<version>`), so path constancy depends on undocumented matcher
behaviour; and Codex's workspace-scoped sandbox may refuse to execute a script from outside the
workspace at all, which would force a second implementation of the thing the whole design exists to
keep singular.

`tests/fence-hashes.txt` plus a CI gate makes a fence edit a deliberate, recorded act rather than an
accident.

## Why there are tests, when the original shipped none

The procedure this grew from deliberately shipped no regression tests, reasoning that copying the
classification logic into a test suite would duplicate the canonical artifact. That reasoning is
right for a single-repository file and wrong for a public tool: a 45-line fence whose output drives a
20-row decision table, used by strangers, is not defensible without tests.

The duplication objection is answered by construction. `tests/extract-fences.sh` **pulls the fences
out of the procedure** and runs them against recorded API responses through a `gh` stub. Nothing is
restated; what is pinned is the interface the decision table consumes. As a side effect, three paths
that the original could only _disclose_ as unexercised — `reaction`, `CHECKS_FAILED`/`SKIPPED`, and
legacy `StatusContext` — are now exercised against recorded data.

The `## Unexercised paths` section survives for what genuinely remains unobserved against a live
reviewer. Keeping that list honest is more useful than making it short.

## No feature detection on `gh`

The verified floor is `gh` 2.4.0 (2022-03); the commands actually used put the theoretical floor near
2.0. At 2.4.0 `gh pr checks` has only `--web`, so CI status comes from
`gh pr view --json statusCheckRollup` and merging goes through REST `PUT` rather than `gh pr merge`.

Newer `gh` versions offer `--watch` and `--match-head-commit`, and revloop uses neither. Two code
paths would halve the empirical coverage behind every claim in the procedure — any given machine
exercises only one of them — and they buy nothing: `--match-head-commit` is the `sha=` pin already in
place, and `--watch` replaces a poll that has to run detached anyway. `gh --version` is printed in the
step-1 probe table, so the version is visible without being branched on.
