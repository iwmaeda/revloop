#!/usr/bin/env bash
# Runs the whitespace preflight from step 3 of procedures/remote-loop.md:
# `git diff --check HEAD`, then each untracked file against /dev/null. The block
# is taken from the procedure by its `revloop:check id=whitespace` marker.
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
# A case below leaves a mode-000 file, so permissions are restored before removal.
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

# An empty extraction would be a script that exits 0 everywhere.
if ! grep -q -- '--no-index' "$SCRIPT" || ! grep -q -- 'git diff --check HEAD' "$SCRIPT"; then
  echo "  FAIL could not lift the whitespace block out of the procedure"
  exit 1
fi

# A fresh repository with one clean tracked file, left in $d. It sets a variable
# because $(repo) would run in a subshell and the counter would never advance.
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

# --no-index against /dev/null exits 1 for every new file, clean or not.
repo
printf 'new and clean\n' > "$d/new.txt"
check
same "a clean untracked file passes"                 "$RC" "0"

repo
printf 'trailing blank \n' > "$d/new.txt"
check
same "an untracked file with a whitespace error is 2" "$RC" "2"
expect "  and the report names it"                   "$OUT" "new.txt:1: trailing whitespace."

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

# Three awkward file names, each holding a whitespace error.
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

# The loop is a pipeline subshell. The braces let it exit with the worst status seen.
repo
printf 'trailing blank \n' > "$d/a-first.txt"
printf 'clean\n' > "$d/z-last.txt"
check
same "an error in an earlier file survives a clean later one" "$RC" "2"

# 128 & 2 is zero, so a bit test would call an unreadable file clean.
# Root can read a mode-000 file, so these cases are skipped as root.
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
