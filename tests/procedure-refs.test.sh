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
# THREE FORMS USED TO BE DECLINED HERE and are not any more, which is worth
# keeping because of how they stopped being declined. `makefile:12`, `R:12` and
# `foo+bar:12` were recorded as out of reach: a lowercase extensionless filename
# is lexically identical to `floor: 2.4.0` and `measured: 0 resolved`, real lines
# in this corpus, and to two `(last:NN)` slices inside a fence. The capital was
# said to be the only available signal.
#
# It was not. The two prose lines were rewritten to say the same thing without
# the shape, and the two fence lines are GraphQL pagination arguments that can be
# neutralised by name. **The collision was removable, so the limit was a choice
# described as a constraint** — which is the failure this file exists to guard
# against, appearing in the guard's own comment.
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

# ONE PATTERN, MATCHED CASE-INSENSITIVELY, over the whole file. Both halves of
# that sentence used to be different, and reviews closed the gap by changing the
# input rather than the checker.
#
# The file branch used to require a capital, because a lowercase bare word before
# `:<digits>` was indistinguishable from prose the file really contained —
# `floor: 2.4.0`, `measured: 0 resolved`, and two `(last:NN)` slices. So
# `makefile:12`, `R:12` and `foo+bar:12` were recorded as permanently declined.
#
# They are not declined any more, because the collisions were removable. The two
# `(last:NN)` forms live inside hash-pinned fences, which are byte-frozen shell
# code that cannot acquire a citation without a fence edit and a re-approval, so
# the scan skips them. The other two were prose, and prose can be rewritten:
# "floor is 2.4.0" and "measured 0 resolved" say the same thing. With nothing
# left to collide with, the file branch is any letter-led token before a line
# number, the capital is unnecessary, and one case-insensitive pattern replaces
# two. The token must start with a letter, a dot or a slash and must not follow
# one: without that, `2026-08-24T07:59:33Z` reads `T07:59` as a file and a line.
CITATION='\blines?[[:space:]:#-]+((numbers?|nos?\.?)[[:space:]:#]+)?[0-9]|(^|[^[:alnum:]])#?l[0-9]+\b|(^|[^A-Za-z0-9_.+/-])[A-Za-z._][A-Za-z0-9_.+/-]*:[[:space:]]*[0-9]'

# NEUTRALISE THE COLLISION, DO NOT SKIP THE REGION. An earlier version dropped
# each fence — marker line through the close of its bash block — and justified it
# by the hash guard. That justification does not hold: `tests/fence-hashes.txt`
# is re-pinned by `tests/update-fence-hashes.sh` whenever a fence legitimately
# changes, and the re-approval a fence edit costs is a human agreeing to new
# permission bytes, not an audit for citations. Skipping also discarded the lines
# *between* the marker and its opener, which no hash covers at all. A citation
# injected there was invisible while the suite reported all green.
#
# The whole file is scanned now. The only thing standing in the way was two
# GraphQL pagination arguments in the wait fence — `comments(last:40)` and
# `reviews(last:15)` — so those are neutralised and nothing else is.
#
# THE FIELD NAME IS PART OF THE PATTERN, not decoration. Matching a bare
# `(last:40)` anywhere would also swallow a prohibited prose citation written as
# `(first:12)`, which is the over-broad exclusion this guard was just fixed for,
# reappearing one level smaller. Anchoring to the field means an argument on any
# other field collides loudly instead — the direction to fail. `first`, `after`
# and `before` ride along with `last` only because a fence edit could reach for
# one on these same two fields.
depaginate() {
  sed -E 's/\b(comments|reviews)\((first|last|after|before):[0-9]+\)/\1(PAGINATION)/g' "$1"
}

caught() { # caught <text> -> CAUGHT | MISSED
  if printf '%s\n' "$1" | grep -qiE "$CITATION"; then echo CAUGHT; else echo MISSED; fi
}

# EVERY procedure is scanned, not only the first one. The rule is that a
# procedure may cite its own steps and never its own line numbers, and it
# applies to whichever file is being read — a guard naming one file would leave
# the next procedure free to acquire exactly the citations this forbids.
PROCS=("$ROOT"/commands/*.md)
if [ ! -f "${PROCS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
fi
# Marked with a literal the pattern itself cannot produce, so the assertion is
# not narrower than the pattern.
for proc in "${PROCS[@]}"; do
  HITS=$(depaginate "$proc" | grep -niE "$CITATION" | sed 's/^/CITATION /') || true
  refute "no citation in the forms below reaches $(basename "$proc")" "$HITS" "CITATION "
done

# The corpus cannot witness a form the pattern fails to reject, so every member
# gets a case. Grouped by the axis it closes.
expect "singular, two digits"     "$(caught 'see line 132 for the rule')"        CAUGHT
expect "plural"                   "$(caught 'see lines 334 and 371')"            CAUGHT
expect "one digit"                "$(caught 'see line 9')"                       CAUGHT
expect "capitalised"              "$(caught 'Line 132 states it')"               CAUGHT
expect "all caps, singular"       "$(caught 'LINE 132 states it')"               CAUGHT
expect "all caps, plural"         "$(caught 'LINES 334 and 371')"                CAUGHT
expect "a range"                  "$(caught 'lines 132-139 cover it')"           CAUGHT
expect "a range, en dash"         "$(caught 'lines 132–139 cover it')"           CAUGHT
expect "a hash before the number" "$(caught 'see line #132')"                    CAUGHT
expect "a colon separator"        "$(caught 'see line: 132')"                    CAUGHT
expect "a colon, no space"        "$(caught 'see line:132')"                     CAUGHT
expect "the word number"          "$(caught 'see line number 132')"              CAUGHT
expect "the abbreviation no."     "$(caught 'see line no. 132')"                 CAUGHT
expect "the hyphenated word"      "$(caught 'see line-number 12')"               CAUGHT
expect "a lowercase l anchor"     "$(caught 'blob/main/review-loop.md#l132')"    CAUGHT
expect "a GitHub #L anchor"       "$(caught 'blob/main/review-loop.md#L132')"    CAUGHT
expect "the path.md:N notation"   "$(caught 'commands/review-loop.md:132 has it')" CAUGHT
expect "path.md, space after :"   "$(caught 'review-loop.md: 132 has it')"       CAUGHT
expect "a non-md path cited"      "$(caught 'tests/procedure-refs.test.sh:40')"  CAUGHT
expect "a 5-letter extension"     "$(caught 'package.jsonc:12 says so')"         CAUGHT
expect "an extensionless file"    "$(caught 'Dockerfile:40 sets it')"            CAUGHT
expect "another bare filename"    "$(caught 'Makefile:12 has the rule')"         CAUGHT
expect "an all-caps bare file"    "$(caught 'LICENSE:3 states it')"              CAUGHT
expect "a leading-dot path"       "$(caught 'see .env:12 for it')"               CAUGHT

# Formerly declined, now caught, because the prose they collided with was
# rewritten and the fences are out of scope.
expect "a lowercase bare filename" "$(caught 'makefile:12 has the rule')"        CAUGHT
expect "a one-letter filename"     "$(caught 'R:12 states it')"                  CAUGHT
expect "a + in the filename"       "$(caught 'foo+bar:12 says so')"              CAUGHT

# The forms the procedure genuinely uses and must keep writable.
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
expect "an ISO timestamp"         "$(caught 'SINCE=2026-08-24T07:59:33Z')"       MISSED

summary "procedure-refs"
