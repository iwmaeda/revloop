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
# The pattern covers the notation, not one spelling of it, and it took three
# review rounds to get there because each round widened one axis and left the
# next one spelled by hand. The axes, and what each cost:
#
#   number of digits   `[0-9]{2,}` let "line 9" pass
#   singular / plural  `line` alone let "lines 334 and 371" pass — which is
#                      just the two citations the guard was written to catch,
#                      joined, so it was the likeliest reintroduction of all
#   letter case        `[Ll]` let "LINE 132" and "LINES 334 and 371" pass
#   the separator      a literal space let "line: 132", "line:132" and
#                      "line number 132" pass
#   the notation       matching only the word let "#L132", "review-loop.md:132"
#                      and "review-loop.md: 132" pass
#   the file cited     matching only `.md:` let "procedure-refs.test.sh:40"
#                      pass, though the rule forbids citing any file by line
#
# Every member is pinned by its own case below. A guard is a predicate, and the
# corpus cannot witness the forms a predicate fails to reject, so the cases are
# the only evidence that any of these axes are actually closed.
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

CITATION='\blines?[[:space:]:#]+((numbers?|nos?\.?)[[:space:]:#]+)?[0-9]|(^|[^[:alnum:]])#?l[0-9]+\b|[A-Za-z0-9_-]\.[a-z]{1,4}:[[:space:]]*[0-9]'

caught() { # caught <text> -> CAUGHT | MISSED
  if printf '%s\n' "$1" | grep -qiE "$CITATION"; then echo CAUGHT; else echo MISSED; fi
}

# Marked with a literal the pattern itself cannot produce, so the assertion is
# not narrower than the pattern. Matching on "line " would have let a `#L132`
# or a `path.md:132` hit pass unseen — the same defect one level up.
HITS=$(grep -niE "$CITATION" "$ROOT/commands/review-loop.md" | sed 's/^/CITATION /') || true
refute "commands/review-loop.md cites no line numbers" "$HITS" "CITATION "

expect "singular, two digits"     "$(caught 'see line 132 for the rule')"        CAUGHT
expect "plural"                   "$(caught 'see lines 334 and 371')"            CAUGHT
expect "one digit"                "$(caught 'see line 9')"                       CAUGHT
expect "capitalised"              "$(caught 'Line 132 states it')"               CAUGHT
expect "a range"                  "$(caught 'lines 132-139 cover it')"           CAUGHT
expect "a range, en dash"         "$(caught 'lines 132–139 cover it')"           CAUGHT
expect "a hash before the number" "$(caught 'see line #132')"                    CAUGHT
expect "all caps, singular"       "$(caught 'LINE 132 states it')"               CAUGHT
expect "all caps, plural"         "$(caught 'LINES 334 and 371')"                CAUGHT
expect "a lowercase l anchor"     "$(caught 'blob/main/review-loop.md#l132')"    CAUGHT
expect "a GitHub #L anchor"       "$(caught 'blob/main/review-loop.md#L132')"    CAUGHT
expect "the path.md:N notation"   "$(caught 'commands/review-loop.md:132 has it')" CAUGHT
expect "a colon separator"        "$(caught 'see line: 132')"                    CAUGHT
expect "a colon, no space"        "$(caught 'see line:132')"                     CAUGHT
expect "the word number"          "$(caught 'see line number 132')"              CAUGHT
expect "the abbreviation no."     "$(caught 'see line no. 132')"                 CAUGHT
expect "path.md, space after :"   "$(caught 'review-loop.md: 132 has it')"       CAUGHT
expect "a non-md path cited"      "$(caught 'tests/procedure-refs.test.sh:40')"  CAUGHT

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
expect "a word ending in -line"   "$(caught 'the deadline 3 days out')"          MISSED
expect "read the last line only"  "$(caught 'do not read the last line only')"   MISSED

summary "procedure-refs"
