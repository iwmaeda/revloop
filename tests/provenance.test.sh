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
# The Provenance section gives two forms, and they are not interchangeable
# fragments: a public observation cites the pull request directly, and a private
# one is anonymised as `repo X` **with the month it was taken**. So the check is
# a PR reference, or a repo tag AND a month — not any one of three. Written as a
# flat alternation it accepted `repo C` with no month, and a bare `2026-08` with
# no source at all, either of which is a bullet nobody can go and check.
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
# The documented exemption names what it rests on. `- **Derived from** …` closes
# the marker with no source, and `- **Derived from   **` closes it with only
# spaces; neither is that exemption, so the span must contain something legible.
DERIVED='^[-*] \*\*Derived from [^*]*[[:alnum:]][^*]*\*\*'

has() { printf '%s\n' "$2" | grep -qE "$1"; }

cited() { # cited <text> -> CITED | UNCITED
  if has "$PR_REF" "$1"; then echo CITED
  elif has "$REPO_TAG" "$1" && has "$MONTH" "$1"; then echo CITED
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
