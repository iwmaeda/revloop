#!/usr/bin/env bash
# The procedures and commands may cite a step by number. They may not cite a
# line number or a counted position such as "the row two below".
# Reads procedures/*.md and commands/*.md.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "procedure-refs"

# Line-number citations, matched case-insensitively. Forms caught:
#   line 9, lines 334 and 371            any digit count, singular or plural
#   line: 132, line:132, line #132       ":", "#" or "-" as the separator
#   line number 132, line no. 132, line-number 12
#   #L132, #l132                         anchors
#   remote-loop.md:132, tests/x.sh: 40   a path, ":" and a digit
#   Dockerfile:40, makefile:12, R:12, .env:12   bare and leading-dot names
# A file token starts at a token boundary, so T07:59 in a timestamp is not one.
# "line 1" is caught too. Write "the first line".
CITATION='\blines?[[:space:]:#-]+((numbers?|nos?\.?)[[:space:]:#]+)?[0-9]|(^|[^[:alnum:]])#?l[0-9]+\b|(^|[^A-Za-z0-9_.+/-])[A-Za-z._][A-Za-z0-9_.+/-]*:[[:space:]]*[0-9]'

# Neutralise the wait fence's GraphQL pagination arguments, which look like
# citations. The field name is in the match so a prose "(first:12)" is still caught.
depaginate() {
  sed -E 's/\b(comments|reviews)\((first|last|after|before):[0-9]+\)/\1(PAGINATION)/g' "$1"
}

caught() { # caught <text> -> CAUGHT | MISSED
  if printf '%s\n' "$1" | grep -qiE "$CITATION"; then echo CAUGHT; else echo MISSED; fi
}

# Every procedure and every command is scanned.
PROCS=("$ROOT"/procedures/*.md "$ROOT"/commands/*.md)
if [ ! -f "${PROCS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL procedures/*.md matched no file\n'
fi
if [ ! -f "$ROOT/commands/remote-codex-loop.md" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
fi
# Hits are prefixed with a literal the pattern cannot produce.
for proc in "${PROCS[@]}"; do
  HITS=$(depaginate "$proc" | grep -niE "$CITATION" | sed 's/^/CITATION /') || true
  refute "no citation in the forms below reaches $(basename "$proc")" "$HITS" "CITATION "
done

# Forms that must be caught.
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
expect "a lowercase l anchor"     "$(caught 'blob/main/remote-loop.md#l132')"    CAUGHT
expect "a GitHub #L anchor"       "$(caught 'blob/main/remote-loop.md#L132')"    CAUGHT
expect "the path.md:N notation"   "$(caught 'procedures/remote-loop.md:132 has it')" CAUGHT
expect "path.md, space after :"   "$(caught 'remote-loop.md: 132 has it')"       CAUGHT
expect "a non-md path cited"      "$(caught 'tests/procedure-refs.test.sh:40')"  CAUGHT
expect "a 5-letter extension"     "$(caught 'package.jsonc:12 says so')"         CAUGHT
expect "an extensionless file"    "$(caught 'Dockerfile:40 sets it')"            CAUGHT
expect "another bare filename"    "$(caught 'Makefile:12 has the rule')"         CAUGHT
expect "an all-caps bare file"    "$(caught 'LICENSE:3 states it')"              CAUGHT
expect "a leading-dot path"       "$(caught 'see .env:12 for it')"               CAUGHT

expect "a lowercase bare filename" "$(caught 'makefile:12 has the rule')"        CAUGHT
expect "a one-letter filename"     "$(caught 'R:12 states it')"                  CAUGHT
expect "a + in the filename"       "$(caught 'foo+bar:12 says so')"              CAUGHT

# Forms the procedures use, which must stay writable.
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

# --- counted positional citations ---
# Matched after unwrapping, so a citation split across a line wrap is found.
# Forms caught:
#   the row two below, the bullet three up     unit, count, direction
#   three paragraphs down, the 2 rows above    count, unit, direction
# Units are row, bullet, paragraph, item and entry. "step" is not one: steps are
# cited by number. Adjacent references such as "the row above" are not checked.
# The \b after the direction keeps "updates" from matching as "up".
POSITIONAL='(rows?|bullets?|paragraphs?|items?|entry|entries)[[:space:]]+(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)[[:space:]]+(above|below|up|down)\b|(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)[[:space:]]+(rows?|bullets?|paragraphs?|items?|entry|entries)[[:space:]]+(above|below|up|down)\b'

unwrap() { tr '\n' ' ' < "$1" | tr -s ' '; }

placed() { # placed <text> -> CAUGHT | MISSED, over the same normalisation
  if printf '%s' "$1" | tr '\n' ' ' | tr -s ' ' | grep -qiE "$POSITIONAL"; then
    echo CAUGHT
  else
    echo MISSED
  fi
}

for proc in "${PROCS[@]}"; do
  HITS=$(unwrap "$proc" | grep -oiE "$POSITIONAL" | sed 's/^/POSITIONAL /') || true
  refute "no counted positional citation in $(basename "$proc")" "$HITS" "POSITIONAL "
done

# Forms that must be caught.
expect "unit then count, below"   "$(placed 'the row two below refuses it')"     CAUGHT
expect "unit then count, up"      "$(placed 'the bullet three up says so')"      CAUGHT
expect "count then unit, down"    "$(placed 'the invariant three paragraphs down')" CAUGHT
expect "count then unit, above"   "$(placed 'once the three rows above match')"  CAUGHT
expect "a digit rather than word" "$(placed 'the row 2 below refuses it')"       CAUGHT
expect "singular unit"            "$(placed 'one entry above says otherwise')"   CAUGHT
expect "wrapped across a newline" "$(placed 'at all: the row
two below refuses that flag')"                                                   CAUGHT
expect "capitalised"              "$(placed 'The Bullet Three Up says so')"      CAUGHT

# Forms that must stay writable.
expect "a step cited by number"   "$(placed 'see step 10 and step 11')"          MISSED
expect "a step above"             "$(placed 'the guard step 6 above applies')"   MISSED
expect "step N updates"           "$(placed 'so step 6 updates the body')"       MISSED
expect "an adjacent row"          "$(placed 'the act the row above forbids')"    MISSED
# shellcheck disable=SC2016
expect "a named row"              "$(placed 'the `grade-over-ladder` row')"      MISSED
expect "abort rows, no direction" "$(placed 'once the three abort rows have')"   MISSED
expect "a count of rungs"         "$(placed 'on a ladder of two rungs or more')" MISSED
expect "a count of findings"      "$(placed 'carry at most ten findings up to')" MISSED

summary "procedure-refs"
