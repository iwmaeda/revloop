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

# --- gh api, the same check on the other half of the list -------------------
#
# A rule matches a command-string prefix and the flag precedes the path, so
# `gh api -X PATCH …` needs its own rule and is not covered by the bare one.
# Step 6 gained exactly that verb after `gh pr edit` turned out not to work at
# the documented floor, and nothing would have noticed the missing rule.
#
# GRANTED is read from the fenced ```json block alone, not the whole document.
# The prose names `Bash(gh api *)` in order to discourage it, and a grep over
# the page would read that discouragement as a grant — the same prose-versus-
# code distinction the git half above relies on.
# THE SPELLING OF A METHOD IS THE WHOLE PROBLEM HERE, so the pattern covers the
# way gh accepts one rather than the way this procedure happens to write it.
# `gh api --help` documents `-X, --method string`, which admits `-X POST`,
# `-XPOST`, `-X=POST`, `--method POST` and `--method=POST`, and gh takes a
# lowercase verb too. A pattern matching only `-X ` plus capitals reads every
# other spelling as the **bare** form — and the bare form is granted, so the
# check goes green beside a rule that will not match at runtime. **That is
# fail-open, the one direction a permission check must never take.**
#
# The verb is deliberately extracted as written rather than normalised. A rule
# matches a literal command-string prefix, so `Bash(gh api -X PATCH …)` does not
# cover `gh api -X patch …`; normalising would hide exactly the mismatch this
# exists to catch. Any non-canonical spelling therefore extracts as itself,
# matches no rule, and fails — which also keeps one spelling canonical.
GH_USED=$(awk '/^ *```bash$/{inb=1;next} /^ *```$/{inb=0} inb' "$PROC" \
  | grep -oE 'gh api +(--method[= ]?[A-Za-z]+|-X[= ]?[A-Za-z]+|--paginate|graphql)?' \
  | sed -E 's/^gh api +//; s/^$/repos/' | sort -u)
GH_GRANTED=$(awk '/^```json$/{inj=1;next} /^```$/{inj=0} inj' "$DOC" \
  | grep -oE '"Bash\(gh api (-X [A-Z]+|--paginate|graphql|repos)' | sed -E 's/^"Bash\(gh api //' | sort -u)

expect "the procedure's blocks do call gh api" "$(nz "$(printf '%s\n' "$GH_USED" | grep -c .)")" NONEMPTY
expect "the doc grants a gh api list"          "$(nz "$(printf '%s\n' "$GH_GRANTED" | grep -c .)")" NONEMPTY

GH_MISSING=$(comm -23 <(printf '%s\n' "$GH_USED") <(printf '%s\n' "$GH_GRANTED") | sed 's/^/UNGRANTED /')
refute "every gh api verb in a bash block has its own rule" "$GH_MISSING" "UNGRANTED "

# Pins the scoping above: the broad rule appears in the prose and must not be
# read as granted. If this ever reports it, the extraction has widened past the
# json block and the subset check has stopped meaning anything.
refute "  the prose-only Bash(gh api *) is not read as a grant" "$GH_GRANTED" "*"

# The extractor is a predicate, so the spellings it must not mis-read get their
# own cases; the procedure cannot witness a form it does not currently contain.
verb() {
  printf '%s\n' "$1" \
    | grep -oE 'gh api +(--method[= ]?[A-Za-z]+|-X[= ]?[A-Za-z]+|--paginate|graphql)?' \
    | sed -E 's/^gh api +//; s/^$/repos/'
}
expect "a separated verb reads as itself" "$(verb 'gh api -X POST "repos/x"')"        "-X POST"
expect "a joined verb does not read bare" "$(verb 'gh api -XPOST "repos/x"')"         "-XPOST"
expect "an = separator does not either"   "$(verb 'gh api -X=POST "repos/x"')"        "-X=POST"
expect "a lowercase verb does not either" "$(verb 'gh api -X patch "repos/x"')"       "-X patch"
expect "the --method long form does not"  "$(verb 'gh api --method PATCH "repos/x"')" "--method PATCH"
expect "nor --method with an ="           "$(verb 'gh api --method=PATCH "repos/x"')" "--method=PATCH"
expect "extra spaces do not read bare"    "$(verb 'gh api  -X PUT "repos/x"')"        "-X PUT"
expect "a bare call reads as the path"    "$(verb 'gh api "repos/x"')"                "repos"

# Every spelling above except the canonical one is ungranted by construction, so
# reading it as itself is what makes the subset check fail rather than pass.
for spelling in '-XPOST' '-X=POST' '-X patch' '--method PATCH' '--method=PATCH'; do
  expect "  '$spelling' is not in the granted list" \
    "$(printf '%s\n' "$GH_GRANTED" | grep -cx -- "$spelling")" "0"
done

summary "permissions"
