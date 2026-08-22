# Adding a reviewer

Any bot that reviews a pull request **in response to a comment**, and whose first reply is the review
or its verdict, can drive this loop with no change to the procedure and no change to its shell
fences. That is the point of the design. Two shapes fall outside it — a reviewer with no comment
trigger, and one that posts a preamble before the real review — and both are called out below rather
than papered over.

## 1. Measure it once, by hand

Open a scratch PR and post the reviewer's trigger. Record:

| Question                                            | Where the answer goes         |
| --------------------------------------------------- | ----------------------------- |
| What text triggers it?                              | `trigger`                     |
| What login does it post as?                         | `botLogin`                    |
| What does it say when it finds nothing?             | `cleanPatterns`               |
| What does it say when it is rate-limited?           | `rateLimitPatterns`           |
| What severity vocabulary does it use?               | `severityLevels`              |
| How long did it take?                               | `expectedLatency`             |
| Does it still answer with the marker appended?      | `markerTolerated`             |
| Do findings arrive as a review, a comment, or both? | the card's prose              |
| How many findings in one round?                     | the card's prose              |
| Does it post anything **before** the real review?   | the card's prose — and see §4 |

The last two rows used to be configuration keys (`verdictOn`, `ignoreCommentPatterns`). They are not,
because nothing consumes them: the wait fence pulls reviews and comments in a single call regardless,
and its list of non-terminal comments to drop lives inside the fence. Recording them on the card is
still worth doing — that is where the next person looks.

Read the raw API rather than the web UI — the web UI hides which endpoint a thing came from:

```bash
gh api graphql -F o='{owner}' -F n='{repo}' -F p=<n> -f query='
  query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){
    comments(last:20){nodes{createdAt author{login __typename} body}}
    reviews(last:10){nodes{submittedAt state author{login __typename} body}}}}}'
```

## 2. Two traps worth knowing before you write the card

**Anchor `cleanPatterns` at the start, never match the whole string.** Reviewers append chatter to
their "nothing found" message, and it varies between rounds — one reviewer's clean phrase was
followed by `Keep it up!`, `:tada:`, `Breezy!`, and `What shall we delve into next?` on different
rounds. An equality test on that string reports "unrecognized bot body" and aborts a clean round.

**Write `botLogin` with the `[bot]` suffix.** GraphQL returns `author.login` without it; REST and
almost all documentation include it. revloop strips it before comparing. If you ever compare the two
forms yourself, remember that equality across them rejects _every_ legitimate verdict.

## 3. Write it down

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

## 4. Check the marker is tolerated

revloop appends an HTML comment to the trigger body:

```text
@acme review

<!-- revloop:trigger v=1 reviewer=acme bot=acme-reviewer head=1a2b3c4d round=1 -->
```

Most connectors ignore trailing content. If yours does not respond with the marker attached, set
`markerTolerated: "no"` and open an issue. **There is no fallback path**: steps 8 and 9 read the
round's whole identity out of the marker, so step 1 aborts with `reason=marker-not-tolerated` rather
than running a degraded loop. Posting the marker as a separate comment has been considered and is not
implemented; if you need it, the issue is where to say so.

## 5. If it posts a preamble first

Some reviewers acknowledge the trigger before doing the work — gemini posts `## Summary of Changes`,
copilot posts `Copilot is reviewing`. Those are **non-terminal** comments, and the wait fence drops
them inside its jq program. It has to happen there: a preamble that reaches the classifier makes the
fence exit on its first iteration every time it is re-fired, an infinite loop that never sleeps.

The fence's drop list is a literal alternation in its jq program, and config deliberately cannot
reach a fence. So a **new** preamble means editing the fence — which costs every user one
re-approval, and follows the protocol in [`../CONTRIBUTING.md`](../CONTRIBUTING.md). Until it is
added, the loop does not hang: step 9 aborts with `interim-loop` and prints the `cid=` and the body,
which is exactly the material the fence edit needs.

## Reviewers with no comment trigger

**Not supported.** Copilot is the example: it is summoned by adding it as a requested reviewer, and
the procedure has only the comment path. Step 1 aborts with `reason=no-comment-trigger` when the
resolved reviewer has no `trigger`.

Its [card](../reviewers/copilot.md) is kept anyway, because what it measured still matters — a
second reviewer's review arriving inside the waiting window is the reason the wait filters by the
marker's `bot=`.

## Contributing the card

Once you have driven it end to end, set `status: "verified"` and consider contributing a card to
[`reviewers/`](../reviewers/) so the next person does not have to measure it again. A card written
from vendor documentation is worse than no card, because it looks measured.
