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

**A `## Measured` bullet states an observation first, and marks any consequence drawn from it
`Derived`.** The two are different kinds of claim — one can be checked against a PR, the other only
against an argument — and a conclusion that inherits the heading's authority without inheriting its
evidence is the "looks measured" failure `CONTRIBUTING.md` warns about. Design rationale signposted as
such ("which is why the loop…") is not a derived claim and needs no marker; a declarative statement
about reviewer behaviour does. `codex.md` carried two unmarked ones until a review of this repository
found them.

## Adding one

See [`../docs/adding-a-reviewer.md`](../docs/adding-a-reviewer.md). A card and a `.revloop.json`
entry are enough — no change to the procedure or its fences is required.
