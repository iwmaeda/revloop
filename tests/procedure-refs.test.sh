#!/usr/bin/env bash
# The procedure may cite its own steps, never its own line numbers.
#
# A line number is a copy of a fact that nothing pins and that every edit above
# it invalidates. Two such citations existed and were both correct on the day
# they were written; the first edit that inserted a line above them would have
# made them silently wrong, with no test and no reader able to notice. This is
# the drift class CONTRIBUTING already forbids across files, applied within one.
#
# The pattern requires two digits so that "line 3" in prose stays writable and
# so that `.line`, `path:line`, "one line", and "the body's first line" — all of
# which the procedure uses — cannot trip it.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "procedure-refs"

HITS=$(grep -nE '\bline [0-9]{2,}' "$ROOT/commands/review-loop.md" || true)
refute "commands/review-loop.md cites no line numbers" "$HITS" "line "

summary "procedure-refs"
