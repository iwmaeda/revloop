#!/usr/bin/env bash
# Measures what git does with `.revloop/` once the ignore file from
# procedures/remote-loop.md is in place, and the states step 1 reads
# `.revloop/config.txt` in. The ignore file's lines are taken from the procedure.
# Also reads local-loop.md, severity-grading.md and docs/configuration.md.
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

# The text block after the revloop-gitignore marker, with its list indent removed.
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

# An empty extraction would write an empty .gitignore.
same "the procedure's block has one bare * line" "$(printf '%s\n' "$BODY" | grep -cx '\*')" "1"

# Both write sites cite the rule.
for f in "$ROOT/procedures/severity-grading.md" "$ROOT/procedures/local-loop.md"; do
  same "$(basename "$f") cites .revloop/.gitignore" "$(grep -q '\.revloop/\.gitignore' "$f" && echo yes)" "yes"
done

# pwd -P because git resolves symlinks.
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
  printf 'note\n' > "$1/.revloop/field-notes.txt"
  # The trailing space is deliberate: a whitespace check flags it if git shows the file.
  printf 'finding  \n' > "$1/.revloop/grading-input.txt"
}

R=$(new_repo plain)
populate "$R"

# --- baseline: without the ignore file both reads list the files ---
expect "without it, status -uall lists the notes"       "$(git -C "$R" status --porcelain -uall)"          "?? .revloop/field-notes.txt"
expect "without it, ls-files -o lists the grading input" "$(git -C "$R" ls-files -o --exclude-standard)" ".revloop/grading-input.txt"

# --- with the procedure's lines in place ---
printf '%s\n' "$BODY" > "$R/.revloop/.gitignore"

same "status -uall returns nothing"               "$(git -C "$R" status --porcelain -uall)"          ""
same "status without -uall returns nothing"       "$(git -C "$R" status --porcelain)"                ""
same "ls-files -o returns nothing"                "$(git -C "$R" ls-files -o --exclude-standard)" ""
git -C "$R" add -A
same "add -A stages nothing"                      "$(git -C "$R" diff --cached --name-only)"         ""
git -C "$R" add .revloop/field-notes.txt 2>/dev/null; rc=$?
same "an explicit add of a note is refused"       "$rc"                                               "1"
same "and stages nothing either"                  "$(git -C "$R" diff --cached --name-only)"         ""
same "the rule that hides the notes is this file" \
  "$(git -C "$R" check-ignore -v .revloop/field-notes.txt | cut -f1 | sed 's/:[0-9]*:/:N:/')" \
  ".revloop/.gitignore:N:*"

# --- a linked worktree reads the same per-directory file ---
git -C "$R" worktree add -q --detach "$TMP/linked" HEAD
populate "$TMP/linked"
printf '%s\n' "$BODY" > "$TMP/linked/.revloop/.gitignore"
same "in a linked worktree, status -uall returns nothing" "$(git -C "$TMP/linked" status --porcelain -uall)"          ""
same "in a linked worktree, ls-files -o returns nothing"  "$(git -C "$TMP/linked" ls-files -o --exclude-standard)" ""

# --- first question: does git track anything under .revloop? ---
# `git ls-files -- .revloop` must print nothing before any write. One repository per state.
same "the procedure states the first question" \
  "$(grep -c -- 'git ls-files -- .revloop  ' "$SRC")" "1"

lf() { # lf <checkout> -> what the procedure's first question prints
  git -C "$1" ls-files -- .revloop
}
commit() { git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m "$2"; }

U=$(new_repo untracked-only); mkdir "$U/.revloop"; printf '%s\n' "$BODY" > "$U/.revloop/.gitignore"
printf 'note\n' > "$U/.revloop/field-notes.txt"
same "nothing tracked: it prints nothing" "$(lf "$U")" ""

G=$(new_repo tracked-gitignore); mkdir "$G/.revloop"; printf 'custom\n' > "$G/.revloop/.gitignore"
git -C "$G" add -f .revloop/.gitignore; commit "$G" gitignore; rm "$G/.revloop/.gitignore"
same "a tracked ignore file, deleted, still prints" "$(lf "$G")" ".revloop/.gitignore"
# An existence test alone would recreate the file here.
printf '%s\n' "$BODY" > "$G/.revloop/.gitignore"
expect "and recreating it would modify a tracked file" "$(git -C "$G" status --porcelain -uall)" " M .revloop/.gitignore"
same "while check-ignore would have said yes" \
  "$(git -C "$G" check-ignore -q -- .revloop/field-notes.txt; printf '%s' "$?")" "0"

L=$(new_repo tracked-link); mkdir "$TMP/elsewhere"; ln -s "$TMP/elsewhere" "$L/.revloop"
git -C "$L" add .revloop; commit "$L" link
same "a tracked symbolic link prints itself" "$(lf "$L")" ".revloop"

M=$(new_repo submodule)
git -C "$M" update-index --add --cacheinfo "160000,$(git -C "$M" rev-parse HEAD),.revloop"; commit "$M" gitlink
same "a submodule prints itself"             "$(lf "$M")" ".revloop"

T=$(new_repo tracked-note); mkdir "$T/.revloop"; printf '%s\n' "$BODY" > "$T/.revloop/.gitignore"
printf 'note\n' > "$T/.revloop/field-notes.txt"
git -C "$T" add -f .revloop/field-notes.txt; commit "$T" note
same "a tracked note prints itself"          "$(lf "$T")" ".revloop/field-notes.txt"
printf 'more\n' >> "$T/.revloop/field-notes.txt"
expect "and a write to it would show"        "$(git -C "$T" status --porcelain -uall)" " M .revloop/field-notes.txt"

# --- third question: `git check-ignore -q` before every write, write only on 0 ---
# Each state asserts the exit code and what `git status` shows after the write.
same "the procedure states the check it runs" \
  "$(grep -c -- 'git check-ignore -q -- .revloop/field-notes.txt' "$SRC")" "1"

ci() { # ci <checkout> <path> -> exit code of the procedure's check
  git -C "$1" check-ignore -q -- "$2"; printf '%s' "$?"
}

C=$(new_repo created);   mkdir "$C/.revloop"; printf '%s\n' "$BODY" > "$C/.revloop/.gitignore"
E=$(new_repo empty);     mkdir "$E/.revloop"; : > "$E/.revloop/.gitignore"
N=$(new_repo negation);  mkdir "$N/.revloop"; printf '*\n!field-notes.txt\n' > "$N/.revloop/.gitignore"
D=$(new_repo directory); mkdir -p "$D/.revloop/.gitignore"
X=$(new_repo exclude);   mkdir "$X/.revloop"; printf '.revloop/\n' >> "$X/.git/info/exclude"

same "created with the procedure's lines: 0"      "$(ci "$C" .revloop/field-notes.txt)"    "0"
same "an empty file hides nothing: 1"             "$(ci "$E" .revloop/field-notes.txt)"    "1"
same "a negation un-hides the note: 1"            "$(ci "$N" .revloop/field-notes.txt)"    "1"
same "and still hides the grading input: 0"       "$(ci "$N" .revloop/grading-input.txt)" "0"
same "a directory in its place hides nothing: 1"  "$(ci "$D" .revloop/field-notes.txt)"    "1"
same "info/exclude answers for itself: 0"         "$(ci "$X" .revloop/field-notes.txt)"    "0"

# Where the answer is 1, a write shows in status.
printf 'note\n' > "$E/.revloop/field-notes.txt"
expect "a write the empty file allowed would show"    "$(git -C "$E" status --porcelain -uall)" "?? .revloop/field-notes.txt"
printf 'note\n' > "$N/.revloop/field-notes.txt"
expect "a write the negation allowed would show"      "$(git -C "$N" status --porcelain -uall)" "?? .revloop/field-notes.txt"
# Where it is 0, a write shows nowhere.
printf 'note\n' > "$C/.revloop/field-notes.txt"
same "a write the created file allowed shows nowhere" "$(git -C "$C" status --porcelain -uall)" ""
printf 'note\n' > "$X/.revloop/field-notes.txt"
same "a write info/exclude allowed shows nowhere"     "$(git -C "$X" status --porcelain -uall)" ""

# --- .revloop/config.txt, read in place of .revloop.json ---
# It is read only if git tracks or ignores it; otherwise config-not-ignored
# aborts. An untracked .revloop.json is still read. One repository per state.
same "the procedure asks git about the local config" \
  "$(grep -qF -- 'git check-ignore -q -- .revloop/config.txt' "$SRC" && echo yes)" "yes"
same "the procedure asks git about the shared config" \
  "$(grep -qF -- 'git check-ignore -q -- .revloop.json' "$SRC" && echo yes)" "yes"
same "the procedure asks whether the shared config is tracked" \
  "$(grep -qF -- 'git ls-files -- .revloop.json' "$SRC" && echo yes)" "yes"

# remote-loop.md states the rule; the local loop and the configuration page name it.
for f in "$SRC" "$ROOT/procedures/local-loop.md" "$ROOT/docs/configuration.md"; do
  same "$(basename "$f") names .revloop/config.txt and config-not-ignored" \
    "$(grep -qF '.revloop/config.txt' "$f" && grep -qF 'config-not-ignored' "$f" && echo yes)" "yes"
done

# A local config written before any run is visible until the ignore file exists.
K=$(new_repo local-config); mkdir "$K/.revloop"; printf '{"version":1}\n' > "$K/.revloop/config.txt"
expect "before it, status -uall lists the local config" "$(git -C "$K" status --porcelain -uall)" "?? .revloop/config.txt"
same "and check-ignore says not ignored: 1"             "$(ci "$K" .revloop/config.txt)"          "1"
printf '%s\n' "$BODY" > "$K/.revloop/.gitignore"
same "after it, status -uall returns nothing"           "$(git -C "$K" status --porcelain -uall)"  ""
same "and ls-files -o returns nothing"                  "$(git -C "$K" ls-files -o --exclude-standard)" ""
same "and check-ignore says read it: 0"                 "$(ci "$K" .revloop/config.txt)"          "0"

# An ignore file that hides nothing: the abort's state.
V=$(new_repo local-config-visible); mkdir "$V/.revloop"; : > "$V/.revloop/.gitignore"
printf '{"version":1}\n' > "$V/.revloop/config.txt"
same "an empty ignore file leaves it visible: 1"        "$(ci "$V" .revloop/config.txt)"          "1"
expect "and status -uall shows it"                      "$(git -C "$V" status --porcelain -uall)"  "?? .revloop/config.txt"

# Tracked: read with no write. check-ignore does not call a tracked file ignored,
# so tracked is asked first.
Q=$(new_repo local-config-tracked); mkdir "$Q/.revloop"; printf '{"version":1}\n' > "$Q/.revloop/config.txt"
git -C "$Q" add .revloop/config.txt; commit "$Q" config
same "a tracked local config prints itself"             "$(lf "$Q")"                               ".revloop/config.txt"
same "and check-ignore does not call it ignored: 1"     "$(ci "$Q" .revloop/config.txt)"          "1"

# Behind a tracked symbolic link git refuses the question with 128.
printf '{"version":1}\n' > "$TMP/elsewhere/config.json"
same "behind a tracked link, check-ignore refuses: 128" "$(ci "$L" .revloop/config.txt 2>/dev/null)" "128"

# The shared name, untracked and not ignored: still read.
H=$(new_repo shared-untracked); printf '{"version":1}\n' > "$H/.revloop.json"
expect "an untracked .revloop.json is in status -uall"  "$(git -C "$H" status --porcelain -uall)"  "?? .revloop.json"
expect "and in ls-files -o"                             "$(git -C "$H" ls-files -o --exclude-standard)" ".revloop.json"
same "the procedure's ls-files prints nothing for it"   "$(git -C "$H" ls-files -- .revloop.json)" ""
same "and check-ignore says not ignored: 1"             "$(ci "$H" .revloop.json)"                 "1"
git -C "$H" add .revloop.json; commit "$H" shared
same "once tracked, ls-files prints it"                 "$(git -C "$H" ls-files -- .revloop.json)" ".revloop.json"

# --- the old local names, moved by step 1 ---
same "the procedure reads the old config name after the new one" \
  "$(grep -qF '.revloop/config.txt` when it exists, then' "$SRC" && echo yes)" "yes"
same "the procedure asks git about the old config name" \
  "$(grep -qF -- 'git check-ignore -q -- .revloop/config.json' "$SRC" && echo yes)" "yes"
for c in 'mv -n .revloop/config.json .revloop/config.txt' \
         'mv -n .revloop/field-notes.md .revloop/field-notes.txt' \
         'cat .revloop/field-notes.md >> .revloop/field-notes.txt && rm .revloop/field-notes.md'; do
  same "the procedure states: $c" "$(grep -qF -- "$c" "$SRC" && echo yes)" "yes"
done

MV=$(new_repo moved); mkdir "$MV/.revloop"; printf '%s\n' "$BODY" > "$MV/.revloop/.gitignore"
printf 'old\n' > "$MV/.revloop/field-notes.md"; printf '{"version":1}\n' > "$MV/.revloop/config.json"
(cd "$MV" && mv -n .revloop/config.json .revloop/config.txt && mv -n .revloop/field-notes.md .revloop/field-notes.txt)
same "a moved note keeps its lines"            "$(cat "$MV/.revloop/field-notes.txt")" "old"
same "a moved config keeps its content"        "$(cat "$MV/.revloop/config.txt")"      '{"version":1}'
same "the old names are gone"                  "$(test -e "$MV/.revloop/field-notes.md" -o -e "$MV/.revloop/config.json" && echo PRESENT)" ""
same "and git shows nothing after the move"    "$(git -C "$MV" status --porcelain -uall)" ""

BM=$(new_repo both-notes); mkdir "$BM/.revloop"; printf '%s\n' "$BODY" > "$BM/.revloop/.gitignore"
printf 'new\n' > "$BM/.revloop/field-notes.txt"; printf 'old\n' > "$BM/.revloop/field-notes.md"
(cd "$BM" && cat .revloop/field-notes.md >> .revloop/field-notes.txt && rm .revloop/field-notes.md)
same "both names: the old lines follow the new" "$(cat "$BM/.revloop/field-notes.txt")" "$(printf 'new\nold')"
same "and the old name is gone"                 "$(test -e "$BM/.revloop/field-notes.md" && echo PRESENT)" ""

# A negation can hide the old name and show the new one: the move is refused.
RF=$(new_repo move-refused); mkdir "$RF/.revloop"; printf '*\n!field-notes.txt\n' > "$RF/.revloop/.gitignore"
same "a new name git would show refuses the move: 1" "$(ci "$RF" .revloop/field-notes.txt)" "1"

# A tracked old config is the repository's: ls-files prints it, so step 1 moves nothing.
QL=$(new_repo old-config-tracked); mkdir "$QL/.revloop"; printf '{"version":1}\n' > "$QL/.revloop/config.json"
git -C "$QL" add .revloop/config.json; commit "$QL" config
same "a tracked old config prints itself" "$(lf "$QL")" ".revloop/config.json"

# --- what a project's linters reach, with no revloop rule in the project ---
PRETTIER="$ROOT/node_modules/.bin/prettier"
MARKDOWNLINT="$ROOT/node_modules/.bin/markdownlint"
if [ ! -x "$PRETTIER" ] || [ ! -x "$MARKDOWNLINT" ]; then
  echo "  note prettier or markdownlint not installed; run npm ci. Skipping the linter checks."
else
  reaches() { # reaches <checkout> <name> <command...> -> yes when the command's output names the file
    local d="$1" name="$2" out; shift 2
    # Captured first: a linter's nonzero exit would fail a pipe under pipefail.
    out=$(cd "$d" && "$@" 2>&1)
    case "$out" in *"$name"*) echo yes ;; *) echo no ;; esac
  }
  long=$(printf 'word %.0s' $(seq 1 60))

  LO=$(new_repo linters-old); mkdir "$LO/.revloop"; printf '%s\n' "$BODY" > "$LO/.revloop/.gitignore"
  printf '# Title\n' > "$LO/README.md"
  printf '%s\n%s\n' "$long" "$long" > "$LO/.revloop/field-notes.md"
  printf '{"version":1}\n' > "$LO/.revloop/config.json"
  same "control: prettier reaches the old note"     "$(reaches "$LO" field-notes.md "$PRETTIER" --check '**/*.{md,json,jsonc}')" "yes"
  same "control: prettier reaches the old config"   "$(reaches "$LO" config.json "$PRETTIER" --check '**/*.{md,json,jsonc}')"    "yes"
  same "control: markdownlint reaches the old note" "$(reaches "$LO" field-notes.md "$MARKDOWNLINT" --dot '**/*.md')"            "yes"

  LN=$(new_repo linters-new); mkdir "$LN/.revloop"; printf '%s\n' "$BODY" > "$LN/.revloop/.gitignore"
  printf '# Title\n' > "$LN/README.md"
  printf '%s\n%s\n' "$long" "$long" > "$LN/.revloop/field-notes.txt"
  printf '{"version":1}\n' > "$LN/.revloop/config.txt"
  printf 'finding  \n' > "$LN/.revloop/grading-input.txt"
  same "prettier's globs reach nothing in .revloop"  "$(reaches "$LN" .revloop "$PRETTIER" --check '**/*.{md,json,jsonc}')" "no"
  same "prettier on the directory reaches nothing"   "$(reaches "$LN" .revloop "$PRETTIER" --check .)"                      "no"
  same "markdownlint reaches nothing in .revloop"    "$(reaches "$LN" .revloop "$MARKDOWNLINT" --dot '**/*.md')"            "no"
fi

summary "revloop-dir"
