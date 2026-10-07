#!/usr/bin/env bash
# Checks the permission list in docs/permissions.md against the fenced bash in
# procedures/*.md and commands/*.md: git subcommands and gh api forms. Also
# checks that every binary an `allowed-tools` line grants is one that
# schema/reviewer.schema.json bans as the start of a review command.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "permissions"

# Globbed so that a file added later is covered without being named here.
PROCS=("$ROOT"/procedures/*.md)
CMDS=("$ROOT"/commands/*.md)
DOC="$ROOT/docs/permissions.md"

# An unmatched glob yields no text, which the subset checks would pass on.
if [ ! -f "${PROCS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL procedures/*.md matched no file\n'
fi
if [ ! -f "${CMDS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
fi

# Runnable commands live in ```bash blocks and prose does not, so only the
# blocks are read.
blocks() { awk '/^ *```bash$/{inb=1;next} /^ *```$/{inb=0} inb' "${PROCS[@]}" "${CMDS[@]}"; }

# `git -C <path> <sub>` puts the subcommand in the third field, so the option
# is removed first. An invocation that still names no subcommand is a failure.
normalise() { sed -E 's/(^|[^A-Za-z0-9_-])git -C ("[^"]*"|[^[:space:]]+) /\1git /g'; }

USED=$(blocks | normalise | grep -oE '\bgit [a-z][a-z-]*' | sed 's/^git //' | sort -u)
UNREADABLE=$(blocks | normalise | grep -oE '\bgit +[^ ]*' | grep -vE '^git +[a-z]' | sed 's/^/UNREADABLE /')
refute "every git invocation names a subcommand" "$UNREADABLE" "UNREADABLE "

GRANTED=$(grep -oE 'Bash\(git [a-z][a-z-]*' "$DOC" | sed 's/^Bash(git //' | sort -u)

# An empty list passes any subset check, so both must be non-empty.
nz() { if [ "$1" -gt 0 ]; then echo NONEMPTY; else echo EMPTY; fi; }
expect "the procedures' blocks do run git" "$(nz "$(printf '%s\n' "$USED" | grep -c .)")" NONEMPTY
expect "the doc grants a git list"         "$(nz "$(printf '%s\n' "$GRANTED" | grep -c .)")" NONEMPTY

MISSING=$(comm -23 <(printf '%s\n' "$USED") <(printf '%s\n' "$GRANTED") | sed 's/^/UNGRANTED /')
refute "every git subcommand in a bash block is granted individually" "$MISSING" "UNGRANTED "

# The reverse direction. A command prescribed only in prose fails here; put it
# in a fenced block.
GRANT_UNUSED=$(comm -13 <(printf '%s\n' "$USED") <(printf '%s\n' "$GRANTED") | sed 's/^/UNUSED /')
refute "no git rule is granted that no bash block uses" "$GRANT_UNUSED" "UNUSED "

# --- gh api -----------------------------------------------------------------
#
# Grants are read from the ```json block only. The prose names
# `Bash(gh api *)` to discourage it.
GH_GRANTED=$(awk '/^```json$/{inj=1;next} /^```$/{inj=0} inj' "$DOC" \
  | grep -oE '"Bash\(gh api (-X [A-Z]+|--paginate|graphql|repos)' | sed -E 's/^"Bash\(gh api //' | sort -u)

canon() { # canon <text> -> form | UNCLASSIFIED
  f=$(printf '%s' "$1" | grep -oE "$GH_CANON" | head -1 | sed -E "$GH_NORM")
  printf '%s' "${f:-UNCLASSIFIED}"
}

GH_TXT=$(blocks)
# A rule matches a command-string prefix and the flag precedes the path, so
# each verb needs its own rule and the scoped path is part of the form.
# GH_NORM reduces a match to its key in the grant list: `-X POST`,
# `--paginate`, `graphql` or `repos`.
GH_CANON='gh api (-X [A-Z]+ |--paginate )?"repos/\{owner\}/\{repo\}/|gh api graphql '
GH_NORM='s/^gh api //; s/ ?"repos\/\{owner\}\/\{repo\}\/$//; s/ +$//; s/^$/repos/'

# Every invocation is counted, including a second one on a line and one split
# after `gh \`. A spelling outside the canonical forms then fails the equality.
gh_inline=$(printf '%s\n' "$GH_TXT" | grep -oE 'gh[[:space:]]+api' | grep -c .)
gh_split=$(printf '%s\n' "$GH_TXT" | grep -cE '\bgh[[:space:]]*\\[[:space:]]*$')
gh_total=$((gh_inline + gh_split))
gh_canon=$(printf '%s\n' "$GH_TXT" | grep -oE "$GH_CANON" | grep -c .)

nz() { if [ "$1" -gt 0 ]; then echo NONEMPTY; else echo EMPTY; fi; }
expect "the procedures' blocks do call gh api"     "$(nz "$gh_total")" NONEMPTY
expect "every gh api invocation is canonical"       "$gh_canon" "$gh_total"

GH_USED=$(printf '%s\n' "$GH_TXT" | grep -oE "$GH_CANON" | sed -E "$GH_NORM" | sort -u)
GH_GRANTED=$(awk '/^```json$/{inj=1;next} /^```$/{inj=0} inj' "$DOC" \
  | grep -oE '"Bash\(gh api (-X [A-Z]+|--paginate|graphql|repos)' | sed -E 's/^"Bash\(gh api //' | sort -u)
expect "the doc grants a gh api list" "$(nz "$(printf '%s\n' "$GH_GRANTED" | grep -c .)")" NONEMPTY

GH_MISSING=$(comm -23 <(printf '%s\n' "$GH_USED") <(printf '%s\n' "$GH_GRANTED") | sed 's/^/UNGRANTED /')
refute "every gh api verb in a bash block has its own rule" "$GH_MISSING" "UNGRANTED "

GH_UNUSED=$(comm -13 <(printf '%s\n' "$GH_USED") <(printf '%s\n' "$GH_GRANTED") | sed 's/^/UNUSED /')
refute "no gh api rule is granted that no bash block uses" "$GH_UNUSED" "UNUSED "
# Guards the json-block scoping of GH_GRANTED.
refute "  the prose-only Bash(gh api *) is not read as a grant" "$GH_GRANTED" "*"

# canon() cases. The blocks hold only canonical spellings, so the rejected
# ones are pinned here.
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

# --- allowed-tools ----------------------------------------------------------
#
# Granting a binary pre-approves every command that starts with it, so each
# granted binary must be on the schema's ban list. The schema may ban more.
# Only the frontmatter is read. A command's body names rules it does not hold.
frontmatter() { # every command's YAML frontmatter, and nothing else
  for f in "${CMDS[@]}"; do
    awk 'NR==1 { if ($0 != "---") exit; next } /^---$/ { exit } { print }' "$f"
  done
}

bins() { # bins <text> -> the binary each Bash(...) rule grants, one per line
  printf '%s' "$1" | grep -oE 'Bash\([^)]*\)' \
    | sed -E 's/^Bash\(//; s/\)$//' | awk '{print $1}' | sed 's/:.*$//' | sort -u
}

GRANTED_BINS=$(bins "$(frontmatter)")
DOC_BINS=$(bins "$(awk '/^```json$/{inj=1;next} /^```$/{inj=0} inj' "$DOC")")
# A ban in the schema is a pattern of the form "^\\s*<binary>". The character
# class skips the {reviewModel} ban, which is not a binary.
BANNED_BINS=$(grep -oE '"\^\\\\s\*[A-Za-z][A-Za-z0-9_.-]*"' "$ROOT/schema/reviewer.schema.json" \
  | sed -E 's/^"\^\\\\s\*//; s/"$//' | sort -u)

expect "the frontmatter grants a binary"  "$(nz "$(printf '%s\n' "$GRANTED_BINS" | grep -c .)")" NONEMPTY
expect "the doc grants a binary"          "$(nz "$(printf '%s\n' "$DOC_BINS"     | grep -c .)")" NONEMPTY
expect "the schema bans a binary"         "$(nz "$(printf '%s\n' "$BANNED_BINS"  | grep -c .)")" NONEMPTY

UNBANNED=$(comm -23 <(printf '%s\n' "$GRANTED_BINS") <(printf '%s\n' "$BANNED_BINS") | sed 's/^/UNBANNED /')
refute "no procedure grants a binary the schema does not ban" "$UNBANNED" "UNBANNED "
DOC_UNBANNED=$(comm -23 <(printf '%s\n' "$DOC_BINS") <(printf '%s\n' "$BANNED_BINS") | sed 's/^/UNBANNED /')
refute "the doc grants no binary the schema does not ban"     "$DOC_UNBANNED" "UNBANNED "

# bins() cases.
expect "a model grant would be seen"     "$(bins 'allowed-tools: Bash(claude:*), Read')"                         claude
expect "a verify grant would be seen"    "$(bins 'allowed-tools: Bash(npm run check:all)')"                      npm
expect "a bare git rule reads as git"    "$(bins 'allowed-tools: Bash(git:*)')"                                  git
expect "a scoped gh api rule reads gh"   "$(bins 'allowed-tools: Bash(gh api -X POST repos/{owner}/{repo}/:*)')" gh
expect "a non-Bash tool is no binary"    "$(nz "$(bins 'allowed-tools: Read, Edit, Grep, Skill' | grep -c .)")"  EMPTY

summary "permissions"
