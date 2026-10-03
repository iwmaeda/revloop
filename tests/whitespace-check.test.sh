#!/usr/bin/env bash
# Runs the whitespace preflight step 3 of procedures/remote-loop.md tells every
# round to run before it pushes: `git diff --check HEAD` for tracked content,
# then a loop that puts each untracked file through the same check against
# /dev/null and classifies the statuses that come back.
#
# The block is not a fence -- nothing hashes it and no permission rule is keyed
# to its bytes -- but it is fixed text that takes no arguments, and the step
# spends a table and four paragraphs on why each token in it is there. Every one
# of those claims was measured once, by hand, on a throwaway repository. This
# file makes the same measurements each time the suite runs.
#
# The block is lifted OUT of the procedure by its marker,
# `<!-- revloop:check id=whitespace -->`, the way findings-read.test.sh lifts a
# read, so what runs here is what the procedure tells a round to type.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "whitespace-check:"

same() { # same <label> <actual> <expected> -- exact, unlike lib.sh's expect
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$3" "$2"
  fi
}

SRC="$ROOT/procedures/remote-loop.md"
WORK=$(mktemp -d)
# The unreadable file below is mode 000, and so would be anything left behind
# by a run that died between the chmod and the cleanup.
trap 'chmod -R u+rw "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

SCRIPT="$WORK/check.sh"
awk '
  index($0, "<!-- revloop:check id=whitespace -->") { armed = 1; next }
  armed && !opened {
    line = $0
    sub(/^[ \t]*/, "", line)
    if (line == "```bash") {
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
' "$SRC" > "$SCRIPT"

# An extraction that found nothing is an empty script, which exits 0 on every
# repository below -- a suite that passes because it ran nothing.
if ! grep -q -- '--no-index' "$SCRIPT" || ! grep -q -- 'git diff --check HEAD' "$SCRIPT"; then
  echo "  FAIL could not lift the whitespace block out of the procedure"
  exit 1
fi

# A fresh repository holding one clean tracked file, left in $d. It sets a
# variable rather than printing a path: called as $(repo) it would run in a
# subshell, the counter would never advance, and every case would share one
# repository with the case before it.
N=0; d=
repo() {
  N=$((N + 1))
  d="$WORK/r$N"
  git init -q "$d"
  printf 'tracked\n' > "$d/tracked.txt"
  git -C "$d" add tracked.txt
  git -C "$d" -c user.email=t@example.com -c user.name=t commit -q -m init
}

OUT=; RC=
check() { # check -- runs the block in $d; sets OUT and RC
  [ -d "$d/.git" ] || { echo "  FAIL no repository at $d"; exit 1; }
  OUT=$(cd "$d" && bash "$SCRIPT" 2>&1)
  RC=$?
}

repo
check
same "a clean tree passes"                           "$RC" "0"
same "  and says nothing"                            "$OUT" ""

# --no-index compares against /dev/null, so every new file is a difference and
# exits 1. A loop testing `$? -ne 0` would go red whenever one exists.
repo
printf 'new and clean\n' > "$d/new.txt"
check
same "a clean untracked file passes"                 "$RC" "0"

repo
printf 'trailing blank \n' > "$d/new.txt"
check
same "an untracked file with a whitespace error is 2" "$RC" "2"
expect "  and the report names it"                   "$OUT" "new.txt:1: trailing whitespace."

# `git diff --check` alone reaches tracked content only -- which is why the
# loop exists -- and its finding is in the output, not in the block's status.
repo
printf 'edited \n' >> "$d/tracked.txt"
check
expect "a tracked edit is reported by the first line" "$OUT" "tracked.txt:2: trailing whitespace."
same "  and does not set the loop's status"          "$RC" "0"

repo
printf 'staged \n' >> "$d/tracked.txt"
git -C "$d" add tracked.txt
check
expect "a staged edit is reported too, since the check is against HEAD" "$OUT" "tracked.txt:2: trailing whitespace."

repo
printf 'ignored.txt\n' > "$d/.gitignore"
git -C "$d" add .gitignore
git -C "$d" -c user.email=t@example.com -c user.name=t commit -q -m ignore
printf 'trailing blank \n' > "$d/ignored.txt"
check
same "an ignored file is not put through the check"  "$RC" "0"

# The three names the step measured, each holding a whitespace error. In the
# naive spelling all three were skipped: two errors about the names, no report.
repo
printf 'trailing blank \n' > "$d/  leading-space.txt"
check
same "a name beginning with blanks is still read (IFS=)" "$RC" "2"
expect "  and reported under its own name"           "$OUT" "  leading-space.txt:1: trailing whitespace."

repo
printf 'trailing blank \n' > "$d/-dashfile.txt"
check
same "a name beginning with a dash is a path, not an option (--)" "$RC" "2"
expect "  and reported"                              "$OUT" "-dashfile.txt:1: trailing whitespace."

repo
printf 'trailing blank \n' > "$d/new"$'\n'"line.txt"
check
same "a name holding a newline is one path (-z, -d '')" "$RC" "2"
expect "  and reported"                              "$OUT" "trailing whitespace."

# The braces: the loop is the last stage of a pipeline and so a subshell. A
# status kept without them would be the last file's alone.
repo
printf 'trailing blank \n' > "$d/a-first.txt"
printf 'clean\n' > "$d/z-last.txt"
check
same "an error in an earlier file survives a clean later one" "$RC" "2"

# 2 is the whitespace bit and 128 & 2 is zero, so a bit test calls a file the
# check could not read clean. Classifying the status is what keeps it red.
# Root reads a mode-000 file, so there is nothing to measure as root.
if [ "$(id -u)" -eq 0 ]; then
  echo "  note running as root; the unreadable-file cases are not exercised here."
else
  repo
  printf 'cannot be read\n' > "$d/only.txt"
  chmod 000 "$d/only.txt"
  check
  same "an unreadable file is a failure, not a pass and not a whitespace finding" "$RC" "128"

  repo
  printf 'trailing blank \n' > "$d/a-first.txt"
  printf 'cannot be read\n' > "$d/m-middle.txt"
  chmod 000 "$d/m-middle.txt"
  printf 'trailing blank \n' > "$d/z-last.txt"
  check
  same "  and it outranks a whitespace finding on either side of it" "$RC" "128"
  expect "  while the findings are still reported" "$OUT" "z-last.txt:1: trailing whitespace."
fi

summary "whitespace-check"
