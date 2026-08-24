# Reviewer presets

One card per reviewer. A card records what was **measured**, when, and where — not what a vendor's
documentation claims. Reviewer products change; a dated card makes staleness visible instead of
silently false.

## Status vocabulary

| `status`      | Meaning                                                            |
| ------------- | ------------------------------------------------------------------ |
| `verified`    | Driven end to end through a real PR, by the maintainers            |
| `reported`    | Someone reported it working; not reproduced here                   |
| `unverified`  | Shipped as a starting point. **Never inferred from documentation** |
| `unsupported` | Measured and found not to work in the way this loop needs          |

## Provenance

Observations from public repositories cite the PR directly (`iwmaeda/iwmaeda#8`). Observations from
private repositories are anonymised as `repo B` / `repo C` with the month they were made. Provenance
is not decoration: this procedure is only worth trusting because it separates what was measured from
what was assumed, and that distinction is meaningful only if a reader can go and check.

**A `## Measured` bullet opens with an observation and its provenance. Everything after that sits
behind a `Derived:` marker** — an inference, a recommendation, a remedy, a design consequence, no
exceptions. The two are different kinds of claim: one can be checked against a PR, the other only
against an argument, and a conclusion that inherits the heading's authority without inheriting its
evidence is the "looks measured" failure `CONTRIBUTING.md` warns about. **A bullet with no observation
does not belong here at all** — it goes under `## Not measured`, which every card has. The one
exception is mechanical rather than a judgement call: a bullet that opens by naming what it rests on
(`**Derived from the samples above**`) is a derivation of the bullets around it and belongs beside
them.

**The first version of this rule exempted "design rationale signposted as such", and that exemption is
gone.** It required deciding, sentence by sentence, whether something was rationale or a claim, and
that judgement was made wrong in both directions in two consecutive review rounds — first by leaving
inferences unmarked, then by defending the exemption for four more that a later audit rejected. A
mechanical rule can be checked by reading; a judgement call gets re-litigated every review. The cost
is some `Derived:` markers on sentences whose status was never really in doubt, which is the cheaper
side of the trade.

## Adding one

See [`../docs/adding-a-reviewer.md`](../docs/adding-a-reviewer.md). A card and a `.revloop.json`
entry are enough — no change to the procedure or its fences is required.
