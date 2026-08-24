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
# The pattern covers the forms enumerated below — not "any citation notation",
# which is a claim no regex over English prose can carry and which this comment
# made for four rounds while the pattern did not. Five review rounds widened it,
# one axis per round, each round leaving the next spelled by hand. The axes, and
# what each cost:
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
#   the filename form  a 1-4 letter extension let "package.jsonc:12" pass, and
#                      requiring an extension at all let "Dockerfile:40" and
#                      "Makefile:12" pass
#   case sensitivity   folding the filename half into the -i grep let
#                      "floor: 2.4.0" and "measured: 0 resolved" match again
#   leading-dot paths  requiring a character before the dot let ".env:12" pass
#   the hyphen form    the separator class omitted "-", so "line-number 12" did
#
# Ten axes. The filename-form one is the only one with no syntax to derive from:
# an extensionless filename is lexically just a word, so nothing separates
# `Dockerfile:40` from prose except the capital. That is measured rather than
# assumed — the corpus holds `floor: 2.4.0`, `measured: 0 resolved`, and two
# `(last:40)` forms inside fences that must not be touched, and every one of
# them is lowercase or has no dot or slash before the colon. So the file branch
# is two rules: a path-shaped token (one containing `.` or `/`, any extension
# length) and a capitalised bare word. A single broad `word: digits` rule was
# tried first and matched all four of those corpus lines.
#
# WHAT THIS GUARD DOES NOT CATCH, and why the list is here rather than in a
# future review comment. It is a tripwire over English prose, not a decision
# procedure, and three forms are out of reach on purpose:
#
#   makefile:12   a lowercase extensionless filename is lexically identical to
#                 the prose this file must not break. `floor: 2.4.0` and
#                 `measured: 0 resolved` are real corpus lines with the same
#                 shape, and two more live inside fences that cannot be edited
#                 without costing every user a permission re-approval. Catching
#                 the lowercase form means breaking those. The capital is the
#                 only signal there is, so only the capitalised form is caught.
#   R:12          a single-letter name; `[A-Z][A-Za-z]+` wants two. Widening it
#                 to one letter matches far more prose than it would ever catch.
#   foo+bar:12    `+` is legal in a filename and absent from the class. No file
#                 in this repository has one, and step 10's own rule is to bound
#                 an input space by what the real inputs can contain.
#
# Those three are declined, not overlooked. If one ever appears in the procedure
# the corpus grep stays silent, and that is the accepted cost.
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

# Two patterns, because case is noise in one half and signal in the other.
# "LINE 132" and "line 132" are the same citation, so that half is matched with
# grep -i. "Dockerfile:40" is a citation and "floor: 2.4.0" is prose, and the
# only thing between them is the capital, so that half must be case-sensitive.
# Folding both into one -i grep was tried and it matched all three of the
# lowercase corpus phrases below — -i does not spare a bracket expression.
CITATION_I='\blines?[[:space:]:#-]+((numbers?|nos?\.?)[[:space:]:#]+)?[0-9]|(^|[^[:alnum:]])#?l[0-9]+\b'
CITATION_S='(^|[^A-Za-z0-9_./+-])[A-Za-z0-9_-]*[./][A-Za-z0-9_./-]*:[[:space:]]*[0-9]|\b[A-Z][A-Za-z]+:[[:space:]]*[0-9]'

caught() { # caught <text> -> CAUGHT | MISSED
  if printf '%s\n' "$1" | grep -qiE "$CITATION_I"; then echo CAUGHT
  elif printf '%s\n' "$1" | grep -qE "$CITATION_S"; then echo CAUGHT
  else echo MISSED; fi
}

# Marked with a literal the pattern itself cannot produce, so the assertion is
# not narrower than the pattern. Matching on "line " would have let a `#L132`
# or a `path.md:132` hit pass unseen — the same defect one level up.
PROC="$ROOT/commands/review-loop.md"
HITS=$( { grep -niE "$CITATION_I" "$PROC"; grep -nE "$CITATION_S" "$PROC"; } | sed 's/^/CITATION /' ) || true
refute "no citation in the forms below reaches the procedure" "$HITS" "CITATION "

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
expect "a 5-letter extension"     "$(caught 'package.jsonc:12 says so')"         CAUGHT
expect "an extensionless file"    "$(caught 'Dockerfile:40 sets it')"            CAUGHT
expect "another bare filename"    "$(caught 'Makefile:12 has the rule')"         CAUGHT
expect "an all-caps bare file"    "$(caught 'LICENSE:3 states it')"              CAUGHT
expect "a leading-dot path"       "$(caught 'see .env:12 for it')"               CAUGHT
expect "the hyphenated word"      "$(caught 'see line-number 12')"               CAUGHT

# Declined, and pinned as declined so the next reader sees a decision rather
# than a hole. See the note above the pattern for why each one is out of reach.
expect "declined: lowercase bare" "$(caught 'makefile:12 has the rule')"         MISSED
expect "declined: one letter"     "$(caught 'R:12 states it')"                   MISSED
expect "declined: + in the name"  "$(caught 'foo+bar:12 says so')"               MISSED

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
expect "lowercase word, colon, N" "$(caught 'Verified gh floor: 2.4.0 (2022-03)')" MISSED
expect "a measured: N phrase"     "$(caught 'measured: 0 resolved, 31 outdated')" MISSED
expect "a jq slice in a fence"    "$(caught 'comments(last:40){nodes{createdAt')"  MISSED
expect "an ISO timestamp"         "$(caught 'SINCE=2026-08-24T07:59:33Z')"       MISSED

summary "procedure-refs"
