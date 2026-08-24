#!/usr/bin/env bash
# The granular permission list in docs/permissions.md is a copy of a fact that
# lives in the procedure: which git subcommands it actually runs. Copies drift,
# and this one did — it was missing `switch` (step 2), `fetch` (step 9's
# recovery row) and `ls-files` (step 3) when a review of this repository looked.
#
# An earlier round declined to test it, on the grounds that a grep for
# `git <word>` over the procedure cannot tell a command from prose: the file
# says "makes git set the upstream" and names `git show HEAD` twice in order to
# forbid it. That reason was wrong, and the fix is to grep a narrower thing.
# Runnable commands live in ```bash blocks; prose does not. Extracting from the
# blocks alone yields no `set` and no `show`, so no exclusion list is needed and
# there is nothing to drift.
#
# WHAT THIS DOES NOT COVER, stated rather than left to be discovered: commands
# the procedure gives in prose instead of a block. `git add` and `git commit`
# live in step 4's paragraph, `git fetch` in step 9's decision table. They are
# granted, and nothing here would notice if they stopped being. Catching those
# needs the ambiguity this test exists to avoid, so the direction is one-way on
# purpose — every command in a block must be granted, and the list may hold
# entries no block uses.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "permissions"

PROC="$ROOT/commands/review-loop.md"
DOC="$ROOT/docs/permissions.md"

# Subcommands the procedure runs, taken from fenced bash blocks only.
USED=$(awk '/^ *```bash$/{inb=1;next} /^ *```$/{inb=0} inb' "$PROC" \
  | grep -oE '\bgit [a-z][a-z-]*' | sed 's/^git //' | sort -u)
# Subcommands docs/permissions.md grants individually.
GRANTED=$(grep -oE 'Bash\(git [a-z][a-z-]*' "$DOC" | sed 's/^Bash(git //' | sort -u)

# Both lists must be non-empty. A broken extraction yields nothing, `comm` then
# finds nothing missing, and the subset check goes green on no data — the
# "no bad marks is not good" hole the procedure warns about. The counts
# themselves are not pinned: they change whenever a step legitimately does.
nz() { if [ "$1" -gt 0 ]; then echo NONEMPTY; else echo EMPTY; fi; }
expect "the procedure's blocks do run git" "$(nz "$(printf '%s\n' "$USED" | grep -c .)")" NONEMPTY
expect "the doc grants a git list"         "$(nz "$(printf '%s\n' "$GRANTED" | grep -c .)")" NONEMPTY

# comm needs sorted input; both are. -23 leaves lines only in the first file.
MISSING=$(comm -23 <(printf '%s\n' "$USED") <(printf '%s\n' "$GRANTED") | sed 's/^/UNGRANTED /')
refute "every git subcommand in a bash block is granted individually" "$MISSING" "UNGRANTED "

# The prose-only commands are granted today. If one is ever dropped from the
# list this says so, which is the closest this test gets to the direction it
# cannot check mechanically.
for c in add commit fetch; do
  expect "  the prose-instructed 'git $c' is still granted" \
    "$(printf '%s\n' "$GRANTED" | grep -cx "$c")" "1"
done

summary "permissions"
