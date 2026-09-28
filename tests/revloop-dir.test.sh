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
#
# The same directory holds the one file an operator writes there: a
# configuration kept out of git, `.revloop/config.json`. The last section
# measures the states step 1's **Config file** paragraph reads it in.
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

# --- the first question: does git track anything under .revloop? --------------
# The ignore file is itself a write, so the existence test cannot be the first
# thing asked: a tracked ignore file deleted from the work tree is "absent", and
# recreating it modifies a tracked file while `check-ignore` still answers 0 --
# the proxy the third question refuses, reached one write earlier. A tracked
# symbolic link or a submodule at .revloop is worse: the write lands outside
# this checkout. So the procedure asks `git ls-files -- .revloop` first and goes
# on only when it prints nothing. Each state below is its own repository.
same "the procedure states the first question" \
  "$(grep -c -- 'git ls-files -- .revloop  ' "$SRC")" "1"

lf() { # lf <checkout> -> what the procedure's first question prints
  git -C "$1" ls-files -- .revloop
}
commit() { git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m "$2"; }

U=$(new_repo untracked-only); mkdir "$U/.revloop"; printf '%s\n' "$BODY" > "$U/.revloop/.gitignore"
printf 'note\n' > "$U/.revloop/field-notes.md"
same "nothing tracked: it prints nothing" "$(lf "$U")" ""

G=$(new_repo tracked-gitignore); mkdir "$G/.revloop"; printf 'custom\n' > "$G/.revloop/.gitignore"
git -C "$G" add -f .revloop/.gitignore; commit "$G" gitignore; rm "$G/.revloop/.gitignore"
same "a tracked ignore file, deleted, still prints" "$(lf "$G")" ".revloop/.gitignore"
# What the existence test alone would have done: recreate it, modify a tracked
# file, and still get 0 from the third question.
printf '%s\n' "$BODY" > "$G/.revloop/.gitignore"
expect "and recreating it would modify a tracked file" "$(git -C "$G" status --porcelain -uall)" " M .revloop/.gitignore"
same "while check-ignore would have said yes" \
  "$(git -C "$G" check-ignore -q -- .revloop/field-notes.md; printf '%s' "$?")" "0"

L=$(new_repo tracked-link); mkdir "$TMP/elsewhere"; ln -s "$TMP/elsewhere" "$L/.revloop"
git -C "$L" add .revloop; commit "$L" link
same "a tracked symbolic link prints itself" "$(lf "$L")" ".revloop"

M=$(new_repo submodule)
git -C "$M" update-index --add --cacheinfo "160000,$(git -C "$M" rev-parse HEAD),.revloop"; commit "$M" gitlink
same "a submodule prints itself"             "$(lf "$M")" ".revloop"

T=$(new_repo tracked-note); mkdir "$T/.revloop"; printf '%s\n' "$BODY" > "$T/.revloop/.gitignore"
printf 'note\n' > "$T/.revloop/field-notes.md"
git -C "$T" add -f .revloop/field-notes.md; commit "$T" note
same "a tracked note prints itself"          "$(lf "$T")" ".revloop/field-notes.md"
printf 'more\n' >> "$T/.revloop/field-notes.md"
expect "and a write to it would show"        "$(git -C "$T" status --porcelain -uall)" " M .revloop/field-notes.md"

# --- the third question: git decides whether to write --------------------------
# An existing .revloop/.gitignore is left alone, so "the file exists" says
# nothing about what it hides. The procedure asks `git check-ignore -q` before
# every write and writes only on 0. Each state of its table is one repository
# here, and each asserts both the exit code and what `git status` would do with
# the write -- the exit code is the rule, and the status is why it is the rule.
same "the procedure states the check it runs" \
  "$(grep -c -- 'git check-ignore -q -- .revloop/field-notes.md' "$SRC")" "1"

ci() { # ci <checkout> <path> -> exit code of the procedure's check
  git -C "$1" check-ignore -q -- "$2"; printf '%s' "$?"
}

C=$(new_repo created);   mkdir "$C/.revloop"; printf '%s\n' "$BODY" > "$C/.revloop/.gitignore"
E=$(new_repo empty);     mkdir "$E/.revloop"; : > "$E/.revloop/.gitignore"
N=$(new_repo negation);  mkdir "$N/.revloop"; printf '*\n!field-notes.md\n' > "$N/.revloop/.gitignore"
D=$(new_repo directory); mkdir -p "$D/.revloop/.gitignore"
X=$(new_repo exclude);   mkdir "$X/.revloop"; printf '.revloop/\n' >> "$X/.git/info/exclude"

same "created with the procedure's lines: 0"      "$(ci "$C" .revloop/field-notes.md)"    "0"
same "an empty file hides nothing: 1"             "$(ci "$E" .revloop/field-notes.md)"    "1"
same "a negation un-hides the note: 1"            "$(ci "$N" .revloop/field-notes.md)"    "1"
same "and still hides the grading input: 0"       "$(ci "$N" .revloop/grading-input.txt)" "0"
same "a directory in its place hides nothing: 1"  "$(ci "$D" .revloop/field-notes.md)"    "1"
same "info/exclude answers for itself: 0"         "$(ci "$X" .revloop/field-notes.md)"    "0"

# Why 1 must refuse: in every state that answers 1, the write shows up.
printf 'note\n' > "$E/.revloop/field-notes.md"
expect "a write the empty file allowed would show"    "$(git -C "$E" status --porcelain -uall)" "?? .revloop/field-notes.md"
printf 'note\n' > "$N/.revloop/field-notes.md"
expect "a write the negation allowed would show"      "$(git -C "$N" status --porcelain -uall)" "?? .revloop/field-notes.md"
# And why 0 may write: the write shows nowhere.
printf 'note\n' > "$C/.revloop/field-notes.md"
same "a write the created file allowed shows nowhere" "$(git -C "$C" status --porcelain -uall)" ""
printf 'note\n' > "$X/.revloop/field-notes.md"
same "a write info/exclude allowed shows nowhere"     "$(git -C "$X" status --porcelain -uall)" ""

# --- the config file: .revloop/config.json, read in place of .revloop.json -----
# The shared .revloop.json was the only place a configuration could live, so a
# person who wanted one for themselves had to commit it, add a rule to a
# .gitignore the team shares, or leave it untracked -- where step 4 stages from
# it and the local loop's clean-tree check never passes. Step 1's **Config
# file** paragraph reads .revloop/config.json instead when it exists: it runs
# rule 2's first two questions whenever .revloop/ exists, then reads the local
# file only if git tracks it or ignores it, and aborts with config-not-ignored
# otherwise. An untracked .revloop.json git would show is still read, with a
# hint. Each state that paragraph names is one repository below.
same "the procedure asks git about the local config" \
  "$(grep -qF -- 'git check-ignore -q -- .revloop/config.json' "$SRC" && echo yes)" "yes"
same "the procedure asks git about the shared config" \
  "$(grep -qF -- 'git check-ignore -q -- .revloop.json' "$SRC" && echo yes)" "yes"
same "the procedure asks whether the shared config is tracked" \
  "$(grep -qF -- 'git ls-files -- .revloop.json' "$SRC" && echo yes)" "yes"

# The rule is stated once, in remote-loop.md; the local loop cites it and the
# configuration page documents it. A copy that stops naming the file or the
# abort is one a reader follows to a different rule.
for f in "$SRC" "$ROOT/procedures/local-loop.md" "$ROOT/docs/configuration.md"; do
  same "$(basename "$f") names .revloop/config.json and config-not-ignored" \
    "$(grep -qF '.revloop/config.json' "$f" && grep -qF 'config-not-ignored' "$f" && echo yes)" "yes"
done

# A local config the operator wrote before any run: git shows it until the
# ignore file step 1 writes is in place, and hides it from then on.
K=$(new_repo local-config); mkdir "$K/.revloop"; printf '{"version":1}\n' > "$K/.revloop/config.json"
expect "before it, status -uall lists the local config" "$(git -C "$K" status --porcelain -uall)" "?? .revloop/config.json"
same "and check-ignore says not ignored: 1"             "$(ci "$K" .revloop/config.json)"          "1"
printf '%s\n' "$BODY" > "$K/.revloop/.gitignore"
same "after it, status -uall returns nothing"           "$(git -C "$K" status --porcelain -uall)"  ""
same "and ls-files -o returns nothing"                  "$(git -C "$K" ls-files -o --exclude-standard)" ""
same "and check-ignore says read it: 0"                 "$(ci "$K" .revloop/config.json)"          "0"

# An operator's ignore file that hides nothing: the abort's state. Reading the
# file here would leave it where step 4 stages from.
V=$(new_repo local-config-visible); mkdir "$V/.revloop"; : > "$V/.revloop/.gitignore"
printf '{"version":1}\n' > "$V/.revloop/config.json"
same "an empty ignore file leaves it visible: 1"        "$(ci "$V" .revloop/config.json)"          "1"
expect "and status -uall shows it"                      "$(git -C "$V" status --porcelain -uall)"  "?? .revloop/config.json"

# Tracked: the repository's own config at the local name, read with no write.
# Tracked is asked first because check-ignore does not call a tracked file
# ignored -- asked alone, it would abort on a file nothing needs to hide.
Q=$(new_repo local-config-tracked); mkdir "$Q/.revloop"; printf '{"version":1}\n' > "$Q/.revloop/config.json"
git -C "$Q" add .revloop/config.json; commit "$Q" config
same "a tracked local config prints itself"             "$(lf "$Q")"                               ".revloop/config.json"
same "and check-ignore does not call it ignored: 1"     "$(ci "$Q" .revloop/config.json)"          "1"

# Behind a tracked symbolic link the file is not this checkout's, and git
# refuses the question rather than answering it -- which is not 0, so it aborts.
printf '{"version":1}\n' > "$TMP/elsewhere/config.json"
same "behind a tracked link, check-ignore refuses: 128" "$(ci "$L" .revloop/config.json 2>/dev/null)" "128"

# The shared name, untracked and not ignored: what an operator had before this
# file existed. It is read, and the hint names the move.
H=$(new_repo shared-untracked); printf '{"version":1}\n' > "$H/.revloop.json"
expect "an untracked .revloop.json is in status -uall"  "$(git -C "$H" status --porcelain -uall)"  "?? .revloop.json"
expect "and in ls-files -o"                             "$(git -C "$H" ls-files -o --exclude-standard)" ".revloop.json"
same "the procedure's ls-files prints nothing for it"   "$(git -C "$H" ls-files -- .revloop.json)" ""
same "and check-ignore says not ignored: 1"             "$(ci "$H" .revloop.json)"                 "1"
git -C "$H" add .revloop.json; commit "$H" shared
same "once tracked, ls-files prints it"                 "$(git -C "$H" ls-files -- .revloop.json)" ".revloop.json"

summary "revloop-dir"
