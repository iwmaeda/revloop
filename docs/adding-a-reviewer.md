# Adding a reviewer

Any bot that reviews a pull request in response to a comment, and whose first reply is the review or
its verdict, can drive this loop with no change to the procedure and no change to its shell fences.
Two shapes fall outside that — a reviewer with no comment trigger, and one that posts a preamble
before the real review — and both are covered below.

**A reviewer that runs on your machine is a different kind**, measured differently, and has its own
section: [Local command reviewers](#local-command-reviewers).

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

The last three rows have no configuration key: the wait fence pulls comments, reviews and reactions in
a single call regardless, and its drop list lives inside the fence. Record them on the card anyway —
that is where the next person looks.

Read the raw API rather than the web UI, which hides which endpoint a thing came from:

```bash
gh api graphql -F o='{owner}' -F n='{repo}' -F p=<n> -f query='
  query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){
    comments(last:20){nodes{createdAt author{login __typename} body}}
    reviews(last:10){nodes{submittedAt state author{login __typename} body}}}}}'
```

## Traps worth knowing

These are for `github-comment` reviewers; the local kind has its own set.

**Trap:** anchor `cleanPatterns` at the start; never match the whole string. Reviewers append chatter
to their "nothing found" message and it varies between rounds — see the samples on
[`../reviewers/codex.md`](../reviewers/codex.md). An equality test on a string that is not constant
reports "unrecognized bot body" and aborts a clean round.

**Trap:** write `botLogin` with the `[bot]` suffix. GraphQL returns `author.login` without it; REST and
almost all documentation include it. revloop strips it before comparing.

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

A new preamble therefore means a fence edit, which follows the protocol in
[`../CONTRIBUTING.md`](../CONTRIBUTING.md#editing-a-shell-fence). Until it is added the loop does not
hang: step 9 aborts with `interim-loop` and prints the `cid=` and the body, which is exactly the
material the edit needs. Why the drop list cannot live in config is in
[`design-notes.md`](design-notes.md#permission-rules-and-fence-bytes).

## Local command reviewers

A reviewer that runs on your machine rather than on a pull request is `kind: "local-command"`, and it
is driven by `/revloop:review-loop-local`. Nothing about it is measured on GitHub, so the checklist
above does not apply; this one does.

| Question                                                          | Where the answer goes                                                              |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Can the model start it, or only a person?                         | `invoke` — `skill` for the first, `subprocess` for the second                      |
| What exactly is the command line or skill name?                   | `command`                                                                          |
| Does it need an open pull request?                                | `requiresPr`                                                                       |
| What severity vocabulary reaches its **output**?                  | `severityLevels`, ordered most severe first                                        |
| What shape is that output — a JSON block, tagged lines, headings? | the card's prose. **This is the one that decides whether it can be driven at all** |
| Does it cap how many findings one run returns?                    | the card's prose                                                                   |
| Does it write files or post anywhere?                             | the card's prose                                                                   |

**Read the command's own definition, and record the version you read.** For a plugin that is the
installed copy under the plugin cache; for a built-in it is the host's version. Cite it as
`ecc 2.2.0, 2026-09` — the artifact and its exact version, plus the month, which is the third
provenance form in [`../reviewers/README.md`](../reviewers/README.md).

### Local traps worth knowing

**Trap: the vocabulary a command documents is not always the vocabulary it emits.** A command can
define one severity scheme in prose and delegate its output format to an agent that tags findings with
another — [`../reviewers/ecc-review-pr.md`](../reviewers/ecc-review-pr.md) records a shipped example.
`severityLevels` must be the emitted list: a ladder taken from the documented one names rungs the
output never carries, so `--accept-at` matches nothing and blocks everything.

**Trap: an output shape can depend on the model and the effort level, not just on the command.**
Record the shape **per configuration you actually ran** — a parser written against one shape returns
zero findings against another, and zero findings is exactly what a clean review looks like.

**Trap: a reviewer with no severity is normal, and the card should say so rather than invent one.**
Leave `severityLevels` out; `--accept-at` then aborts against that reviewer, which is the intended
outcome.

**Trap: some commands write into the work tree or post to GitHub.** That is a side effect the loop did
not ask for. Prefer a command with nothing to suppress, and record what a rejected one did.

### Candidates worth measuring

Two review commands have a stronger contract than either shipped preset, and **neither ships**, because
nobody has driven them here. Both are worth a card if you do.

- **A workflow-based reviewer that returns a schema-enforced result** — a verdict, a blocking list and
  an advisory list, deduplicated and adversarially verified before it returns. That is the taxonomy the
  acceptance floor is for, already machine-readable. The cost is that it spawns many agents.
- **A reviewer that runs a different model from the one driving the loop.** Among the commands
  surveyed, exactly one does, which makes it the only local reviewer that could be an independent
  check rather than a second opinion from the same source — see
  [`design-notes.md`](design-notes.md#what-a-local-run-does-not-establish).

## Reviewers with no comment trigger

Not supported. Copilot is the example: it is summoned by adding it as a requested reviewer, and the
procedure has only the comment path, so step 1 aborts with `reason=no-comment-trigger`. Its
[card](../reviewers/copilot.md) is kept anyway.

## Contributing the card

Once you have driven it end to end, set `status: "verified"` and consider contributing a card to
[`reviewers/`](../reviewers/) so the next person need not measure it again. The bar for that word, and
why a card written from documentation is worse than no card, are in
[`../reviewers/README.md`](../reviewers/README.md).

## Related docs

- [Configuration](configuration.md#reviewers) — where the `reviewers` block sits in `.revloop.json`
- [`../reviewers/`](../reviewers/) — the existing measurement cards, and the card format
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — the protocol for editing a fence
