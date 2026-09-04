# Reviewer presets

**Two files per reviewer, and they answer different questions.**

| File                    | What it is                                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------------------------ |
| `reviewers/<name>.json` | The **definition** — the configuration the loop loads, validated against `schema/reviewer.schema.json` |
| `reviewers/<name>.md`   | The **card** — what was measured, when, and where                                                      |

A card records what was **measured** — not what a vendor's documentation claims. Reviewer products
change; a dated card makes staleness visible instead of silently false. **The definition is the
configuration and the card is the record, and neither restates the other**: the definition used to sit
inside the card as a fenced ` ```json ` block, which made the card two documents with one heading.

**The file name is the name.** There is no `name` key, so there is nothing to drift from the file it
sits in, and the stem must match `^[a-z0-9][a-z0-9-]*$` because the pull-request procedure writes it
into the trigger marker as `reviewer=<name>`. `tests/schema.test.sh` asserts the pairing in both
directions, so neither file ships alone.

**A definition you write with `--config` is the same format**, read by the same loader. A built-in gets
no special case; what it has in addition is a command naming it, and `tests/commands.test.sh` asserts
that every shipped definition has exactly one.

## Kinds

A reviewer is one of two kinds, and the two are driven by different command families. `kind` is absent
from every definition written before the second kind existed, and absent means `github-comment`.

| `kind`           | Driven by                                                 | How it is reached                                                   |
| ---------------- | --------------------------------------------------------- | ------------------------------------------------------------------- |
| `github-comment` | the `remote-*` commands, over `procedures/remote-loop.md` | A trigger comment on a pull request, answered by a bot              |
| `local-command`  | the `local-*` commands, over `procedures/local-loop.md`   | A review command run on this machine, as a subprocess or as a skill |

The fields differ with the kind and the schema enforces the split: a `github-comment` definition
carries a `trigger`, a `botLogin` and a `markerTolerated`, and a `local-command` one carries an
`invoke`, a `command` and a `requiresPr`. Neither may carry the other's — a `botLogin` on a local
reviewer is a field nothing reads, which is the same defect as a config key with no consumer.

**A `local-command` definition's `command` should carry `{reviewModel}` wherever the command takes a
model.** The local procedure expands it — to `--model` if it was typed, otherwise to the built-in
`sonnet` — so the card is where a reviewer declares that it _can_ be pinned. A card that omits it
declares that it cannot, and `--model` then aborts against that reviewer rather than passing
silently. **There is no `model` field**: the placeholder is in `command` for the same reason an effort
argument is, and because the resolved value comes from the flag or the builtin and never from
`.revloop.json`.

**`requiresPr` on a local card now decides two things**, and the second is not about this file: it is
what the local loop reads to place its publish step — before each review or once after convergence —
on a run that publishes at all, `--no-publish` skipping both. So
record it from the command's behaviour, not from whether a pull request happened to exist when you
looked.

`severityLevels` belongs to both and means the same thing in both: **the reviewer's severity
vocabulary, ordered most severe first**, and it is the **emitted** vocabulary rather than the one the
reviewer's documentation defines. It is the ladder `--accept-at` names on its native pass. A card
omits it when the reviewer emits no severity, and omitting it is a measurement like any other — it
makes `--accept-at` abort rather than letting the loop rank findings it is itself obliged to fix.

**`severityMap` belongs to both as well, and it is a different kind of claim from the key beside
it.** It carries each rung of `severityLevels` onto revloop's canonical ladder —
`critical > high > medium > low` — which is what lets `--accept-at high` mean one thing against
reviewers that do not share a vocabulary. **The ladder is measured and the map is judged.** Nothing
establishes that one reviewer's `P1` and another's `CRITICAL` describe the same thing, so the map is
a separate key rather than an ordering folded into the ladder, and **a card states under
`## Not measured` that its map is a judgement** — leaving it beside the ladder without saying so is
the "looks measured" failure this page exists to prevent. A card omits the map when it has no ladder
to map from, and **a canonical level against such a reviewer is then resolved by grading** rather than
by an abort. The map's own abort is for a definition that has a ladder and no map, where deriving one
from position would be the loop authoring a ladder one key over from where that is already forbidden.

**Neither key is what the grader reads.** Grading is for a reviewer with no ladder at all, and the
rungs it produces come from a subprocess outside this loop rather than from a definition. **It is not
a definition field and must not become one**: a card records what its reviewer emits, and a reviewer
that emits no severity does not start emitting one because a floor was typed. What a card should say
about it is what `code-review.md` says — that the absence is measured, and that grading is what
happens instead. **It was a flag until 0.7.0** (`--grade-severity`); it is now a consequence of the
definition's shape, which is the same rule with nothing left to type.

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
difference is worth stating.** "Driven end to end through a real PR" is not available: **the
reviewer never runs on the pull request.** The loop opens one by default now, but the review happened
on your machine before it existed, and under `--no-publish` there is none at all. The equivalent bar
is **the loop driven to convergence** — findings observed, fixed, and
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
