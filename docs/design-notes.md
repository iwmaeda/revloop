# Design notes

Why the loops are shaped the way they are. The procedures' `## Notes` state each invariant next to the
failure that motivated it; this page covers decisions that span the whole design, and holds the
reasoning the task guides link out to.

## Provenance

revloop is the union of three independently hardened copies of the same procedure. None was best on
its own — each had fixed bugs the others still had: a clean phrase matched for equality instead of as
a prefix, a findings reader that trusted a field which is usually null, a failure token containing
the success token as a substring, a wait loop that exited on a non-terminal signal, and a wait built
on an endpoint that returns 404 while another serves the same data. Each of those is now a rule in
[`../commands/review-loop.md`](../commands/review-loop.md)'s `## Notes`, stated with the failure it
answers.

The differences that were _not_ bugs became the configuration surface. `.revloop.json`'s field list is
therefore not a guess about what people might want, but the list of what actually differed between
three working installations.

## The baseline timestamp is the whole safety argument

The wait loop takes the newest trigger as its baseline and accepts a verdict arriving after it.
Getting that wrong fails in two directions, and they are not equally bad:

| Baseline | Consequence                                                                                                                 | Class                                                                |
| -------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Too new  | A verdict that already arrived is dropped; the round times out and aborts — or, since the re-post, may finish clean instead | **liveness**, but **safety** when the dropped signal was abort-class |
| Too old  | A **previous** round's "no issues" satisfies the filter → false clean verdict                                               | **safety**                                                           |

Findings arriving as a _review_ are protected by comparing `commit=` against HEAD. Terminal signals
arriving as a comment have no commit binding at all, so the timestamp is the only thing tying them to
this round. "Newest trigger" guarantees never-too-old at the price of being vulnerable to too-new,
which is why the tempting refinement — walk back to an older trigger when no verdict is found — is
rejected. It trades a liveness bug for a safety bug, and with `--auto --merge` a safety bug merges
unreviewed code.

**Posting a second trigger is the mirror of that, and it is allowed.** A re-post moves the baseline
**forward**, so it can only reach the too-new row above, never the too-old one. **The direction is the
entire argument**: the rejected refinement reaches for a verdict older than the baseline, which is how
a previous round's "no issues" gets adopted.

The cost is bounded but not zero. A review orphaned in the gap is recovered by step 10's two-trigger
sweep; a comment-only signal has no such recovery, and for the two abort-class comments that is a real
widening, which is why a two-trigger round says so in its report. The conditions, the budget, and the
recovery are in the procedure's step 7 and step 10.

**"Newest" is a computation, not a row position.** Trigger rows are sorted before the newest is taken,
because the fence builds its array from several generators and generator order is not time order —
taking the last row selected the newest _hand-typed_ trigger whenever one existed, which is the
too-old row reached without anyone choosing it. What the sort enforces is that **the trigger posted
later wins, whatever class it belongs to**.

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
  condition immediately, so the wait never waits; that was a real failure.
- **`head=` and `attempt=` put the run's bounds on GitHub rather than in the session**, where a
  restart cannot refund them. Adding `attempt=` cost no fence edit, because the fence reads marker
  keys by name and skips one it does not know — **a marker key can be added without changing any
  fence's bytes**, and so without costing any user a re-approval.
- **Config never reaches the fence.** Reviewer identity arrives via a comment revloop posted, not a
  file the fence parses, so a hostile `.revloop.json` has no path into a shell command or jq program.

## Permission rules and fence bytes

The reasoning behind [`permissions.md`](permissions.md). **A permission rule matches a command-string
prefix**, and that single fact shapes three decisions:

- **`{owner}/{repo}` instead of a literal slug.** `gh api` expands both from the current remote, so no
  call needs a `$(...)` substitution — which is what makes `Bash(gh api repos/{owner}/{repo}/:*)`
  possible. A blanket rule over `gh api` would reach every repository your token can touch.
- **`-X POST`, `-X PUT`, and `--paginate` need their own rules.** The flag precedes the path, so the
  string starts with `gh api -X POST`, not `gh api repos/`. All three are used, and each is narrowed
  the same way.
- **The wait scripts take no arguments.** A fence embedding the PR number, a timestamp, or a reviewer
  name would differ every round, "always allow" would never apply, and you would be prompted every
  round — exactly where `--auto` dies. The fences resolve the repository and PR themselves, so their
  text is permanently identical and one approval holds.

**That is also why the fences are inline rather than shipped as scripts and called by path.** Behind a
path the command string never changes while the file behind it does, so a plugin update could ship new
content under a grant given once. Editing a fence therefore costs every user one re-approval, which is
the point rather than the price; [`../CONTRIBUTING.md`](../CONTRIBUTING.md) has the protocol.

The same rule is why the wait fence's list of non-terminal comments to drop lives inside its jq
program rather than in config: config that reached a fence would be config that changed what you
granted.

## The local loop is a second procedure, not a flag

`review-loop-local.md` exists as its own file, and the alternative — a `--local` branch inside
`review-loop.md` — was rejected using the argument that file already makes about `gh` feature
detection: **two code paths halve the empirical coverage behind every claim, because any given run
exercises only one.** That argument was about two ways of reaching the same outcome. Here the two are
not the same outcome at all, which makes the split easier rather than harder to justify:

|                     | Remote                                                                                                 | Local                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| The reviewer        | A GitHub App, in its own context                                                                       | A command on your machine                   |
| The scarce resource | **Wall clock** — a quota and your patience, both visible                                               | **Tokens** — invisible while they are spent |
| The verdict         | Arrives asynchronously; the baseline, the marker and the bot filter all exist to bind it to this round | Arrives as the command's own output         |
| The memory          | The pull request                                                                                       | The commit                                  |
| Permissions         | `gh` and `git`                                                                                         | `git`                                       |

**Roughly half of `review-loop.md` is machinery for a problem the local loop does not have.** The
baseline timestamp, the trigger marker, the re-post budget, the two-trigger sweep, and the whole wait
fence exist because a verdict arrives later, from elsewhere, possibly for someone else's trigger.
Carrying that across would mean every one of those rules had to be re-read as "does this still apply?"
by whoever edits next. What the two **do** share is the prepare phase, which the local procedure cites
by step number rather than restating.

**The invariant that does transfer is the runaway one, and it transfers for a different reason.**
Remotely, re-firing a trigger against an unchanged HEAD spends the reviewer's quota and a visible
stretch of wall clock. Locally it spends tokens, and **nothing about it feels expensive** — which is
precisely why it has to be written down. **It is not that a local round is quick**: measured rounds
land inside the remote reviewer's own measured range ([`../reviewers/code-review.md`](../reviewers/code-review.md),
[`../reviewers/codex.md`](../reviewers/codex.md)). The wall clock is not the difference between the
loops; what a round spends while it passes is, and one of the two is invisible.

## The acceptance floor

`--accept-at` is the first consumer `severityLevels` has ever had. The schema says a key with no
consumer is a promise the procedure does not keep, and this was that key: cards filled the ladder in,
nothing read it, and the one place that reasoned about severity named a rung literally — one
reviewer's vocabulary, hardcoded into a rule meant to apply to all of them. On a ladder that does not
contain that rung, the rule led the report with nothing.

**The floor and "do not triage by the badge" are compatible, and the boundary between them is where
the flag is safe.** [`../reviewers/codex.md`](../reviewers/codex.md) derives that instruction from a
measurement: the severity mix moves per pull request, so the badge cannot tell you what is worth
reading. The floor never decides what to read. Every finding is fetched, classified, replied to, and
listed whatever its rung; the floor decides only **when the loop may stop**. A version that skipped
fetching the accepted rungs would be the thing the card forbids, and it would also be cheaper — which
is why the rule is written down instead of left to judgement.

**The loop never supplies a ladder the reviewer did not.** Asked to accept findings from a reviewer
that emits no severity, it aborts rather than ranking them itself. It is the party obliged to fix
them, so a ladder it authors is a ladder it can author its way out of the work with, and from outside
the run that is indistinguishable from a reviewer that really graded them that way. This is not
hypothetical: one shipped local preset is exactly that reviewer.

Where the flag sits in the configuration surface, and the one combination it refuses, are in
[`configuration.md`](configuration.md#the-acceptance-floor).

## What a local run does not establish

**A local reviewer may be the same model as the thing that wrote the code**, and then it is not an
independent check. It shares the training, the habits and the blind spots of the author, and a
reviewer cannot find a defect it would have written itself. Running it as a subprocess stops it from
reading _this session's_ reasoning, which is a real and separate improvement — a reviewer that has
just watched you justify a decision does not find that decision suspicious — but it does not make the
reviewer a second opinion. **Only a different model does that**, and
[`adding-a-reviewer.md`](adding-a-reviewer.md) records one as a candidate rather than shipping it,
because nobody has driven it here.

**So the local loop is a pre-flight and not a replacement**, and the report says so. The claim it can
support is that fewer defects present when the remote trigger fires means fewer remote rounds. The
claim it cannot support is that a clean local run means the change has been reviewed.

**Its memory is the commit, and there is no local state file.** A findings ledger read back as input
would break the rule field notes live under — never read a local file as input to a classification —
and it would break it at the one place that decides whether the run passes. A resumed run re-reviews
and re-derives instead, which is also the more correct answer: an acceptance is a judgement about the
tree in front of you, and the tree may have moved.

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
and wrong for a public tool used by strangers — **and the duplication objection is answered by
construction.** `tests/extract-fences.sh` pulls the fences _out_ of the procedure and runs them against
recorded API responses through a `gh` stub, so nothing is restated; what is pinned is the interface the
decision table consumes. `## Unexercised paths` survives for what genuinely remains unobserved against
a live reviewer, and keeping that list honest is more useful than making it short.

## No feature detection on `gh`

Only stable REST and GraphQL surfaces are used, and the loop never branches on the `gh` version. Newer
versions offer conveniences revloop does not take, because two code paths would halve the empirical
coverage behind every claim — any given machine exercises only one — and they buy nothing here.
`gh --version` is printed in the step-1 probe table, so the version is visible without being branched
on. The floor itself is in [`install.md`](install.md#requirements).

## Related docs

- [Permissions](permissions.md) — the rules this reasoning produces
- [Configuration](configuration.md#what-is-deliberately-not-configurable) — what is fixed, and why
- [`../commands/review-loop.md`](../commands/review-loop.md) — the procedure, and its per-step `## Notes`
- [`../commands/review-loop-local.md`](../commands/review-loop-local.md) — the local procedure
