# Adding a reviewer

Any bot that reviews a pull request in response to a comment, and whose first reply is the review or
its verdict, can drive this loop with no change to the procedure and no change to its shell fences.
Two shapes fall outside that: a reviewer with no comment trigger, and one that posts a preamble
before the real review. Both are covered below.

## Measure it once, by hand

Open a scratch PR, post the reviewer's trigger, and record:

| Question                                            | Where the answer goes                                                                    |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| What text triggers it?                              | `trigger`                                                                                |
| What login does it post as?                         | `botLogin`                                                                               |
| What does it say when it finds nothing?             | `cleanPatterns`                                                                          |
| What does it say when it is rate-limited?           | `rateLimitPatterns`                                                                      |
| What severity vocabulary does it use?               | `severityLevels`                                                                         |
| How long did it take?                               | `expectedLatency`                                                                        |
| Does it still answer with the marker appended?      | `markerTolerated`                                                                        |
| Do findings arrive as a review, a comment, or both? | the card's prose                                                                         |
| How many findings in one round?                     | the card's prose                                                                         |
| Does it post anything before the real review?       | the card's prose — and see [If it posts a preamble first](#if-it-posts-a-preamble-first) |

The last two rows used to be configuration keys (`verdictOn`, `ignoreCommentPatterns`). Nothing
consumes them — the wait fence pulls comments, reviews and reactions in a single call regardless, and
its drop list lives inside the fence — but recording them on the card is where the next person looks.

Read the raw API rather than the web UI, which hides which endpoint a thing came from:

```bash
gh api graphql -F o='{owner}' -F n='{repo}' -F p=<n> -f query='
  query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){
    comments(last:20){nodes{createdAt author{login __typename} body}}
    reviews(last:10){nodes{submittedAt state author{login __typename} body}}}}}'
```

## Traps worth knowing

**Trap:** anchor `cleanPatterns` at the start; never match the whole string. Reviewers append chatter
to their "nothing found" message, and it varies between rounds — one reviewer's clean phrase was
followed by `Keep it up!`, `:tada:`, `Breezy!`, and `What shall we delve into next?`. An equality test
on that string reports "unrecognized bot body" and aborts a clean round.

**Trap:** write `botLogin` with the `[bot]` suffix. GraphQL returns `author.login` without it; REST and
almost all documentation include it. revloop strips it before comparing, but if you ever compare the
two forms yourself, equality across them rejects every legitimate verdict.

## Write the card

In `.revloop.json`:

```json
{
  "version": 1,
  "defaults": { "reviewer": "acme" },
  "reviewers": {
    "acme": {
      "displayName": "Acme Reviewer",
      "trigger": "@acme review",
      "botLogin": "acme-reviewer[bot]",
      "cleanPatterns": ["^Acme Review: no issues found"],
      "rateLimitPatterns": ["quota exceeded"],
      "severityLevels": ["blocker", "major", "minor"],
      "expectedLatency": "2-8m",
      "markerTolerated": "unverified",
      "status": "unverified"
    }
  }
}
```

## Check the marker is tolerated

revloop appends an HTML comment to the trigger body:

```text
@acme review

<!-- revloop:trigger v=1 reviewer=acme bot=acme-reviewer head=1a2b3c4d round=1 -->
```

Most connectors ignore trailing content. If yours does not respond with the marker attached, set
`markerTolerated: "no"` and open an issue. There is no fallback: steps 8 and 9 read the round's whole
identity out of the marker, so step 1 aborts with `reason=marker-not-tolerated` rather than running a
degraded loop.

## If it posts a preamble first

Some reviewers acknowledge the trigger before doing the work — gemini posts `## Summary of Changes`,
copilot posts `Copilot is reviewing`. Those comments are non-terminal, and the wait fence drops them
inside its jq program.

A new preamble therefore means editing the fence, which costs every user one re-approval and follows
the protocol in [`../CONTRIBUTING.md`](../CONTRIBUTING.md). Until it is added the loop does not hang:
step 9 aborts with `interim-loop` and prints the `cid=` and the body, which is exactly the material
the fence edit needs. Why the drop list cannot live in config is in
[`design-notes.md`](design-notes.md#permission-rules-and-fence-bytes).

## Reviewers with no comment trigger

Not supported. Copilot is the example: it is summoned by adding it as a requested reviewer, and the
procedure has only the comment path, so step 1 aborts with `reason=no-comment-trigger`. Its
[card](../reviewers/copilot.md) is kept anyway — a second reviewer's review arriving inside the
waiting window is the reason the wait filters by the marker's `bot=`.

## Contributing the card

Once you have driven it end to end, set `status: "verified"` and consider contributing a card to
[`reviewers/`](../reviewers/) so the next person need not measure it again. A card written from vendor
documentation is worse than no card, because it looks measured.

## Related docs

- [Configuration](configuration.md#reviewers) — where the `reviewers` block sits in `.revloop.json`
- [`../reviewers/`](../reviewers/) — the four existing measurement cards
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — the protocol for editing a fence
