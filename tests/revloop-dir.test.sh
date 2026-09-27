#!/usr/bin/env bash
# Measures the one property `.revloop/.gitignore` is written for.
#
# revloop writes its field notes and the grading input into the checkout it runs
# against, where this repository's .gitignore has no reach. Rule 2 of the Field
# notes paragraph in procedures/remote-loop.md has the procedure write
# `.revloop/.gitignore` before either, and this file takes that file's lines OUT
# of the procedure rather than restating them -- so what is measured is what the
# procedure tells a run to write, and an edit there is measured here next run.
#
# WHAT IS PINNED IS GIT'S SIDE OF THE CONTRACT, on whatever git CI carries. The
# two reads are the ones the procedures act on: `git status --porcelain -uall` is
# what step 4 stages from and what the local loop's clean-tree check reads, and
# `git ls-files -o --exclude-standard` is step 3's untracked-file read.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "revloop-dir:"

same() { # same <label> <actual> <expected> -- exact, unlike lib.sh's expect
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$3" "$2"
  fi
}

SRC="$ROOT/procedures/remote-loop.md"

# The text block after the marker, with the list indent of its opening fence
# removed -- the same shape extract-fences.sh reads for a shell fence.
BODY=$(awk '
  index($0, "<!-- revloop:file id=revloop-gitignore -->") { armed = 1; next }
  armed && !opened {
    line = $0
    sub(/^[ \t]*/, "", line)
    if (line == "```text") {
      match($0, /^[ \t]*/)
      indent = RLENGTH
      opened = 1
    }
    next
  }
  opened {
    line = $0
    sub(/^[ \t]*/, "", line)
    if (line == "```") { exit }
    print substr($0, indent + 1)
  }
' "$SRC")

# An extraction that found nothing would write an empty .gitignore, and every
# assertion below would then fail for the wrong reason -- or, on a later edit,
# pass over a block that no longer says what it did.
same "the procedure's block has one bare * line" "$(printf '%s\n' "$BODY" | grep -cx '\*')" "1"

# Both write sites send the reader to the rule. A write site that stops citing it
# is a run that writes a note without writing the ignore file first.
for f in "$ROOT/procedures/severity-grading.md" "$ROOT/procedures/local-loop.md"; do
  same "$(basename "$f") cites .revloop/.gitignore" "$(grep -q '\.revloop/\.gitignore' "$f" && echo yes)" "yes"
done

# `pwd -P` for the reason fence-worktree.test.sh gives: git resolves symlinks.
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

new_repo() { # new_repo <name> -> path
  d="$TMP/$1"
  git init -q "$d"
  git -C "$d" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  printf '%s' "$d"
}

populate() { # populate <checkout> -- the two files a run writes
  mkdir -p "$1/.revloop"
  printf 'note\n' > "$1/.revloop/field-notes.md"
  # A trailing space: what step 3's whitespace check fails on when it can see it.
  printf 'finding  \n' > "$1/.revloop/grading-input.txt"
}

R=$(new_repo plain)
populate "$R"

# --- the finding this file answers -------------------------------------------
# Without the file both reads return both paths. If they ever came back empty
# here, every "returns nothing" below would be measuring nothing.
expect "without it, status -uall lists the notes"       "$(git -C "$R" status --porcelain -uall)"          "?? .revloop/field-notes.md"
expect "without it, ls-files -o lists the grading input" "$(git -C "$R" ls-files -o --exclude-standard)" ".revloop/grading-input.txt"

# --- with the procedure's lines in place ---------------------------------------
printf '%s\n' "$BODY" > "$R/.revloop/.gitignore"

same "status -uall returns nothing"               "$(git -C "$R" status --porcelain -uall)"          ""
same "status without -uall returns nothing"       "$(git -C "$R" status --porcelain)"                ""
same "ls-files -o returns nothing"                "$(git -C "$R" ls-files -o --exclude-standard)" ""
git -C "$R" add -A
same "add -A stages nothing"                      "$(git -C "$R" diff --cached --name-only)"         ""
git -C "$R" add .revloop/field-notes.md 2>/dev/null; rc=$?
same "an explicit add of a note is refused"       "$rc"                                               "1"
same "and stages nothing either"                  "$(git -C "$R" diff --cached --name-only)"         ""
same "the rule that hides the notes is this file" \
  "$(git -C "$R" check-ignore -v .revloop/field-notes.md | cut -f1 | sed 's/:[0-9]*:/:N:/')" \
  ".revloop/.gitignore:N:*"

# --- a linked worktree reads the same per-directory file -------------------------
git -C "$R" worktree add -q --detach "$TMP/linked" HEAD
populate "$TMP/linked"
printf '%s\n' "$BODY" > "$TMP/linked/.revloop/.gitignore"
same "in a linked worktree, status -uall returns nothing" "$(git -C "$TMP/linked" status --porcelain -uall)"          ""
same "in a linked worktree, ls-files -o returns nothing"  "$(git -C "$TMP/linked" ls-files -o --exclude-standard)" ""

summary "revloop-dir"
