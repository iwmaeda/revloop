# Adding a reviewer

A reviewer is one of two kinds. A bot that reviews a pull request when a comment asks it to is a
`github-comment` reviewer. A review command that runs on your machine is a
[local command reviewer](#local-command-reviewers). Both are described by a JSON definition and need
no change to the procedures. A preamble the wait fence does not know costs a stop on a round with
nothing to fix while a read observes its mark, and an abort when the mark cannot be made or
confirmed ([below](#if-it-posts-a-preamble-first)).

A reviewer summoned by a reviewer request instead of a comment (GitHub Copilot, for example) is not
supported by the pull-request loops: there is no trigger comment to bind a round to, and step 1 aborts with
`reason=no-comment-trigger`.

## Measure it once, by hand

Open a scratch pull request, post the reviewer's trigger, and record:

| Question                                            | Where the answer goes                                      |
| --------------------------------------------------- | ---------------------------------------------------------- |
| What text triggers it?                              | `trigger`                                                  |
| What login does it post as?                         | `botLogin`                                                 |
| What does it say when it finds nothing?             | `cleanPatterns`                                            |
| What does it say when it is rate-limited?           | `rateLimitPatterns`                                        |
| What severity words does it use?                    | `severityLevels`, most severe first                        |
| What does each of them mean?                        | `severityMap`, onto `critical` / `high` / `medium` / `low` |
| How long did it take?                               | `expectedLatency`                                          |
| Does it still answer with the marker appended?      | `markerTolerated`                                          |
| Do findings arrive as a review, a comment, or both? | The card                                                   |
| How many findings in one round?                     | The card                                                   |
| Does it post anything before the real review?       | The card; see [below](#if-it-posts-a-preamble-first)       |

Read the raw API, which shows which endpoint each item came from:

```bash
gh api graphql -F o='{owner}' -F n='{repo}' -F p=<n> -f query='
  query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){
    comments(last:20){nodes{createdAt author{login __typename} body}}
    reviews(last:10){nodes{submittedAt state author{login __typename} body}}}}}'
```

- Anchor each `cleanPatterns` entry at the start of the message. Reviewers append text that varies
  between rounds, so a whole-string match fails.
- Write `botLogin` with the `[bot]` suffix. revloop strips it before comparing.

## Write the definition

Create `reviewers/acme.json` for a reviewer you intend to ship, or a file at any path for one you
pass with `--config`. Both are validated against
[`schema/reviewer.schema.json`](../schema/reviewer.schema.json).

```json
{
  "$schema": "https://raw.githubusercontent.com/iwmaeda/revloop/main/schema/reviewer.schema.json",
  "displayName": "Acme Reviewer",
  "trigger": "@acme review",
  "botLogin": "acme-reviewer[bot]",
  "cleanPatterns": ["^Acme Review: no issues found"],
  "rateLimitPatterns": ["quota exceeded"],
  "severityLevels": ["blocker", "major", "minor"],
  "severityMap": { "blocker": "critical", "major": "high", "minor": "low" },
  "expectedLatency": "2-8m",
  "markerTolerated": "unverified",
  "status": "unverified"
}
```

The file name is the reviewer's name; there is no `name` key. The field reference is in
[Configuration](configuration.md#reviewer-definitions), and
[`examples/reviewer.custom.json`](../examples/reviewer.custom.json) is another instance.

## Check the marker is tolerated

revloop appends an HTML comment to the trigger:

```text
@acme review

<!-- revloop:trigger v=1 reviewer=acme bot=acme-reviewer head=1a2b3c4d oid=<full commit sha> round=1 -->
```

Most bots ignore it. If yours does not answer with the marker attached, set `markerTolerated: "no"`
and open an issue. There is no fallback: step 1 aborts with `reason=marker-not-tolerated`.

## If it posts a preamble first

Some reviewers acknowledge the trigger before doing the work. Gemini posts `## Summary of Changes`,
and Codex posts a status card that it edits while the review runs. The wait fence drops the ones it
knows.

One it does not know is skipped. Step 9 adds a 👀 reaction to the comment from your account when
fewer than three marks stand and a second read lists the new one among at most three, a firing of
the fence that fetches it ignores that comment, and the wait goes on with the next firing's fetch
deciding. Three marks already standing, a reaction that cannot be added, a second read that does not
list it or one that returns more than three rows abort with `reason=interim-loop` instead. A round
whose pull request carries a bot comment with a 👀 on it since the pull request was opened, whoever
put it there and in whichever run or round, as far as the loop's reads observe, and then has nothing
to fix stops with `reason=unclassified-comment` and prints the comment. Remove the 👀 and run the
command again to accept the verdict. A firing that fetches the 👀 ignores the comment whatever it
says later, so a reviewer that edits that comment into its verdict is read only by a firing that
fetches after the 👀 is removed. Every report lists the marks the loop's last read observed on the
pull request.

To remove that stop, add the preamble to the fence's list. That is a fence edit, which follows the
protocol in [`CONTRIBUTING.md`](../CONTRIBUTING.md#editing-or-adding-a-shell-fence).

## Local command reviewers

A reviewer with `kind: "local-command"` is driven by `/revloop:local-review-loop`,
`/revloop:local-ecc-loop`, or `/revloop:local-custom-loop --config <path>`. Record:

| Question                                    | Where the answer goes                                   |
| ------------------------------------------- | ------------------------------------------------------- |
| Can the model start it, or only a person?   | `invoke`: `skill` for the first, `subprocess` otherwise |
| What is the command line or skill name?     | `command`                                               |
| Where does it take a model?                 | `{reviewModel}` at that spot in `command`, if it does   |
| Does it need an open pull request?          | `requiresPr`                                            |
| What does it say when it is out of quota?   | `rateLimitPatterns`                                     |
| What severity words appear in its output?   | `severityLevels`, most severe first                     |
| What does each of them mean?                | `severityMap`                                           |
| What shape is the output?                   | The card, under `## Output shape`                       |
| How does it choose what to review?          | The card                                                |
| Does it cap findings, write files, or post? | The card                                                |

Read the command's own definition and record the version you read. The card cites it as the
artifact, its exact version and the month (`ecc 2.2.0, 2026-09`), the third provenance form in
[`../reviewers/README.md`](../reviewers/README.md).

### Local traps

- `severityLevels` is what the command prints, which is not always what it documents. A ladder taken
  from the documentation names rungs the output never carries, and then every finding blocks.
- The output shape can change with the model and the effort level. Record the shape for the
  configuration you ran; a subprocess reviewer with `{reviewModel}` reviews on `sonnet` unless
  `--model` says otherwise. A parser written for another shape
  finds nothing, which looks like a clean review.
- A command that diffs against the branch's upstream returns nothing once the branch is pushed. Set
  `requiresPr` correctly: the local loop publishes after convergence when it is `false` and before
  every round when it is `true`, and never under `--no-publish`.
- An out-of-quota reply can exit 0 in one line, like a clean review. Record the message exactly and
  match only its fixed start in `rateLimitPatterns`.
- A headless reviewer that is refused a tool call may end by asking for permission, and that
  question is all it prints. Say in `command` that the run is non-interactive, the way the built-in
  `ecc-review-pr` definition does.
- `invoke: skill` runs on the loop's own model. Use `subprocess` with `{reviewModel}` unless the host
  forbids it.
- A reviewer that emits no severity is normal. Leave out both `severityLevels` and `severityMap`;
  at `minimal` and `standard` the findings are then graded. Never add a ladder the reviewer does not
  emit.
- `severityMap` is your judgement of what the reviewer's rungs mean. Check the result in the step 1
  table, which prints the rungs that block and the rungs that are acceptable.
- Prefer a command that neither writes into the work tree nor posts to GitHub.

## Contributing the card

Once you have driven the reviewer end to end, set `status: "reported"` and consider contributing the
definition and its card to [`reviewers/`](../reviewers/). The maintainers set `verified` after they
reproduce it. The card format is in [`reviewers/README.md`](../reviewers/README.md).
