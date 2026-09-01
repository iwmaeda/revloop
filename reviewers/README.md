# Reviewer presets

One card per reviewer. A card records what was **measured**, when, and where — not what a vendor's
documentation claims. Reviewer products change; a dated card makes staleness visible instead of
silently false.

## Kinds

A reviewer is one of two kinds, and the two are driven by different commands. `kind` is absent from
every card written before the second kind existed, and absent means `github-comment`.

| `kind`           | Driven by                       | How it is reached                                                   |
| ---------------- | ------------------------------- | ------------------------------------------------------------------- |
| `github-comment` | `commands/review-loop.md`       | A trigger comment on a pull request, answered by a bot              |
| `local-command`  | `commands/review-loop-local.md` | A review command run on this machine, as a subprocess or as a skill |

The fields differ with the kind and the schema enforces the split: a `github-comment` card carries a
`trigger`, a `botLogin` and a `markerTolerated`, and a `local-command` card carries an `invoke`, a
`command` and a `requiresPr`. Neither may carry the other's — a `botLogin` on a local reviewer is a
field nothing reads, which is the same defect as a config key with no consumer.

`severityLevels` belongs to both and means the same thing in both: **the reviewer's severity
vocabulary, ordered most severe first**. It is the ladder `--accept-at` names. A card omits it when
the reviewer emits no severity, and omitting it is a measurement like any other — it makes
`--accept-at` abort rather than letting the loop rank findings it is itself obliged to fix.

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

**A third form exists for `local-command` cards, because neither of the first two fits them.** A
review command is not observed on a pull request and not inside a private repository; it is observed
in an installed artifact, and what makes such an observation checkable is the artifact's exact
version — `ecc 2.2.0, 2026-09`, `claude-code 2.1.233, 2026-09`. The month is required for the same
reason the anonymised form requires it: these artifacts are re-released, and a version with no date
says what was read without saying whether it is still true.

**The form is provenance for either kind of claim, and the card is what separates them.** A version
plus a month is what makes a reading reproducible, and it is equally what makes a _run_ reproducible —
you cannot repeat either without knowing which build answered. What must not blur is the claim: that a
command **defines** four severity levels is not the same as watching it **emit** one, and letting the
first stand in for the second is the "looks measured" failure this page exists to prevent.

So a `local-command` card splits its `## Measured` section by where the claim came from — a
`### From the installed command` subsection for what was read, and one named for the runs for what was
observed — and keeps everything neither can support under `## Not measured`. **A card written from the
artifact alone has only the first subsection**, and stays `unverified`.

**`unverified` means something narrower for a local reviewer than the table above says, and the
difference is worth stating.** "Driven end to end through a real PR" is not available: there is no
pull request. The equivalent bar is **the loop driven to convergence** — findings observed, fixed, and
a later round returning none. Observing the command answer is not that, however many times it answers.

**Every sentence in a `## Measured` bullet is either an observation carrying its provenance, or sits
behind a `Derived:` marker** — an inference, a recommendation, a remedy, a design consequence, no
exceptions. A bullet may hold several observations; the marker separates kinds of claim, not the
first sentence from the rest. An earlier draft read "opens with an observation, and everything after
that is `Derived:`", which taken literally demands a marker on a bullet's second observation and put
one in front of an exact quoted string. Sentence by sentence is the check. The two are different
kinds of claim: one can be checked against a PR, the other only
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
