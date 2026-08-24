#!/usr/bin/env bash
# The granular permission list in docs/permissions.md is a copy of a fact that
# lives in the procedure: which commands it actually runs. Both halves of the
# list are checked here — git subcommands, and the gh api verbs that each need
# their own rule because a rule matches a prefix and the flag precedes the path.
#
# Copies drift, and this one has, twice. It was missing `switch` (step 2),
# `fetch` (step 9's recovery row) and `ls-files` (step 3) when a review of this
# repository looked; and step 6 later gained `-X PATCH`, after `gh pr edit`
# turned out not to work at the documented floor, with no rule to match it.
#
# An earlier round declined to test it, on the grounds that a grep for
# `git <word>` over the procedure cannot tell a command from prose: the file
# says "makes git set the upstream" and names `git show HEAD` twice in order to
# forbid it. That reason was wrong, and the fix is to grep a narrower thing.
# Runnable commands live in ```bash blocks; prose does not. Extracting from the
# blocks alone yields no `set` and no `show`, so no exclusion list is needed and
# there is nothing to drift.
#
# This used to record a blind spot instead of closing it: `git add` and
# `git commit` were prescribed in step 4's paragraph and `git fetch` in step 9's
# decision table, so no block contained them and three hardcoded assertions
# named them by hand. That was a stand-in for a check. **The answer was to move
# the commands, not to widen the grep** — they are in fenced blocks now, which
# step 4 and step 9 wanted anyway, and the sets are equal, so the check runs in
# both directions.
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

# THERE ARE NO PROSE-ONLY COMMANDS LEFT, so the check runs in both directions.
# `git add`, `git commit` and `git fetch` used to be prescribed in paragraphs and
# table cells and were invisible here; the three hardcoded assertions that named
# them were a stand-in for a check, not a check. They are now written in fenced
# blocks like everything else, which was overdue on its own merits — step 4 told
# you to stage explicitly and never showed the command, and step 9 put its
# recovery inside a table cell.
#
# With the sets equal, an unused grant is as much a defect as an ungranted use:
# it is a permission nobody needs, and it means the list and the procedure have
# drifted. If a future step legitimately prescribes something in prose, this is
# the assertion that will complain, and the answer is to put it in a block.
GRANT_UNUSED=$(comm -13 <(printf '%s\n' "$USED") <(printf '%s\n' "$GRANTED") | sed 's/^/UNUSED /')
refute "no git rule is granted that no bash block uses" "$GRANT_UNUSED" "UNUSED "

# --- gh api, the same check on the other half of the list -------------------
#
# A rule matches a command-string prefix and the flag precedes the path, so
# `gh api -X PATCH …` needs its own rule and is not covered by the bare one.
# Step 6 gained exactly that verb after `gh pr edit` turned out not to work at
# the documented floor, and nothing would have noticed the missing rule.
#
# THIS CHECK REJECTS RATHER THAN FALLS BACK, and that is the whole design. Two
# earlier versions matched a *method group* and made it optional, so any line
# the group failed to recognise quietly became the bare form — which is granted.
# Each round then widened the alphabet (`-XPOST`, then `--method`, then
# lowercase) and the next spelling walked straight through: `-X  DELETE` with two
# spaces, `gh  api`, a tab, `-X 'DELETE'`. The alphabet was never the class. **An
# optional group with a granted default is fail-open by construction**, which is
# the one direction a permission check must never take.
#
# So: find every line that invokes gh api in *any* spelling, classify each
# against the canonical forms only, and treat anything unclassified as a
# failure. Widening the alphabet is no longer how a new spelling is handled —
# rewriting it canonically is.
#
# GRANTED is read from the fenced ```json block alone, not the whole document.
# The prose names `Bash(gh api *)` in order to discourage it, and a grep over the
# page would read that discouragement as a grant.
GH_GRANTED=$(awk '/^```json$/{inj=1;next} /^```$/{inj=0} inj' "$DOC" \
  | grep -oE '"Bash\(gh api (-X [A-Z]+|--paginate|graphql|repos)' | sed -E 's/^"Bash\(gh api //' | sort -u)

# canon() classifies one invocation, and exists so the rejected spellings can be
# pinned by cases — the corpus holds only canonical ones, so it can never
# witness a form that must be rejected.
canon() { # canon <text> -> form | UNCLASSIFIED
  f=$(printf '%s' "$1" | grep -oE "$GH_CANON" | head -1 | sed -E "$GH_NORM")
  printf '%s' "${f:-UNCLASSIFIED}"
}

# The text of every fenced bash block, scanned as text rather than line by line.
GH_TXT=$(awk '/^ *```bash$/{inb=1;next} /^ *```$/{inb=0} inb' "$PROC")
# THE SCOPED PATH IS PART OF THE RULE, so it is part of the pattern. Matching
# only the verb reduced `gh api -X PATCH "users/example"` to `-X PATCH`, which is
# granted — while `Bash(gh api -X PATCH repos/{owner}/{repo}/:*)` would not
# authorize that call at all. A rule is a whole prefix; comparing half of one
# answers a question nobody asked.
GH_CANON='gh api (-X [A-Z]+ |--paginate )?"repos/\{owner\}/\{repo\}/|gh api graphql '
GH_NORM='s/^gh api //; s/ ?"repos\/\{owner\}\/\{repo\}\/$//; s/ +$//; s/^$/repos/'

# THE DENOMINATOR COUNTS INVOCATIONS, NOT LINES, and that distinction is the
# whole guard. Counting lines and classifying one per line with `head -1` lets a
# second call on the same line go unseen — `gh api "repos/{owner}/{repo}/x" && gh api -X DELETE
# …` classified only the granted sibling. And a call split across a continuation
# (`gh \` then `api -X DELETE …`) matches no single-line pattern at all, so it
# was absent from the count entirely rather than counted and rejected.
gh_inline=$(printf '%s\n' "$GH_TXT" | grep -oE 'gh[[:space:]]+api' | grep -c .)
gh_split=$(printf '%s\n' "$GH_TXT" | grep -cE '\bgh[[:space:]]*\\[[:space:]]*$')
gh_total=$((gh_inline + gh_split))
gh_canon=$(printf '%s\n' "$GH_TXT" | grep -oE "$GH_CANON" | grep -c .)

nz() { if [ "$1" -gt 0 ]; then echo NONEMPTY; else echo EMPTY; fi; }
expect "the procedure's blocks do call gh api"      "$(nz "$gh_total")" NONEMPTY
expect "every gh api invocation is canonical"       "$gh_canon" "$gh_total"

# Every canonical occurrence, not one per line.
GH_USED=$(printf '%s\n' "$GH_TXT" | grep -oE "$GH_CANON" | sed -E "$GH_NORM" | sort -u)
GH_GRANTED=$(awk '/^```json$/{inj=1;next} /^```$/{inj=0} inj' "$DOC" \
  | grep -oE '"Bash\(gh api (-X [A-Z]+|--paginate|graphql|repos)' | sed -E 's/^"Bash\(gh api //' | sort -u)
expect "the doc grants a gh api list" "$(nz "$(printf '%s\n' "$GH_GRANTED" | grep -c .)")" NONEMPTY

GH_MISSING=$(comm -23 <(printf '%s\n' "$GH_USED") <(printf '%s\n' "$GH_GRANTED") | sed 's/^/UNGRANTED /')
refute "every gh api verb in a bash block has its own rule" "$GH_MISSING" "UNGRANTED "
# Pins the scoping above: the broad rule appears in the prose and must not be
# read as granted. If this ever reports it, the extraction has widened past the
# json block and the subset check has stopped meaning anything.
refute "  the prose-only Bash(gh api *) is not read as a grant" "$GH_GRANTED" "*"

# The classifier is a predicate. The corpus holds only canonical spellings, so
# it cannot witness a single one of the forms that must be rejected.
expect "canonical -X reads as itself"   "$(canon 'gh api -X POST "repos/{owner}/{repo}/x"')"        "-X POST"
expect "a quoted path reads as repos"   "$(canon 'gh api "repos/{owner}/{repo}/x"')" "repos"
expect "an off-scope path is rejected"  "$(canon 'gh api -X PATCH "users/example"')" UNCLASSIFIED
expect "another off-scope path is too"  "$(canon 'gh api "orgs/acme/repos"')"        UNCLASSIFIED
expect "graphql reads as graphql"       "$(canon 'gh api graphql -F o=x')"           "graphql"
expect "--paginate reads as itself"     "$(canon 'gh api --paginate "repos/{owner}/{repo}/x"')"     "--paginate"
expect "a joined verb is rejected"      "$(canon 'gh api -XPOST "repos/{owner}/{repo}/x"')"         UNCLASSIFIED
expect "an = separator is rejected"     "$(canon 'gh api -X=POST "repos/{owner}/{repo}/x"')"        UNCLASSIFIED
expect "a lowercase verb is rejected"   "$(canon 'gh api -X patch "repos/{owner}/{repo}/x"')"       UNCLASSIFIED
expect "--method is rejected"           "$(canon 'gh api --method PATCH "repos/{owner}/{repo}/x"')" UNCLASSIFIED
expect "--method= is rejected"          "$(canon 'gh api --method=PATCH "repos/{owner}/{repo}/x"')" UNCLASSIFIED
expect "a doubled inner space is too"   "$(canon 'gh api -X  DELETE "repos/{owner}/{repo}/x"')"     UNCLASSIFIED
expect "a doubled gh/api space is too"  "$(canon 'gh  api -X DELETE "repos/{owner}/{repo}/x"')"     UNCLASSIFIED
expect "a tab between tokens is too"    "$(canon 'gh	api -X DELETE "repos/{owner}/{repo}/x"')"      UNCLASSIFIED
expect "a quoted verb is rejected"      "$(canon "gh api -X 'DELETE' \"repos/x\"")"  UNCLASSIFIED

summary "permissions"
