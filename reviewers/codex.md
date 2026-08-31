# codex

| Field         | Value                                                             |
| ------------- | ----------------------------------------------------------------- |
| `triggerKind` | `comment`                                                         |
| `trigger`     | `@codex review`                                                   |
| `botLogin`    | `chatgpt-codex-connector[bot]`                                    |
| verdict on    | `comments` (findings arrive as a review; terminal signals do not) |
| `status`      | `verified`                                                        |
| `lastChecked` | 2026-08                                                           |

```json
{
  "trigger": "@codex review",
  "botLogin": "chatgpt-codex-connector[bot]",
  "cleanPatterns": ["^Codex Review: Didn't find any major issues\\."],
  "rateLimitPatterns": ["You have reached your Codex usage limits"],
  "severityLevels": ["P1", "P2", "P3"],
  "markerTolerated": "verified"
}
```

## Measured

- **Latency: three samples, and each wider than the last.** 3–4 minutes to a verdict
  (`iwmaeda/iwmaeda#8`, `#11`; repo C, 2026-08). Ten consecutive rounds on one pull request ran
  3:04, 3:38, 3:52, 4:01, 4:03, 4:25, 4:44, 5:46, 6:27 and 8:01 — range 3:04–8:01, median 4:14, mean
  4:48 (`iwmaeda/revloop#8`, 2026-08). Seven consecutive rounds on the next one ran 2:53, 3:16, 5:09,
  5:32, 6:25, 7:01 and 10:07 — range **2:53–10:07**, median 5:32, mean 5:46 (`iwmaeda/revloop#9`,
  2026-08). All three timed from each trigger's `createdAt` to its review's `submittedAt`. Seventeen
  rounds in this repository span **2:53 to 10:07**. A **clean** round is timed against a different
  endpoint and is not a member of that range: `iwmaeda/revloop#11` found nothing, so its terminal
  signal was an issue comment rather than a review, and trigger to comment ran **3:46** (2026-08).
  **Derived:** budget for the range and not the centre, and treat the range itself as provisional —
  **each sample so far has moved both ends outward**, so the next one probably will too. The clean
  round neither widens nor confirms that range, because it does not measure the same thing; it is
  simply the first figure this repository has for a round that returns no findings. Nothing in
  the loop reads either figure at runtime: step 8 waits in 480-second chunks against `--timeout` and
  never consults a card. **They are no longer only planning numbers, though.** Step 7's floor of three
  silent chunks before a trigger may be re-posted was chosen as roughly 2.4 times the 10:07 end of
  this range, so a sample that widens that end is a reason to revisit the floor — which is the one
  place a measurement on this card now reaches into the procedure.
- **1–4 findings per round** (repo C, 2026-08, 37 rounds). A second sample runs narrower: one PR
  produced **23 finding-bearing rounds returning 1–2 each, mean 1.22**, never more than 2, and an
  earlier PR in the same repository averaged 1.52 with the same maximum (repo C, 2026-08). **The two
  samples share a repository and an account.** **Derived** from that shared origin: they corroborate
  the centre and not the range, because two samples from one source are not two sources. **Derived**
  from the range itself, and the reason this procedure is built around the number: leaving a sibling
  behind costs a whole round.
- **Derived from the samples above**, not separately observed: a round costs roughly one finding, so
  **the number of rounds a PR needs is roughly the number of defects present when the trigger
  fires**. This is arithmetic on the measurements. It is why the procedure sweeps in step 10 and
  re-reads the diff in step 3 — waiting more cleverly cannot move this number, firing with fewer
  defects can.
- **A predicate's missing input forms arrive one per round.** On one PR, roughly 20 of 30 rounds were
  successive members of a single predicate's input space — a particle, then a comma-joined form, then
  leading whitespace, then whitespace around a joiner, then an em dash, then a compound particle
  (repo C, 2026-08). **The corpus never went red for any of them.** **Derived**, and the reason the
  input-space sweep exists: the missing forms are inputs the predicate could receive rather than text
  that exists in the tree, so grepping the repository cannot find the next one.
- **Findings concentrate, and consecutive findings repeat a file.** One PR's 28 findings fell in 3
  files (13/13/2); an earlier one's 30 fell in 5 (14 and 10 in the top two). Across four PRs, the
  next finding landed in the same file as the previous one **39–52%** of the time (repo C, 2026-08).
- **The severity mix moves per PR.** One PR returned 15 of 15 at P2, another 15 of 15 at P1, a third
  25 P1 and 3 P2 (repo C, 2026-08). P3 stayed at zero across all four, which matches the 70-finding
  sample below. **Derived from that spread**, and the reason it is recorded: the badge carries no
  information about which PR you are on, so do not triage by it.
- **Round counts across seven PRs in one repository**: 2, 3, 3, 8, 10, 21, 30 (repo C, 2026-08). The
  30-round PR ran 16.8 hours, with a round-to-round gap of a median 9.2 minutes. **Derived**, by
  multiplying the two: 30 rounds at that median is most of 16.8 hours, so the wall clock tracks the
  number of rounds rather than the length of any single wait. This repository's own three are 10, 7
  and 1 (`iwmaeda/revloop#8`, `#9`, `#11`; 2026-08); the last converged with zero findings on its
  first round. **Derived from those three, and deliberately nothing more:** they are recorded so a
  later sample has something to join. Three PRs of differing size cannot say why a count is what it
  is, and a one-round PR is a single observation — reading it as evidence that any practice shortens
  a loop would be the leap this card's grammar exists to stop.
- **A review can carry its entire finding in the body, with zero inline comments.** Measured on
  `iwmaeda/revloop#13` round 16 (2026-08): the review was `COMMENTED` on the current commit,
  `pulls/<n>/comments` returned **zero** rows for its `pull_request_review_id`, and the body held a
  complete P1 with its severity badge and five enumerated sub-findings. Every earlier round on the
  same pull request put its findings inline and left the body as boilerplate, so this is a
  **tendency, not a contract**. **Derived, and the reason step 10 now reads the body:** a procedure
  that counts inline comments to decide "clean" reports a P1 round as clean, and merges past it under
  `--auto --merge`. One observation, so the frequency is unknown; what is known is that it is
  not zero.
- **Terminal signals arrive as issue comments, not reviews.** On `iwmaeda/iwmaeda#8` and `#11`,
  `/pulls/<n>/reviews` was empty while the clean verdict sat in `/issues/<n>/comments`.
- **The clean phrase's tail varies between rounds.** Observed after
  `Codex Review: Didn't find any major issues.` — `Keep it up!`, `:tada:`, `Breezy!`, and
  `What shall we delve into next?` (repo C, 2026-08), and `Keep them coming!`
  (`iwmaeda/revloop#11`, 2026-08). **Derived:** match it as a prefix, because an
  equality test on a string that is not constant fails a clean round.
- **Supports a one-off focus suffix**: `@codex review <focus>` was accepted and answered on seven
  consecutive rounds (`iwmaeda/revloop#8`, 2026-08). **Derived, and explicitly not measured:** that it
  points the round's findings budget. What was observed is only that the suffix does not stop the
  review.
- **The revloop marker is tolerated, end to end.** A trigger body of `@codex review`, a blank line,
  and the `<!-- revloop:trigger ... -->` comment was recognised and answered (`iwmaeda/revloop#2`,
  2026-08). Ten consecutive marked triggers on one pull request each returned a full review
  (`iwmaeda/revloop#8`, 2026-08); this entry sat under `## Not measured` until then, because the
  round that would have proved it had hit the account's code-review quota. **Derived:** the connector
  does not require the body to be the trigger phrase alone.
- **The rate-limit reply arrives in about 10 seconds**, two orders of magnitude faster than a real
  verdict (`iwmaeda/revloop#2`, 2026-08). Its exact text is `You have reached your Codex usage limits
for code reviews.` followed by a dashboard link (same comment). **Derived:** a reply that much
  faster than a real verdict is a failure rather than a review, and the pattern above matches that
  text as a prefix.
- **REST and GraphQL spell the login differently**, measured on the same comment
  (`iwmaeda/revloop#2`, 2026-08):

  | API     | `login`                        |
  | ------- | ------------------------------ |
  | REST    | `chatgpt-codex-connector[bot]` |
  | GraphQL | `chatgpt-codex-connector`      |

  **Derived:** the wait fence reads GraphQL, so comparing its output against a `botLogin` written the
  REST way rejects every legitimate verdict. Strip the suffix before comparing.

- Severities `P1`/`P2`/`P3` appear as a badge at the head of each finding body. One 70-finding sample
  had 12 P1, 58 P2, and zero P3 (repo C, 2026-08).

## Not measured

- The documented "👍 reaction when there are no findings" path. Every measured trigger carried zero
  reactions.
