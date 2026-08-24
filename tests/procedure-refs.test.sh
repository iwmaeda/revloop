#!/usr/bin/env bash
# The procedure may cite its own steps, never its own line numbers.
#
# A line number is a copy of a fact that nothing pins and that every edit above
# it invalidates. Two such citations existed and were both correct on the day
# they were written; the first edit that inserted a line above them would have
# made them silently wrong, with no test and no reader able to notice. This is
# the drift class CONTRIBUTING already forbids across files, applied within one.
#
# The guard is scoped to the procedure on purpose. CHANGELOG.md has to be able
# to quote the citations it records removing, and does; a repository-wide grep
# would fail on that entry for saying what it fixed.
#
# The pattern covers the notation, not one spelling of it. An earlier version
# matched `line` singular followed by two or more digits, so joining the very
# two citations it was written to catch — "lines 334 and 371" — would have
# reintroduced the defect and passed. The members below are each pinned
# by a case, because a guard is a predicate and the corpus cannot witness the
# forms it fails to reject: singular and plural, any digit count, either case,
# an optional `#`, the `#L132` anchor, and the `path.md:132` notation.
#
# Dropping the two-digit floor costs one thing: "line 1" meaning the first line
# of some output now trips the guard. Write "the first line" instead, which the
# procedure already does everywhere ("the body's first line", "one line"). The
# floor's other stated purpose was never real — `.line`, `path:line`, and "one
# line" carry no digit at all, so no digit count protects them.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "procedure-refs"

CITATION='\b[Ll]ines?[[:space:]]+#?[0-9]|(^|[^[:alnum:]])#?[Ll][0-9]+\b|\.md:[0-9]+'

caught() { # caught <text> -> CAUGHT | MISSED
  if printf '%s\n' "$1" | grep -qE "$CITATION"; then echo CAUGHT; else echo MISSED; fi
}

# Marked with a literal the pattern itself cannot produce, so the assertion is
# not narrower than the pattern. Matching on "line " would have let a `#L132`
# or a `path.md:132` hit pass unseen — the same defect one level up.
HITS=$(grep -nE "$CITATION" "$ROOT/commands/review-loop.md" | sed 's/^/CITATION /') || true
refute "commands/review-loop.md cites no line numbers" "$HITS" "CITATION "

expect "singular, two digits"     "$(caught 'see line 132 for the rule')"        CAUGHT
expect "plural"                   "$(caught 'see lines 334 and 371')"            CAUGHT
expect "one digit"                "$(caught 'see line 9')"                       CAUGHT
expect "capitalised"              "$(caught 'Line 132 states it')"               CAUGHT
expect "a range"                  "$(caught 'lines 132-139 cover it')"           CAUGHT
expect "a range, en dash"         "$(caught 'lines 132–139 cover it')"           CAUGHT
expect "a hash before the number" "$(caught 'see line #132')"                    CAUGHT
expect "a GitHub #L anchor"       "$(caught 'blob/main/review-loop.md#L132')"    CAUGHT
expect "the path.md:N notation"   "$(caught 'commands/review-loop.md:132 has it')" CAUGHT

# The backticks are the corpus form: the procedure writes both of these inside
# code spans, and a case that drops them stops being a quotation of the text it
# claims to protect. Nothing here is meant to expand.
# shellcheck disable=SC2016
expect "the path:line token"      "$(caught 'cite a `path:line`, a test name')"  MISSED
# shellcheck disable=SC2016
expect "the .line JSON key"       "$(caught '`.line` is null far more often')"   MISSED
expect "one line"                 "$(caught 'stdout is normally one line')"      MISSED
expect "the first line"           "$(caught "the body's first line")"            MISSED
expect "a step citation"          "$(caught 'see step 10 and step 11')"          MISSED
expect "a severity badge"         "$(caught 'a P1 finding and a P2 finding')"    MISSED
expect "a table row citation"     "$(caught 'Rows 3 and 4 below')"               MISSED

summary "procedure-refs"
