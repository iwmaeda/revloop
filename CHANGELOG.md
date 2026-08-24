# Changelog

All notable changes to this project are documented here.

**Fence changes are called out explicitly.** The shell fences in
[`commands/review-loop.md`](commands/review-loop.md) are matched by permission rules on their exact
text, so editing one costs every user a single re-approval. See
[`docs/permissions.md`](docs/permissions.md).

## [0.2.0] - 2026-08-25

**No fence changed, so no re-approval is owed** — but **the granted rule list grew by one**, and
anyone who copy-pasted it needs to copy it again. Step 6 no longer runs `gh pr edit`, so
`Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` joins the list in all four places it is written. All
three fences still match the hashes in `tests/fence-hashes.txt`; `tests/fence-guards.test.sh` proves
it on every run.

Everything here came out of operating the loop on the previous release's own pull request, which ran
ten rounds and stopped on `--max-rounds` rather than on convergence. Three of these are defects that
review could not have found, because they are failures of the procedure as run rather than as read.

Fixed:

- **Step 6 told users to run a command that does not work.** Measured twice on `gh 2.4.0`, the
  version this procedure calls its verified floor: `gh pr edit <n> --body-file` exits 1 with
  `GraphQL: Projects (classic) is being deprecated … (repository.pullRequest.projectCards)` and
  leaves the body unchanged. The subcommand asks for that field to populate the pull request's
  current metadata and GitHub has retired it. The body now goes through
  `gh api -X PATCH "repos/{owner}/{repo}/pulls/<n>"`, which is not a new idea — it is why the merge
  already uses REST `PUT` and why CI status comes from `gh pr view --json`. The floor note used to
  say `gh pr create/edit --body-file` "all exist at 2.4.0"; **existing at the floor and working at
  the floor are different claims**, and it now separates them. `gh pr create` is left alone and
  **measured working** at the same floor (`iwmaeda/revloop#9`, 2026-08, exit 0) — it has no existing
  pull request to query, so it never reaches the retired field. That measurement was taken by this
  changelog's own pull request being opened, which is the cheapest experiment that was available.
- **The procedure prescribed an artifact that broke its own verify step.** `.revloop/field-notes.md`
  is git-ignored, but neither `.markdownlint-cli2.jsonc` nor `.prettierignore` excluded it, and the
  documented "one line per event" format runs past MD013 on the first line. Writing the field note
  the procedure asks for turned `npm run check:all` red. Both ignore lists now name **that file**,
  not the directory: excluding all of `.revloop/` would have let any other Markdown left there skip
  the checks, which is more than the collision needed.
- **`reviewers/codex.md` was stale in the file whose whole purpose is separating measured from
  assumed.** Its latency said 3–4 minutes; ten consecutive rounds on one pull request ran 3:04 to
  8:01, median 4:14, timed from each trigger's `createdAt` to its review's `submittedAt`. Both
  samples are kept and labelled, because the new one widens the range rather than replacing the
  centre. Its `## Not measured` still listed an end-to-end review with the marker attached, which
  those same ten rounds measure; that entry has moved into `## Measured` with its provenance. Both
  READMEs carried a copy of the latency figure and both are updated.

Added:

- **`tests/permissions.test.sh` now covers `gh api` as well as `git`.** A rule matches a
  command-string prefix and the flag precedes the path, so each verb needs its own rule — and the
  `-X PATCH` above arrived with none. The check is the same shape as the git half: extract from
  fenced blocks and compare, in both directions. `GRANTED` is read from the fenced `json` block alone rather than
  the page, because the prose names `Bash(gh api *)` in order to discourage it and a grep over the
  document would read that discouragement as a grant. A case pins that scoping. Verified by
  deleting the `-X PATCH` rule and watching the suite go red.

  **The extractor rejects rather than falls back, and it took three rounds to get there because the
  first two answers were the wrong shape.** Both matched a _method group_ and made it optional, so
  any line the group failed to recognise quietly became the bare form — which is granted. Each round
  then widened the alphabet and the next spelling walked straight through: `-XPOST`, then
  `--method PATCH` and a lowercase verb, then `-X  DELETE` with two spaces, `gh  api`, a tab, and
  `-X 'DELETE'`. **The alphabet was never the class. An optional group with a granted default is
  fail-open by construction**, and a permission check may fail closed and never open.

  So it now finds every line invoking `gh api` in any spelling, classifies each against the canonical
  forms alone, and treats anything unclassified as a failure — with the line count asserted equal to
  the number classified, so nothing can be dropped on the way to green. **The verb is matched as
  written, never normalised**: a rule matches a literal prefix, so `Bash(gh api -X PATCH …)` does not
  cover `-X patch`, and normalising would hide exactly that mismatch. Widening the alphabet is no
  longer how a new spelling is handled; rewriting it canonically is. Verified end to end by rewriting
  step 6 as `--method PATCH` and watching the suite go red.

  **The denominator counts invocations, not lines**, which a later round required twice over.
  Classifying one call per line with `head -1` let a second call on the same line go unseen —
  `gh api "repos/x" && gh api -X DELETE …` classified only the granted sibling — and a call split
  across a continuation (`gh \` then `api -X DELETE …`) matched no single-line pattern at all, so it
  was absent from the count rather than counted and rejected. Both fail now: the first as an
  ungranted verb, the second as a non-canonical invocation, each verified by putting it into the
  procedure and watching the suite go red.

  **It compares the whole prefix, scoped path included.** Matching only the verb let
  `gh api -X PATCH "users/example"` reduce to `-X PATCH`, which is granted — while
  `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` would not authorize that call at all. A rule is a
  whole prefix, and comparing half of one answers a question nobody asked.

  **And the direction is no longer one-way, because the reason it was is gone.** `git add` and
  `git commit` were prescribed in step 4's paragraph and `git fetch` in step 9's table, so no block
  held them and three hardcoded assertions named them by hand — a stand-in for a check rather than
  one. The answer was to move the commands rather than widen the grep: they are in fenced blocks now,
  which both steps wanted anyway, since step 4 told you to stage explicitly and never showed the
  command and step 9 buried its recovery in a table cell. With the sets equal, **a granted rule no
  block uses fails too** — a permission nobody needs is a sign the list and the procedure have
  drifted. Verified in both new directions: an off-scope path, and an unused grant.

  **That second direction went to the git half and not the gh half**, which left an unused
  `gh api -X DELETE` grant passing for a round — the same defect surviving because the fix reached one
  of the two places that needed it. Both halves check both directions now, and `docs/permissions.md`
  no longer calls the check one-way.

- **`tests/procedure-refs.test.sh` stopped declining three citation forms, because the reason for
  declining them was removable.** `makefile:12`, `R:12` and `foo+bar:12` were recorded as permanently
  out of reach: a lowercase bare word before a line number is indistinguishable from prose the file
  really contained — `floor: 2.4.0`, `measured: 0 resolved`, and two `(last:NN)` GraphQL slices. Two
  of those were prose and were rewritten to say the same thing without the shape; the other two are
  pagination arguments and are neutralised by name, `first`, `after` and `before` alongside `last`,
  since a fence edit could reach for any of them. With nothing left to collide with, the capital is
  unnecessary and two patterns collapse into one case-insensitive rule. The token must be letter-led
  and must not follow one, or `2026-08-24T07:59:33Z` reads `T07:59` as a file and a line — found by a
  negative case rather than by reasoning, and pinned. Three declined forms became three caught ones.

  **The first attempt skipped each fence wholesale and justified it by the hash guard, which does not
  hold.** `tests/fence-hashes.txt` is re-pinned whenever a fence legitimately changes, and the
  re-approval a fence edit costs is a human agreeing to new permission bytes, not an audit for
  citations. Skipping also discarded the lines _between_ a marker and its opener, which no hash covers
  at all: a citation injected there was invisible while the suite reported all green. The whole file
  is scanned now, and the neutralisation is anchored to the two fields that actually collide
  (`comments`, `reviews`). A bare `(last:40)` pattern would also have swallowed a prohibited prose
  citation written as `(first:12)` — the same over-broad exclusion, one level smaller, in the fix for
  it. An argument on any other field collides loudly instead.

- **`tests/provenance.test.sh` holds the reviewer cards to the grammar `reviewers/README.md`
  states.** **It checks the provenance half only, and says so**: deciding whether a sentence is an
  observation or an inference is the judgement that rule was rewritten to remove, so a test claiming
  to guard the whole grammar would be the overclaim the grammar exists to prevent. Provenance is the
  half that failed anyway — two `gemini.md` bullets stated observations with no citation and survived
  several reviews. The one exemption is the documented mechanical one, for a bullet opening
  `**Derived from …**`. Verified by injecting an uncited bullet and watching it fail.

  **The two provenance forms are not interchangeable fragments, and the first draft treated them as
  three.** The section gives a public form — cite the pull request — and a private one: anonymise as
  `repo X` **with the month**. Written as a flat alternation the check accepted `repo C` with no
  month, and a bare `2026-08` with no source at all, either of which is a bullet nobody can go and
  check. It is now a PR reference, or a repo tag and a month together.

  **Each form is matched whole rather than as a substring**, which a later round caught: a bare
  `#[0-9]+` is satisfied by `C#8` in ordinary prose, `repo [A-Z]` by `repo GitHub` — a name, not an
  anonymisation — and an unbounded month by `2026-99`. A PR reference now needs its `owner/name`, a
  repo tag needs a lone capital, and a month has to be one that exists. **The exemption was loose the
  same way**: `- **Derived from** …` closed the marker without naming anything and skipped the check
  entirely, so the bold span must now contain a source.

  **And a card the extractor could not parse used to pass in silence.** A `*` list marker or a
  `##  Measured` heading with two spaces yielded zero bullets, while the aggregate count stayed
  non-empty from the other cards — an entirely uncited new card would have gone green. Both markers
  are recognised now, and **each card asserts its own parseable section** rather than contributing to
  a total.

  **Each form is bounded at both ends**, which a later round required: without a left boundary
  `12026-08` supplies a month and `owner/repo#0suffix` a reference, and without a right one `#8x`
  does; a pull request is numbered from 1, so `#0` is not one. The derived exemption closed on
  whitespace alone (`- **Derived from   **`) and now needs something legible in the span.

  **One request is declined and recorded as declined**, in the test rather than only in a reply:
  checking provenance per sentence instead of per bullet. The rule is written per sentence, so the
  gap is real — a bullet holding two observations passes on one citation. Deciding which sentences
  are observations, as against derivations or connective prose, is the judgement the rule was
  rewritten to remove; a grep that guessed would either demand a citation on every sentence, which no
  card could satisfy, or guess at sentence roles and be wrong in the direction that matters. The unit
  is the bullet, and that is a limit rather than an oversight.

  Every existing bullet on all four cards satisfies each tightening, checked before it was applied,
  so the guard starts green.

Changed:

- **Step 3's untracked-file whitespace loop reports a status instead of only printing**, and
  **classifies that status rather than masking it with a bit test.** `--no-index` exits 1 for a clean
  new file and 3 for a dirty one, so `2` is the whitespace bit — but `git diff` also exits 128 when it
  cannot read a path, and `128 & 2` is zero, so a bit test calls an unreadable file clean. Measured on
  git 2.34.1: a single `chmod 000` file that `git ls-files -o` does list gives
  `error: open("only.txt"): Permission denied`, exit 128, and a `& 2` loop reports **status 0**. Only
  0 and 1 are clean now, 3 is the whitespace finding, and every other status is an operational failure
  that outranks it, because a check that could not read its input has not passed. `set -o pipefail`
  covers the producer side for the same reason. The braces are load-bearing as `-z` is — the `while`
  is the last stage of a pipeline and therefore a subshell, so a bare assignment would be discarded
  and the status would be the last file's. The output is still the report; the status says only
  whether to look, and at what.

The entries here come from two sources, and the difference matters when reading them.

**The originating measurement** is seven pull requests driven through this loop with codex in a single
repository (private, so `reviewers/codex.md` anonymises it as repo C, 2026-08). Their round counts
were 2, 3, 3, 8, 10, 21, and 30, and **a round returns roughly one finding** — 23 finding-bearing
rounds on one PR at a mean of 1.22, never more than 2. **The rounds a pull request needs is therefore
roughly the number of defects present when the trigger fires**, which is arithmetic on the measurement
rather than a separate observation, and is labelled derived wherever it appears. It is what the
entries below about steps 3, 7 and 10 were **originally written from**; several of them were then
corrected by the second source, and say so in place.

**The rest comes from this pull request reviewing itself.** Its review rounds on the branch that adds
these entries produced further defects in them, each fixed and recorded in place rather than as a
separate entry, and several were measured in throwaway git repositories built for the question — the
`--no-index` exit codes, the filename-handling table, and the `--follow` rename case. Those say
"measured" and name what was run. **This preamble said "everything here comes from one measurement"
until round 6, when the reviewer pointed out it had stopped being true several rounds earlier.**

Added:

- **Step 10 now names three sweeps instead of one, and asks which one matches the class.** The old
  advice was "sweep the whole codebase for its shape", and for the class that dominates the
  measurement it is wrong: **about 20 of one PR's 30 rounds were successive members of a single
  predicate's input space** — a particle, a comma-joined form, leading whitespace, whitespace around
  a joiner, an em dash, a compound particle — one form per round. **A codebase sweep returns zero for
  that class**, because the missing forms are inputs the predicate could receive and not text that
  exists in the tree, so the author concludes the class is closed and the reviewer names the next
  member next round. The three are a **corpus sweep** (instances exist; grep, fix, report count and
  method — the old bullet, now named), an **input-space sweep** (enumerate the form space along
  stated axes, close it as a set in one round, and pin every member with a synthetic case, because
  the corpus cannot witness this class and a test is the only evidence there is), and a **definition
  sweep** (find every other implementation of the predicate just changed and make them agree, or
  delete one — measured: a splitter and its consumer carried two grammars, and one of two gates read
  a different rule). Two guards ship with them: the input-space sweep is **bounded by what the
  predicate's real inputs can contain**, so the rule cannot generate speculative work of its own, and
  **a location already fixed in an earlier round of this PR means the class was named too narrowly**
  — widen and sweep again rather than patch in the new member (measured: four commit subjects on one
  PR name a prior round, and one line was fixed four separate times).
- **Step 3 now reads the pending change before step 4.** The procedure already asserted that the only
  way to spend fewer rounds is to have fewer defects at fire time, and then fired anyway. Step 3
  already argued the same thing about CI — a red run wastes a round, so pay for it before pushing —
  and the measurement makes the reviewer the more expensive of the two. **It is deliberately not a
  generic self-review**: on the measured PR the author was an LLM that had already missed those
  findings once, so a second general reading by the same reader is not supported by anything. It is
  step 10's sweeps, one step earlier. The pass must be reported, because a self-review nobody can see
  is indistinguishable from one that never happened.

  Two things about **what** it reads, both found by the reviewer on this branch's first round.
  **It reads the working tree, not a committed snapshot.** Step 4 has not committed yet and step 11
  re-enters step 3 with the fix unstaged, so the `git diff <base>...HEAD` and `git show HEAD` the
  step first shipped with read a history that does not contain the edits: round 1 could show an empty
  diff, and from round 2 `git show HEAD` shows the previous round's commit — the code the reviewer
  already found a defect in. `git status --porcelain` joins them because **no diff against a commit or
  the index lists an untracked file** — the `--no-index` form added later is the exception, and only
  because it is handed each path explicitly — and `git diff --check` gained an explicit `HEAD`: bare, it
  reads only what is unstaged. **And the change picks what to sweep for without bounding where to
  look.** The definition-sweep bullet asked for rules "this diff states in two places", which the
  diff can answer on its own and which therefore never fires for the drift the sweep exists to catch
  — a second implementation in a file the change never touched. It now searches the repository.

  Round 2 returned the same shape at two of the same locations, so the class was renamed from "reads
  a committed snapshot" to **a check whose actual input is a proper subset of what its stated rule
  covers**, and swept again. `git diff --check HEAD` reaches tracked content only, so a brand-new
  file — where a whitespace error is likeliest — passed it silently; each untracked path now goes
  through the same check against `/dev/null`, chosen over `git add -N .` because intent-to-add writes
  index entries for files step 4 has not decided to stage. `git status --porcelain` collapses a
  wholly-untracked directory into one `?? dir/` line, which is not something you can "read in full" —
  it now carries `-uall` at all three of its sites, and **step 4's is the one that matters**: staging
  a `?? dir/` line stages everything inside it, the blast radius `git add -A` is banned for. The
  re-sweep also reached step 1, where nothing read the repository's history even though steps 4 and 6
  both say commit style and the two languages are "detected" from it; two `git log` calls now do,
  because a row that says `detected` with no detector behind it is worse than an honest `builtin`.

  Round 3 found four more, all of them the mechanics rather than the intent, and three measured on
  throwaway repositories holding three awkward names — one beginning with two blanks, one called
  `-dashfile.txt`, and one with a newline in its name. The first two were run together; the newline
  case separately, which is why it is reported as what `git ls-files` printed rather than as what the
  loop then did. **The untracked loop skipped exactly
  the awkward names it existed to reach**: `read -r` without `IFS=` strips leading blanks
  (`Could not access 'leading-space.txt'`), `git ls-files` without `-z` renders an embedded newline as
  the quoted `"new\nline.txt"`, and a name beginning with `-` reaches `git diff` as options
  (`unknown switch 'd'`) — both files' whitespace errors went unreported while the loop printed
  complaints about their names. It is now `-z` with `IFS= read -r -d ''` and a `--` separator, and the
  procedure states that the **exit status of `--no-index` is not the signal**: every new file differs
  from `/dev/null`, so a clean one exits `1` and a dirty one `3`, and `$? -ne 0` would mark the
  preflight red whenever any untracked file exists. **Step 10's "was this already fixed in an earlier
  round" query gained `--follow`** — measured: a file fixed in round 1 and renamed in round 2 shows
  only the rename, so the question that exists to detect a too-narrow class answered a confident No.
  And step 1's trailer detection read three bodies, which is a sample of shape and not evidence of a
  convention; trailers are now grepped out of twenty.

  Round 4 closed the probe properly. All three `git log` calls read **the same twenty commits**, so
  the three agree with each other — round 3 had bumped the trailer read to twenty while keeping a
  three-body read and labelling it "read in full rather than sampled", which was a label contradicting
  its own command. **Twenty is still a window and not the history**, which is why the row says
  `detected` rather than proven; round 5 corrected the first version of this entry for claiming the
  sample away entirely. The unfiltered body read is the authority and the trailer grep is a
  convenience view of the same twenty, so **a token that grep fails to match still appears in the line
  above it**; the pattern had in fact been too narrow, dropping trailer tokens containing digits. Its
  comment says "lines shaped like a trailer" rather than "trailers", because an ordinary `Note:` line
  mid-body has the same shape.

- **Step 7's focus asks for every sibling in one comment.** The focus already named the class; it did
  not say what to ask for. That this raises findings per round is **derived, not measured** — what is
  measured is only that codex accepts the suffix — and the paragraph says so.
- **Step 7 forbids the literal `revloop:trigger` in the focus text.** The wait fence reads the marker
  as the text after the first occurrence of that literal, and the focus precedes the marker, so a
  focus containing it wins the split. **Measured** against the fence's own jq program: the marker
  string becomes `markers in the diff--`, carrying no `bot=`, `head=`, `reviewer=`, or `round=`.
  **Derived from that, not separately measured**: step 9 aborts on `marker_head=none` (fail-closed,
  one wait spent), and an empty `bot=` leaves the fence's bot filter matching every login, so any
  other bot on the pull request would have satisfied the wait had the round continued. The schema
  already rejects a configured `trigger` containing the literal; the focus is composed in the
  procedure, so the rule now exists there too. `tests/fixtures/jq/focus-carrying-marker` pins **the
  jq output only** — it runs the extracted jq program against one recorded payload that contains no
  bot verdict, so neither the shell that reads the row nor step 9's table is exercised by it. Round 5
  corrected both this entry and the fixture's own assertion labels, which named the step-9 abort as
  though the fixture reached it. The existing clean-comment fixture is the control that proves the
  assertions discriminate.
- **`reviewers/codex.md` carries a second findings-per-round sample** and four new measurements:
  findings concentrate (28 in 3 files, 30 in 5) and the next one repeats the previous file 39–52% of
  the time across four PRs; the severity mix moves per PR (15/15 P2 on one PR, 15/15 P1 on another,
  25 P1 + 3 P2 on a third, P3 zero throughout — from which "do not triage by badge" is derived, and
  marked so on the card); the per-PR round counts; and the input-form-per-round
  shape. **The second sample is not independent of the existing 37-round one** — same repository,
  same account — and is written as corroborating the centre rather than the range, because presenting
  two samples from one source as two sources is the "looks measured" failure `CONTRIBUTING.md` warns
  about.
- **`reviewers/README.md` states the rule the cards are written to**: a `## Measured` bullet opens
  with an observation and its provenance, and everything after that — inference, recommendation,
  remedy, design consequence — sits behind a `Derived:` marker. A bullet with no observation belongs
  under `## Not measured`, which all four cards now have; the single exception is mechanical, for a
  bullet that opens by naming what it derives from.

  **The rule took three rounds to hold, and the reason is the rule's first draft.** It exempted
  "design rationale signposted as such", and that exemption required deciding sentence by sentence
  whether something was rationale or a claim. The judgement went wrong in both directions in
  consecutive rounds: first leaving inferences unmarked, then defending the exemption for four
  sentences a later audit rejected. The exemption is gone, the rule is now mechanical, and it costs
  some `Derived:` markers on sentences whose status was never in doubt — the cheaper side of the
  trade. It also took three rounds because the first two applications only touched `codex.md` while
  the rule sat in a file governing every card, which is the same "stated in one place, not held to
  elsewhere" shape the rule exists to catch. All four cards are now written to it, `gemini.md` and
  `claude.md` and `copilot.md` gained the `## Not measured` sections the rule implies, and the
  focus-suffix bullet gained the provenance it never had.

  A further round found the rule itself still wrong at its boundary: "opens with an observation, and
  everything after that is `Derived:`" demands a marker on a bullet's **second** observation, and had
  put one in front of an exact quoted string on `codex.md`. It now reads sentence by sentence — every
  sentence is an observation with provenance or sits behind the marker — which is the same rule
  without the false ordering. Three cards were corrected under it, and `gemini.md`'s error
  observation gained the date it lacked.

- **`tests/permissions.test.sh` holds `docs/permissions.md`'s granular git list to the procedure.**
  That list is a copy of a fact living in `commands/review-loop.md`, and it had already drifted three
  times — `switch`, `fetch` and `ls-files` were each run by a step the list did not grant. An earlier
  round **declined to test it**, arguing that a grep for `git <word>` cannot tell a command from prose
  since the file says "makes git set the upstream" and names `git show HEAD` twice to forbid it.
  **That reason was wrong.** Runnable commands live in fenced `bash` blocks and prose does not, so
  extracting from the blocks alone yields neither `set` nor `show` and needs no exclusion list. The
  check compares both directions: every subcommand in a block must be granted, and every granted rule
  must be used by a block. It was one-way at first, because `git add` and `git commit` were prescribed
  in step 4's paragraph and `git fetch` in step 9's table, so no block held them and three assertions
  named them by hand. A later round moved the commands into blocks instead — which both steps wanted
  anyway — and the stand-ins went with them. Both extractions must be non-empty, because a broken one
  finds nothing missing and passes on no data.
- **`CONTRIBUTING.md` no longer says `tests/procedure-refs.test.sh` "enforces" the line-number rule.**
  The rule is absolute; the guard catches the forms it enumerates and once declined three it could not tell
  from prose. Tripwire, not proof — and the difference is now in the sentence that sends readers to it.
- **`tests/procedure-refs.test.sh`** fails if the procedure cites one of its own line numbers, and
  `CONTRIBUTING.md` states the rule beside it. **It took five review rounds to make the guard's claim
  match its behaviour, and the reason is worth more than the guard**: each round closed one axis of the
  notation and left the next one spelled by hand, which is the failure the procedure's own
  input-space sweep is written to prevent. The axes, in the order they were found — number of digits
  (`[0-9]{2,}` passed "line 9"), singular versus plural (`line` alone passed "lines 334 and 371",
  which is just the two citations the guard was written to catch, joined), letter case (`[Ll]` passed
  "LINE 132"), the separator (a literal space passed "line: 132", "line:132", "line number 132"), the
  notation (matching the word alone passed "#L132" and "review-loop.md:132"), and the file cited
  (matching only `.md:` passed "procedure-refs.test.sh:40", though the rule forbids citing any file by
  line). Round 4 added two more: the filename form (a 1–4 letter extension passed
  `package.jsonc:12`, and requiring an extension at all passed `Dockerfile:40` and `Makefile:12`) and
  case sensitivity — folding the filename half into the `grep -i` half **re-broke it**, because `-i`
  does not spare a bracket expression, and `floor: 2.4.0` matched again. Case is noise in `LINE 132`
  and signal in `Dockerfile:40`, so the guard is now two patterns, one grep each. The extensionless
  branch is the one axis with no syntax to derive from — an extensionless filename is lexically just a
  word — so it is derived from the corpus instead: every `word: digits` phrase the procedure really
  contains (`floor: 2.4.0`, `measured: 0 resolved`, and two `(last:40)` forms inside untouchable
  fences) is lowercase or has no dot or slash, and all four are pinned as must-not-match cases. Round
  5 added leading-dot paths (`.env:12`) and the hyphen form (`line-number 12`), for ten axes and 41
  assertions.

  **Round 5 also stopped the guard claiming to cover "any citation notation", which is the claim that
  kept being wrong.** No regex over English prose carries it, and the comment had asserted it for four
  rounds while the pattern did not. It now says it covers the enumerated forms, and it names the three
  it deliberately did not — `makefile:12`, `R:12` and `foo+bar:12` — on the ground that a lowercase
  extensionless filename is lexically identical to prose this file must not break. **A later round
  removed that ground and all three are caught**; see the entry above. **The guard is a tripwire, not
  a decision procedure, and the difference is written down.** The assertion was widened alongside
  the pattern — keying on a literal `line` would have let an `#L132` hit through unseen, the same
  defect one level up. The guard stays scoped to `commands/review-loop.md` so that this file can go on
  quoting the citations it records removing.

Changed:

- **`commands/review-loop.md` no longer cites its own line numbers.** `## Notes` named "step 10, line
  334" and "step 11, line 371". Both were correct when written and both were one insertion away from
  being silently wrong; the step numbers were already there, so the line numbers carried nothing.
- **Two copies of a measured number now point at the card that owns it** rather than restating it:
  the flags table said real PRs have needed 20+ rounds (the measured maximum is 30), and step 10's
  lead declared codex at 1–4 and gemini at 30–50 a second time.
- **Both README phase tables** describe the Prepare and Fix phases as they now behave — Prepare sweeps
  the pending change before pushing, and Fix runs the sweep that matches the class rather than "the
  codebase sweep", which is now one of three and the one that does not apply to the dominant class.
- **`docs/permissions.md`'s granular rule list gained `git switch`, `git fetch`, and `git ls-files`**,
  the first two of which step 2 and step 9's recovery row have always run while the list never granted
  them. The list is a copy of a
  fact that lives in the procedure, so it drifts; the section now says outright that no test holds the
  two together and why one would not help — a grep for `git <word>` cannot tell a command from prose,
  and the procedure names `git show HEAD` twice precisely to forbid it.

## [0.1.0] - 2026-08-23

First release. Everything below happened before it, so **no re-approval is owed to anyone**: there
was no earlier version for a fence to have changed from. The fence-related entries are recorded
anyway, because "record every fence edit" is the rule, and a rule that is skipped when it is
convenient is not one.

### Added

- **Both READMEs now describe the loop's flow, and say how long the wait is.** `## How it works` /
  `## 動作の流れ` sits ahead of the install section in each, giving the run as seven phases and then
  stating the part nobody was told: **after the trigger comment, several minutes pass in which nothing
  happens**, because the reviewer is a GitHub app and the loop can only poll it. A first-time user had
  no way to tell that from a hung command — the arrow chain that used to open the English README read
  as if the steps ran back to back. codex's **3–4 minutes to a verdict is measured and dated**
  ([`reviewers/codex.md`](reviewers/codex.md), 2026-08); gemini and claude are given no latency at all
  rather than codex's. The section summarises the procedure at phase level and does not restate it;
  `commands/review-loop.md` remains the only place the steps are written out, and the only place the
  shipped budgets — the 30-second poll, the 480-second chunk, the cumulative `--timeout 30m`, the
  `--max-rounds` circuit breaker, and the CI wait's ~18-minute worst case — are stated. Neither README
  repeats those numbers; `docs/install.md` links to both files from `## Prerequisites` instead.
- **`docs/permissions.md` now covers Codex.** It described only Claude Code's allowlist and never
  said so, which left Codex users to infer their setup from a note in the skill. There is now a
  `## Codex: approval policy and sandbox` section covering `approval_policy`, `sandbox_mode`,
  `sandbox_workspace_write.network_access`, and per-project `trust_level`, and the file opens by
  saying which sections belong to which host. The section states the failure it exists to prevent:
  **a `workspace-write` sandbox commonly runs with `network_access = false`, and every `gh` call in
  the procedure needs the network.** Its key names and value sets were read out of an installed
  `codex-cli 0.147.0` rather than from vendor documentation, and the claim that the configuration
  carries the loop end to end is **labelled derived**, because it has not been driven against a live
  pull request.
- **Both READMEs now state the reviewer prerequisite up front**, above the command block: the Codex or
  Claude GitHub integration must already be installed on the repository and answering comments. Why
  that is a separate thing to install — a `@codex review` comment goes to
  `chatgpt-codex-connector[bot]`, not to the session you are running — is spelled out once, in the new
  `## Prerequisites` section of `docs/install.md`, which the READMEs link rather than restate. This
  was previously one sentence at the tail of `## Requirements`, where the person who most needed it
  had already stopped reading; that sentence moved rather than being duplicated.

- Initial extraction of the review loop into a standalone, reviewer-agnostic tool.
- `.revloop.json` configuration with auto-detection for base branch, verify commands, branch
  prefixes, and commit conventions; JSON Schema and four worked examples.
- Reviewer presets for `codex`, `gemini`, `claude`, and `copilot`, each as a dated card recording
  what was measured and where.
- Fence tests that extract the shell fences from the procedure and replay recorded GitHub responses
  through a `gh` stub, plus structural guards and a fence-hash gate.
- Codex router under `.agents/skills/revloop/`, resolving the same procedure file.
- A **Limitations** section in the README. Forks, detached HEAD, squash and rebase merges, `copilot`,
  and reviewers that post a preamble are all outside what this drives; each is a stop with a named
  reason rather than something a user discovers.
- `tests/version.test.sh`, pinning the version string across the five manifests and the changelog.
- Issue templates (bug report, reviewer measurement), a pull request template, and a code of conduct.

### Changed

- **The install section is now structured identically in both READMEs**, as
  `### Claude Code` / `### Codex`. The English side had a flat `## Install` with Codex reduced to a
  single link, and the Japanese side had an **empty** `## Codex` heading at the wrong level, which
  broke `npm run check:docs`. Both now carry the same two subsections in the same order, and the
  permission setup lives inside the host it belongs to — the allowlist JSON under `### Claude Code`,
  the approval-policy-and-sandbox pointer under `### Codex` — rather than in a third section that had
  to name both.
- **The Japanese README moved to the repository root, and the English one was cut down to match it.**
  It was `docs/ja/README.ja.md`, a partial overview that covered install and design intent; it is
  `README.ja.md`, a standalone README, and `README.md` now mirrors it section for section — same
  headings in the same order, same tables, same examples — so the two can be compared line by line and
  drift is visible rather than quiet. **The parity was reached by shortening the English side, not by
  expanding the Japanese one.** **The old path is gone, not redirected**, so a link to it 404s; the
  only reference in this repository was the README's own documentation table, and it was updated.
  The procedure itself is unchanged and still English-only, and no fence changed, so **no
  re-approval is owed**.

- **Toolchain versions are stated once, in `mise.toml`.** CI installs them with
  `jdx/mise-action`, replacing `actions/setup-node` and the `node-version: 24` that was duplicated
  across both jobs. `jq` and `shellcheck` are now pinned there too — jq at 1.7.1 (the final patch of
  the 1.7.x series `ubuntu-latest` carried when this was written) and shellcheck at 0.9.0 (matching
  the image exactly) — so a runner image update can no longer change a lint verdict on its own.
  Dependabot does not track mise pins, so raising them stays a manual, deliberate step.

  This closes a real gap rather than only removing duplication. `tests/lint-shell.sh` and
  `tests/jq-program.test.sh` skip themselves when their binary is absent, so a contributor without
  `jq` and `shellcheck` saw `npm run check:all` pass having run neither — while CI ran both. After
  `mise install` the two agree.

- **The configuration surface now matches what the procedure consumes.** About twenty-five schema
  keys had no consumer in `commands/review-loop.md`, which is the single source of truth for
  behaviour — so configuring them did nothing while looking like it did something. Removed:
  `project.roundSource`, `project.commit.embedRoundNumber`, `project.pr.titleTemplate`,
  `project.pr.bodyUpdateMethod`, `project.pr.mergeMethod`, `project.pr.requireCleanCiForMerge`,
  `reviewers.*.triggerKind`, `reviewers.*.announce`, `reviewers.*.focusSuffix`,
  `reviewers.*.verdictOn`, and `reviewers.*.ignoreCommentPatterns`. What each of them was reaching
  for is now stated as a fixed property in `docs/configuration.md` under **What is deliberately not
  configurable**, with the reason it is fixed.

  The round number, which `roundSource` used to select a strategy for, is now defined in step 7:
  the count of `revloop:trigger` markers already on the PR, plus one.

- **Actions are pinned to commit shas** rather than to `@v5`/`@v4`, for the same reason `mise.toml`
  pins jq and shellcheck exactly. `actions/checkout` also moves to v7.

- **`npm audit` runs in CI as its own job**, and `.revloop.json`'s `verifyNotes` now names it as the
  gap `check:all` does not cover. `audit` needs the network and `check:all` has to stay runnable
  offline, so this repository demonstrates its own `verifyNotes` feature rather than claiming to have
  no gap.

- **`ajv-cli` replaced by `ajv` called directly** from `tests/validate-schema.mjs`. `ajv-cli` has not
  moved since 2021 and its dependency tree carried a high-severity prototype-pollution advisory
  through `fast-json-patch` (GHSA-8gh8-hqwg-xf34), which `npm audit fix --force` proposed to resolve
  by downgrading four major versions. The wrapper was the problem; the wrapper is now forty lines in
  this repository, and it distinguishes "the schema rejected it" from "the validator never ran" —
  the reject cases would otherwise pass for the wrong reason after a typo in a path.

### Removed

- **`README.md` no longer carries `## Why it is built the way it is`, `## Tests`, or the
  `### The wait is the slowest part of the loop` subsection.** Each was English-only, and keeping them
  is what made the two READMEs impossible to diff. Nothing was lost, only relocated to the file that
  already owned it: the design rationale is in [`docs/design-notes.md`](docs/design-notes.md), the
  check commands and the warning that `check:all` **goes green having skipped shellcheck and jq**
  without `mise install` are in [`CONTRIBUTING.md`](CONTRIBUTING.md), and the wait budgets are in
  `commands/review-loop.md`. All three are still reachable from the README's documentation table or
  from `docs/install.md`. **`--timeout` is the one flag no longer named anywhere in either README** —
  it remains in the procedure's flag table and in the command's `argument-hint`.

### Fixed

- **All three fences**: a detached HEAD made `git branch --show-current` print nothing, and
  `gh pr list --head ""` reads an empty value as **no filter** rather than as no match — so it
  answered with the first open PR in the repository. Measured here: the unguarded command returned an
  unrelated Dependabot PR (`iwmaeda/revloop#4`). The wait fence would have read a stranger's
  comments, step 12 would have reported a stranger's CI as green, and only the merge fence's `sha=`
  pin stood between that and a merge of someone else's branch — one interlock deep is not enough for
  a gate. Each fence now resolves the branch first and exits `no-branch` when it is empty; step 9's
  table and step 12's output list carry the new reason.

  This changes fence bytes in all three fences.

- **wait-verdict fence**: revloop's own trigger comment matched both trigger classes at once, so a
  single comment emitted two `TRIG` rows with identical timestamps. `tail -1` then took the
  compatibility row, discarding the marker — and with it the `bot=` filter that excludes other bots
  and the `head=` value the runaway check depends on. The compatibility class now excludes bodies
  that already carry a marker. Found by running the fence's jq program against a raw GraphQL payload;
  the row-level fixtures could not see it, because they were written by hand with one row per
  comment.

  This changes fence bytes.

- **A repository could grant itself an unattended merge.** `defaults.merge` and `defaults.auto` were
  configuration keys, and `.revloop.json` comes from whatever repository you are working in,
  including one you just cloned. A hostile or careless config could therefore turn on merging and
  delete both human confirmation points, while `SECURITY.md` claimed safety rules could not be
  switched off from config. Both keys are removed: `--merge` and `--auto` are settable by flag only,
  because the flag is the approval. `tests/schema.test.sh` now asserts both are rejected.

- **The command granted itself the wide permission rule its own docs warn against.** The frontmatter
  carried `Bash(gh api *)` — which reaches every repository the token can touch, and which
  `README.md`, `docs/permissions.md` and `SECURITY.md` all name as the rule to avoid — in a syntax
  (`Bash(git *)`) that did not match the documented one either. It is now the same rules the docs
  tell you to grant, and `tests/fence-guards.test.sh` fails if the frontmatter ever grants something
  `docs/permissions.md` does not list.

  The first pass narrowed to a single `Bash(gh api repos/{owner}/{repo}/:*)` rule and missed that a
  rule matches a command-string **prefix**: the reply-to-finding call and the merge fence both put
  `-X POST`/`-X PUT` before the path, so neither matched. Under `--merge --auto` that reintroduced
  exactly the stall the narrowing was meant to avoid. Two more rules, scoped the same way —
  `Bash(gh api -X POST repos/{owner}/{repo}/:*)` and `Bash(gh api -X PUT repos/{owner}/{repo}/:*)` —
  cover them. Found in review before release.

  The same gap existed one flag over: reading findings (step 10) and verifying a reply (step 11)
  both call `gh api --paginate "repos/{owner}/{repo}/..."`, and `--paginate` sits before the path
  the same way `-X POST`/`-X PUT` do, so none of the existing rules matched either. One more rule,
  `Bash(gh api --paginate repos/{owner}/{repo}/:*)`, covers them. Also found in review before
  release.

- **A hand-typed trigger produced a misleading abort.** A compatibility-class trigger carries no
  marker, so `marker_head=none`, which step 9's check (c) reported as "the runaway invariant is
  violated, or someone else pushed" — sending the reader hunting for a push that never happened. It
  has its own row now, and `docs/design-notes.md` states that anchoring a baseline is the whole of
  what the compatibility class does.

- **`copilot` is marked `unsupported`, not `unverified`.** It has no comment trigger, and the
  reviewer-request path it needs was never written, so `--reviewer copilot` could not run. Step 1
  now aborts with `reason=no-comment-trigger`. The card is kept for what it measured.

- **The claim that adding a reviewer never needs a fence change was false** for a reviewer that
  posts a preamble before its verdict — the drop list is inside the fence, where config cannot reach.
  `README.md` and `docs/adding-a-reviewer.md` now say so, and name the `interim-loop` abort as the
  signal that a fence edit is owed.

- **`docs/install.md` gave `git` no version floor.** It is 2.22 (`git branch --show-current`),
  labelled as derived from the feature rather than measured, next to the `gh` floor that was.

[0.2.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.2.0
[0.1.0]: https://github.com/iwmaeda/revloop/releases/tag/v0.1.0
