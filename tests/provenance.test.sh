#!/usr/bin/env bash
# `reviewers/README.md` states the grammar the cards are written to: a
# `## Measured` bullet opens with an observation carrying its provenance, and
# every consequence after it sits behind a `Derived:` marker.
#
# ONLY THE PROVENANCE HALF IS CHECKED HERE, and saying so is the point. Deciding
# whether a sentence is an observation or an inference is exactly the judgement
# the rule was rewritten to remove, and no grep recovers it — a test claiming to
# guard the whole grammar would be the overclaim the grammar exists to prevent.
#
# Provenance is the half that actually failed. Two bullets in `gemini.md` stated
# observations with no citation at all and survived several reviews; the rule had
# required a citation the entire time.
#
# The Provenance section gives three forms, and they are not interchangeable
# fragments: a public observation cites the pull request directly, a private one
# is anonymised as `repo X` **with the month it was taken**, and one read out of
# an installed review command names the artifact and its exact version, again
# with a month. So the check is a PR reference, or a repo tag AND a month, or an
# artifact version AND a month — not any one of five. Written as a flat
# alternation it accepted `repo C` with no month, and a bare `2026-08` with no
# source at all, either of which is a bullet nobody can go and check.
#
# One exemption, and it is the one the rule already documents because it is
# mechanical rather than a judgement: a bullet opening \`**Derived from …**\` names
# what it rests on instead of citing a source, and is a derivation of the bullets
# around it rather than a claim of its own.
#
# DECLINED, ON PURPOSE: checking provenance per sentence rather than per bullet.
# A review asked for it, and the rule is written per sentence, so the gap is
# real: a bullet holding two observations passes on one citation. It is not
# fixed because deciding which sentences in a bullet are observations — as
# against derivations, connective prose, or a quoted reviewer phrase — is the
# judgement this rule was rewritten to remove. A grep that guessed would either
# demand a citation on every sentence, which no card could satisfy, or guess at
# sentence roles and be wrong in the direction that matters. **The unit is the
# bullet, and that is a limit rather than an oversight.** A second observation
# in a bullet is caught by review, not here.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "provenance"

# The forms are matched whole, not as fragments. A bare `#8` is satisfied by
# `C#8` in ordinary prose; `repo [A-Z]` is satisfied by `repo GitHub`, which is
# a name rather than an anonymisation; and an unbounded `[0-9]{2}` month accepts
# `2026-99`. Each of those returned CITED for text nobody can go and check.
# Each form is also bounded at both ends. Without a left boundary `12026-08`
# supplies a month and `owner/repo#0suffix` supplies a reference; without a
# right one, `#8x` does. A pull request is numbered from 1, so `#0` is not one.
PR_REF='(^|[^A-Za-z0-9_.#/-])[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[1-9][0-9]*([^0-9A-Za-z]|$)'
REPO_TAG='repo [A-Z]([^A-Za-z]|$)'
MONTH='(^|[^0-9])[0-9]{4}-(0[1-9]|1[0-2])([^0-9]|$)'
# THE THIRD FORM, added for reviewers that are not GitHub Apps. A local review
# command is not observed on a pull request and not in a private repository; it
# is observed in an installed artifact, and what makes such an observation
# checkable is the artifact's exact version. `ecc 2.2.0` plus a month is more
# checkable than `repo C` plus one, not less: anyone can install that version
# and read the same file, where nobody outside can open repo C at all.
#
# THE MONTH IS PART OF THE PATTERN, NOT A SEPARATE CONJUNCT. Requiring "a
# version somewhere in the bullet AND a month somewhere in it" accepted
# `this repository's 0.5.0 diff, 2026-09` — a version, a month, and no artifact
# named — and that shape had already reached a card. Anchoring the month
# immediately after the version makes the pair one citation instead of two
# coincidences, for the same reason a repo tag alone was never enough.
#
# The name is required lowercase, which is how every one of them is actually
# spelled (`ecc`, `codex`, `claude-code`). What that excludes is a capitalised
# word before a dotted triple — `Measured 2.4.0`, `Verified 1.2.3` — which is how
# such a collision reads in this corpus's prose.
#
# WHAT IT STILL DOES NOT EXCLUDE is a lowercase word that is not an artifact
# name. `revloop 0.4.0, 2026-08` passes, so a bullet can cite **this project's
# own version** as provenance for another artifact's behaviour; so does
# `the floor is 2.4.0, 2026-08`, where the "name" is the word `is`. Two earlier
# versions of this comment claimed otherwise, once about capitalisation and once
# about adjacency, and each claim was false when it was written. The cases below
# pin both rather than describing them, because a limit stated in a comment and
# contradicted by the code is worse than no comment — this file had already gone
# green on its own failure case once.
#
# Neither is closed by widening the shape further. The form is "an artifact and
# its version", `revloop` is an artifact with versions, and `is` is only
# distinguishable from an artifact name by knowing what the sentence is about.
# That is the judgement the per-sentence provenance check was declined for below.
# **The unit is what a grep can see, and this sits outside it.** Caught by
# review, and by the cards keeping observations and readings in named
# subsections so a misfiled one is visible.
ARTIFACT_REF='(^|[^A-Za-z0-9_.#/-])[a-z][a-z0-9-]*[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+,[[:space:]]*[0-9]{4}-(0[1-9]|1[0-2])([^0-9]|$)'
# The documented exemption names what it rests on. `- **Derived from** …` closes
# the marker with no source, and `- **Derived from   **` closes it with only
# spaces; neither is that exemption, so the span must contain something legible.
DERIVED='^[-*] \*\*Derived from [^*]*[[:alnum:]][^*]*\*\*'

has() { printf '%s\n' "$2" | grep -qE "$1"; }

cited() { # cited <text> -> CITED | UNCITED
  if has "$PR_REF" "$1"; then echo CITED
  elif has "$REPO_TAG" "$1" && has "$MONTH" "$1"; then echo CITED
  elif has "$ARTIFACT_REF" "$1"; then echo CITED
  else echo UNCITED
  fi
}

# Pin the predicate before turning it on the corpus: the cards cannot witness a
# form it wrongly accepts or wrongly rejects.
# shellcheck disable=SC2016
expect "a PR reference is provenance"  "$(cited 'seen on `iwmaeda/revloop#8`')"    CITED
expect "a repo tag with its month is"  "$(cited 'seen in repo C, 2026-08')"        CITED
expect "a repo tag without one is not" "$(cited 'seen in repo C, on one PR')"      UNCITED
expect "a bare month is not either"    "$(cited 'observed 2026-08 on a PR')"       UNCITED
expect "an unsourced claim is not"     "$(cited 'the connector does this')"        UNCITED
expect "a bare #N is not a reference"  "$(cited 'the C#8 binding does this')"      UNCITED
expect "a repo name is not a repo tag" "$(cited 'seen in repo GitHub, 2026-08')"   UNCITED
expect "month 99 is not a month"       "$(cited 'seen in repo C, 2026-99')"        UNCITED
expect "month 00 is not either"        "$(cited 'seen in repo C, 2026-00')"        UNCITED
expect "month 13 is not either"        "$(cited 'seen in repo C, 2026-13')"        UNCITED
expect "a month needs a left boundary" "$(cited 'seen in repo C, 12026-08')"       UNCITED
expect "a reference needs one too"     "$(cited 'seen on xowner/repo#8')"          CITED
expect "PR 0 is not a pull request"    "$(cited 'seen on owner/repo#0suffix')"     UNCITED
expect "a reference needs a right end" "$(cited 'seen on owner/repo#8x')"          UNCITED
# The artifact form, pinned on the same axes the other two were.
expect "an artifact and its month"     "$(cited 'read from ecc 2.2.0, 2026-09')"   CITED
expect "a hyphenated artifact name"    "$(cited 'in claude-code 2.1.233, 2026-09')" CITED
expect "an artifact without a month"   "$(cited 'read from ecc 2.2.0')"            UNCITED
expect "a month with no version"       "$(cited 'read from the ecc plugin, 2026-09')" UNCITED
expect "a two-part version is not one" "$(cited 'read from ecc 2.2, 2026-09')"     UNCITED
expect "a capitalised name is not one" "$(cited 'read from ECC 2.2.0, 2026-09')"   UNCITED
expect "a four-part version is not"    "$(cited 'read from ecc 2.2.0.1, 2026-09')" UNCITED
expect "a month elsewhere is not one"  "$(cited 'ran the 0.5.0 diff in 2026-09')"  UNCITED
expect "a version and a loose month"   "$(cited \"the 0.5.0 diff, reviewed 2026-09\")" UNCITED
# THE KNOWN LIMITS, PINNED. These are not assertions that the behaviour is right;
# they assert the behaviour is what the comment above says it is. If a later
# change closes one, its line fails and the comment is rewritten with it, which
# is the only way the two stay in step.
expect "this project's own version passes" "$(cited 'read from revloop 0.4.0, 2026-08')" CITED
expect "a function word reads as a name"   "$(cited 'the floor is 2.4.0, 2026-08')"      CITED

exempt() { if printf '%s\n' "$1" | grep -qE "$DERIVED"; then echo EXEMPT; else echo CHECKED; fi; }
expect "a derivation naming its source" "$(exempt '- **Derived from the samples above**, so')" EXEMPT
expect "an empty derivation marker"     "$(exempt '- **Derived from** an uncited claim')"      CHECKED
expect "a whitespace-only source"       "$(exempt '- **Derived from   ** an uncited claim')"   CHECKED

cards=0
bullets=0
UNSOURCED=

for card in "$ROOT"/reviewers/*.md; do
  name=$(basename "$card")
  # README.md is the format document these cards are written to, not a card.
  [ "$name" = "README.md" ] && continue
  cards=$((cards + 1))
  # A bullet spans lines: a marker opens one, indented lines continue it, blank
  # lines inside it are skipped rather than ending it. Fold each onto one line
  # so a citation on the third line still counts as the bullet's. Both `-` and
  # `*` are valid markers, and the heading may carry extra spaces — a card using
  # either used to yield zero bullets and pass in silence, because the other
  # cards kept the aggregate count non-empty.
  folded=$(awk '/^##[[:space:]]+Measured[[:space:]]*$/{inm=1;next} /^## /{inm=0} inm' "$card" |
    awk '/^[-*] /{if(b!="")print b; b=$0; next} /^ +[^ ]/{b=b" "$0} END{if(b!="")print b}')
  n=$(printf '%s\n' "$folded" | grep -c '^[-*] ') || true
  # Per card, not in aggregate. This is the assertion that a new card cannot
  # slip through by being unparseable.
  expect "  $name has a parseable Measured section" "$(if [ "$n" -gt 0 ]; then echo YES; else echo NO; fi)" YES
  bullets=$((bullets + n))
  while IFS= read -r bullet; do
    [ -n "$bullet" ] || continue
    [ "$(exempt "$bullet")" = EXEMPT ] && continue
    if [ "$(cited "$bullet")" = UNCITED ]; then
      UNSOURCED="$UNSOURCED
UNSOURCED $name: $(printf '%s' "$bullet" | cut -c1-64)"
    fi
  done <<INNER
$folded
INNER
done

# Non-empty, for the same reason the permissions test insists on it: a broken
# extraction finds no violations and would go green on no data.
nz() { if [ "$1" -gt 0 ]; then echo NONEMPTY; else echo EMPTY; fi; }
expect "cards were found to check"         "$(nz "$cards")"   NONEMPTY
expect "those cards have Measured bullets" "$(nz "$bullets")" NONEMPTY

refute "every Measured bullet cites where it came from" "$UNSOURCED" "UNSOURCED "

summary "provenance"
