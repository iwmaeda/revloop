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
# required a citation the entire time. A citation is a PR reference (`#123`), a
# `repo X` tag, or a `YYYY-MM` date — the three forms the Provenance section
# names.
#
# One exemption, and it is the one the rule already documents because it is
# mechanical rather than a judgement: a bullet opening `**Derived from …**` names
# what it rests on instead of citing a source, and is a derivation of the bullets
# around it rather than a claim of its own.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "provenance"

CITATION='#[0-9]+|repo [A-Z]|[0-9]{4}-[0-9]{2}'

cited() { # cited <text> -> CITED | UNCITED
  if printf '%s\n' "$1" | grep -qE "$CITATION"; then echo CITED; else echo UNCITED; fi
}

# Pin the predicate before turning it on the corpus: the cards cannot witness a
# form it fails to accept, so these are the only evidence the three shapes work.
# The backticks are the corpus form — every card writes a PR reference inside a
# code span — and a case that drops them stops quoting the text it protects.
# shellcheck disable=SC2016
expect "a PR reference is provenance" "$(cited 'seen on `iwmaeda/revloop#8`')" CITED
expect "a repo tag is provenance"     "$(cited 'seen in repo C, one PR')"      CITED
expect "a bare year-month is too"     "$(cited 'observed 2026-08 on a PR')"    CITED
expect "an unsourced claim is not"    "$(cited 'the connector does this')"     UNCITED

cards=0
bullets=0
UNSOURCED=

for card in "$ROOT"/reviewers/*.md; do
  name=$(basename "$card")
  # README.md is the format document these cards are written to, not a card.
  [ "$name" = "README.md" ] && continue
  cards=$((cards + 1))
  # A bullet spans lines: `- ` opens one, indented lines continue it, blank
  # lines inside it are skipped rather than ending it. Fold each onto one line
  # so a citation on the third line still counts as the bullet's.
  folded=$(awk '/^## Measured/{inm=1;next} /^## /{inm=0} inm' "$card" |
    awk '/^- /{if(b!="")print b; b=$0; next} /^ +[^ ]/{b=b" "$0} END{if(b!="")print b}')
  while IFS= read -r bullet; do
    [ -n "$bullet" ] || continue
    bullets=$((bullets + 1))
    case "$bullet" in '- **Derived from'*) continue ;; esac
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
expect "cards were found to check"      "$(nz "$cards")"   NONEMPTY
expect "those cards have Measured bullets" "$(nz "$bullets")" NONEMPTY

refute "every Measured bullet cites where it came from" "$UNSOURCED" "UNSOURCED "

summary "provenance"
