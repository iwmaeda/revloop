# Adding a reviewer

Any bot that reviews a pull request in response to a comment can drive this loop. **No change to the
procedure or to its shell fences is required** — which is the whole point of the design.

## 1. Measure it once, by hand

Open a scratch PR and post the reviewer's trigger. Record:

| Question                                            | Where the answer goes   |
| --------------------------------------------------- | ----------------------- |
| What text triggers it?                              | `trigger`               |
| What login does it post as?                         | `botLogin`              |
| Do findings arrive as a review, a comment, or both? | `verdictOn`             |
| What does it say when it finds nothing?             | `cleanPatterns`         |
| What does it say when it is rate-limited?           | `rateLimitPatterns`     |
| Does it post anything **before** the real review?   | `ignoreCommentPatterns` |
| How long did it take?                               | `expectedLatency`       |
| How many findings in one round?                     | the card's prose        |

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
      "triggerKind": "comment",
      "trigger": "@acme review",
      "botLogin": "acme-reviewer[bot]",
      "verdictOn": ["reviews", "comments"],
      "cleanPatterns": ["^Acme Review: no issues found"],
      "rateLimitPatterns": ["quota exceeded"],
      "ignoreCommentPatterns": ["^Acme is analysing"],
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
`markerTolerated: "no"` and open an issue — the fallback is to post the marker as its own comment
immediately after the trigger, which preserves the loop's baseline semantics.

Once you have driven it end to end, set `status: "verified"` and consider contributing a card to
[`reviewers/`](../reviewers/) so the next person does not have to measure it again.

## Reviewers with no comment trigger

Set `triggerKind: "reviewer-request"` and `announce: true`. revloop posts a marker-carrying
announcement comment and issues the reviewer request through the API. `copilot` works this way —
see [its card](../reviewers/copilot.md).
