#!/usr/bin/env bash
# The teardown fence removes only the worktrees this run created and leaves
# every other worktree alone. A path is swept only if it is a line in
# <git dir>/revloop/worktrees.txt and its last component begins with revloop-wt-.
# Fixtures are throwaway repositories, because the fence force-removes worktrees.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "fence-worktree:"

# Exact match. lib.sh's expect is a substring test, so `expect 0` passes on 10.
same() { # same <label> <actual> <expected>
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$3" "$2"
  fi
}

# pwd -P because git resolves symlinks in the paths the assertions compare.
# The trap restores permissions so rm -rf can enter directories a fixture locked.
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'chmod -R u+rwX "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
FENCE="$TMP/worktree-teardown.sh"
"$ROOT/tests/extract-fences.sh" worktree-teardown > "$FENCE"

# A repository with one commit, so `worktree add` has something to point at.
new_repo() { # new_repo <name> -> path
  d="$TMP/$1"
  git init -q "$d"
  git -C "$d" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  printf '%s' "$d"
}

# Paths come from git, as in the fence, so record a worktree while its directory
# exists. The newline repair before the append copies the procedure's step 3.
record() { # record <checkout> <worktree>... -- claim them in <checkout>'s ledger
  d=$(git -C "$1" rev-parse --absolute-git-dir)/revloop
  mkdir -p "$d"
  for w in "${@:2}"; do
    { [ ! -s "$d/worktrees.txt" ] || [ -z "$(tail -c1 "$d/worktrees.txt")" ] || printf '\n' >> "$d/worktrees.txt"; }
    git -C "$w" rev-parse --show-toplevel >> "$d/worktrees.txt"
  done
}

# lib.sh's run_fence is not used. It builds its own repository, and these
# fixtures need one they have populated with worktrees.
run_in() { # run_in <dir> -> the fence's output, run with <dir> as the cwd
  ( cd "$1" && bash "$FENCE" 2>&1 )
}

# For the FIFO fixture, where a regression would hang instead of failing.
run_capped() { # run_capped <dir> -> like run_in, but a hang becomes exit 124
  ( cd "$1" && timeout 10 bash "$FENCE" 2>&1 )
}

# --- the ordinary sweep -----------------------------------------------------
A=$(new_repo ordinary)
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-base" HEAD
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-gone" HEAD
git -C "$A" worktree add -q --detach "$A/wt/mine" HEAD
# The family name as a parent directory. Only the last component is matched.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-outer/inner" HEAD
# Without the trailing hyphen the name is outside the family.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt" HEAD
# Another checkout's worktree: family-named, dirty, absent from this ledger.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-theirs" HEAD
echo measuring > "$A/wt/revloop-wt-theirs/artifact.txt"
# The same, to become a stale registration below.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-theirs-gone" HEAD
# An untracked file makes plain `remove` refuse, so this exercises --force.
echo built > "$A/wt/revloop-wt-base/artifact.txt"
# wt/mine is recorded but outside the family, so it must survive.
record "$A" "$A/wt/revloop-wt-base" "$A/wt/revloop-wt-gone" "$A/wt/mine"
# Two stale registrations: one recorded, one another checkout's.
rm -rf "$A/wt/revloop-wt-gone" "$A/wt/revloop-wt-theirs-gone"

OUT_A=$( run_in "$A" ); RC_A=$?
LIST_A=$( git -C "$A" worktree list )

expect "the recorded worktree is removed"      "$OUT_A"  "WORKTREE=removed path=$A/wt/revloop-wt-base"
expect "a stale registration goes with it"     "$OUT_A"  "WORKTREE=removed path=$A/wt/revloop-wt-gone"
expect "the sweep reports success once"        "$OUT_A"  "WORKTREE=swept removed=2 other=2"
refute "an ordinary sweep reports nothing stuck" "$OUT_A" "WORKTREE=stuck"
same   "the fence exits zero"                  "$RC_A"   "0"
refute "the recorded worktree is deregistered" "$LIST_A" "revloop-wt-base"
refute "the stale registration is deregistered" "$LIST_A" "revloop-wt-gone"

expect "a recorded worktree of another name is left registered" "$LIST_A" "$A/wt/mine"
expect "and is left on disk"                   "$(test -d "$A/wt/mine" && echo PRESENT)" "PRESENT"
refute "and is not even named as another's"    "$OUT_A"  "WORKTREE=other path=$A/wt/mine"
expect "a nested path keeps its registration"  "$LIST_A" "$A/wt/revloop-wt-outer/inner"
expect "and its directory"                     "$(test -d "$A/wt/revloop-wt-outer/inner" && echo PRESENT)" "PRESENT"
expect "the bare family name is not a match"   "$LIST_A" "$A/wt/revloop-wt "
expect "and keeps its directory too"           "$(test -d "$A/wt/revloop-wt" && echo PRESENT)" "PRESENT"
refute "and is not counted as another's"       "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt "

expect "an unrecorded worktree is named"       "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt-theirs"
expect "and left registered"                   "$LIST_A" "$A/wt/revloop-wt-theirs"
expect "and left on disk, dirty"               "$(test -f "$A/wt/revloop-wt-theirs/artifact.txt" && echo PRESENT)" "PRESENT"
expect "its stale registration is named too"   "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt-theirs-gone"
expect "and survives, which no prune would allow" "$LIST_A" "$A/wt/revloop-wt-theirs-gone"
expect "the repository's own checkout survives" "$(test -d "$A/.git" && echo PRESENT)" "PRESENT"
# The record is emptied but kept; the inside-worktree guard tests for the file.
LEDGER_A="$(git -C "$A" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
same   "the sweep leaves only the stuck set"   "$(cat "$LEDGER_A")" ""
expect "and the record is still there to read" "$(test -f "$LEDGER_A" && echo PRESENT)" "PRESENT"
# Exact match, to pin the terminal line's field order and its end.
same   "the terminal line reads exactly this"  "$(printf '%s\n' "$OUT_A" | tail -1)" "WORKTREE=swept removed=2 other=2 ledger=ok"

# --- a removal that fails ---------------------------------------------------
B=$(new_repo stuck)
git -C "$B" worktree add -q --detach "$B/wt/revloop-wt-locked" HEAD
git -C "$B" worktree add -q --detach "$B/wt/keep" HEAD
record "$B" "$B/wt/revloop-wt-locked"
git -C "$B" worktree lock "$B/wt/revloop-wt-locked"

OUT_B=$( run_in "$B" ); RC_B=$?
LIST_B=$( git -C "$B" worktree list )

expect "a refused removal is named"            "$OUT_B"  "WORKTREE=stuck path=$B/wt/revloop-wt-locked"
expect "and the verdict says so"               "$OUT_B"  "WORKTREE=partial removed=0 stuck=1 other=0"
# A failure verdict must not contain the success token; callers grep for it.
refute "a failed sweep never claims success"   "$OUT_B"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_B"   "0"
expect "the stuck worktree is still there"     "$LIST_B" "revloop-wt-locked"
expect "and the bystander is untouched"        "$LIST_B" "$B/wt/keep"

LEDGER_B="$(git -C "$B" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
same   "a stuck worktree keeps its ledger line" "$(cat "$LEDGER_B")" "$B/wt/revloop-wt-locked"
expect "and the rewrite is still reported ok"   "$OUT_B"  "ledger=ok"
OUT_B2=$( run_in "$B" )
expect "so a second sweep still finds it"       "$OUT_B2" "WORKTREE=stuck path=$B/wt/revloop-wt-locked"

# --- a removal that deregisters before it fails -----------------------------
# An unwritable subdirectory: git deregisters the worktree, then fails to delete
# it. Only the ledger still names the path, so the second sweep is the real check.
DR=$(new_repo deregistered-live)
git -C "$DR" worktree add -q --detach "$DR/wt/revloop-wt-dr" HEAD
record "$DR" "$DR/wt/revloop-wt-dr"
mkdir -p "$DR/wt/revloop-wt-dr/build" && : > "$DR/wt/revloop-wt-dr/build/out.o"
LEDGER_DR="$(git -C "$DR" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
if [ "$(id -u)" = 0 ]; then
  printf '  note an unwritable directory does not stop root; the deregistering failure is unmeasured here\n'
else
  chmod a-w "$DR/wt/revloop-wt-dr/build"
  OUT_DR=$( run_in "$DR" ); RC_DR=$?
  LIST_DR=$( git -C "$DR" worktree list )

  expect "a removal that cannot finish is named" "$OUT_DR" "WORKTREE=stuck path=$DR/wt/revloop-wt-dr"
  expect "and the verdict says so"            "$OUT_DR"  "WORKTREE=partial removed=0 stuck=1 other=0"
  refute "a failed sweep never claims success" "$OUT_DR" "WORKTREE=swept"
  same   "and still exits zero"               "$RC_DR"   "0"
  expect "the worktree is still on disk"      "$(test -d "$DR/wt/revloop-wt-dr" && echo PRESENT)" "PRESENT"
  refute "and git has already forgotten it"   "$LIST_DR" "revloop-wt-dr"
  same   "and it keeps its ledger line"       "$(cat "$LEDGER_DR")" "$DR/wt/revloop-wt-dr"

  OUT_DR2=$( run_in "$DR" )
  expect "a later sweep still finds it"       "$OUT_DR2" "WORKTREE=stuck path=$DR/wt/revloop-wt-dr"
  expect "and still reports partial"          "$OUT_DR2" "WORKTREE=partial removed=0 stuck=1 other=0"
  refute "and never claims a clean sweep"     "$OUT_DR2" "WORKTREE=swept"
  same   "the record still holds the path"    "$(cat "$LEDGER_DR")" "$DR/wt/revloop-wt-dr"
  expect "and the directory is still there"   "$(test -d "$DR/wt/revloop-wt-dr" && echo PRESENT)" "PRESENT"
  chmod u+w "$DR/wt/revloop-wt-dr/build"
fi

# --- a recorded path that is gone from both ---------------------------------
# A recorded path absent from the list and from disk is retired silently.
DG=$(new_repo deregistered-gone)
git -C "$DG" worktree add -q --detach "$DG/wt/revloop-wt-dg" HEAD
record "$DG" "$DG/wt/revloop-wt-dg"
LEDGER_DG="$(git -C "$DG" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
# A hand-added line outside the family, for a directory that was never a worktree.
mkdir -p "$DG/wt/mine-dg"
printf '%s\n' "$DG/wt/mine-dg" >> "$LEDGER_DG"

rm -rf "$DG/wt/revloop-wt-dg"
git -C "$DG" worktree prune

OUT_DG=$( run_in "$DG" )

expect "a spent path is retired in silence"  "$OUT_DG" "WORKTREE=swept removed=0 other=0 ledger=ok"
refute "and is not reported as stuck"        "$OUT_DG" "WORKTREE=stuck"
refute "nor as another checkout's"           "$OUT_DG" "WORKTREE=other"
refute "an out-of-family line is not named"  "$OUT_DG" "$DG/wt/mine-dg"
expect "and its directory is untouched"      "$(test -d "$DG/wt/mine-dg" && echo PRESENT)" "PRESENT"
same   "and both lines leave the record"     "$(cat "$LEDGER_DG")" ""

# --- the fence owns nothing, and touches nothing ----------------------------
# Another checkout's stale registration must survive a run that owns nothing.
# A `git worktree prune` in the fence would remove it.
C=$(new_repo bystander-stale)
git -C "$C" worktree add -q --detach "$C/wt/theirs" HEAD
rm -rf "$C/wt/theirs"

OUT_C=$( run_in "$C" )
LIST_C=$( git -C "$C" worktree list )

expect "a run that owns nothing says so"       "$OUT_C"  "WORKTREE=swept removed=0 other=0"
expect "and leaves a stale registration alone" "$LIST_C" "$C/wt/theirs"

# --- the two guards ---------------------------------------------------------
mkdir -p "$TMP/notrepo"
OUT_D=$( run_in "$TMP/notrepo" ); RC_D=$?
expect "outside a repository the fence says so" "$OUT_D" "WORKTREE=error reason=not-a-repo"
refute "and never claims a sweep"              "$OUT_D"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_D"   "0"

# In a bare repository `worktree list` succeeds and only `--show-toplevel` fails.
# The other two not-a-repo guards have no fixture that isolates them.
git init -q --bare "$TMP/bare.git"
OUT_D2=$( run_in "$TMP/bare.git" ); RC_D2=$?
expect "a repository with no work tree says so" "$OUT_D2" "WORKTREE=error reason=not-a-repo"
refute "and never claims a sweep"              "$OUT_D2" "WORKTREE=swept"
same   "and still exits zero"                  "$RC_D2"  "0"

# From inside a measurement worktree the fence would read the wrong ledger, so
# it refuses the whole sweep.
E=$(new_repo cwd)
git -C "$E" worktree add -q --detach "$E/wt/revloop-wt-self" HEAD
git -C "$E" worktree add -q --detach "$E/wt/revloop-wt-sibling" HEAD
record "$E" "$E/wt/revloop-wt-self" "$E/wt/revloop-wt-sibling"

OUT_E=$( run_in "$E/wt/revloop-wt-self" ); RC_E=$?
expect "the fence refuses to sweep from inside one" "$OUT_E" "WORKTREE=error reason=inside-worktree path=$E/wt/revloop-wt-self"
refute "and never claims a sweep"              "$OUT_E"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_E"   "0"
expect "its own directory is still there"      "$(test -d "$E/wt/revloop-wt-self" && echo PRESENT)" "PRESENT"
# The refusal covers the recorded sibling too.
expect "and so is the sibling it did not sweep" "$(test -d "$E/wt/revloop-wt-sibling" && echo PRESENT)" "PRESENT"

# --- two checkouts of one repository ----------------------------------------
# Both checkouts list both worktrees. Each has a ledger in its own git dir.
F=$(new_repo two-checkouts)
git -C "$F" worktree add -q --detach "$F/second" HEAD
git -C "$F" worktree add -q --detach "$F/wt/revloop-wt-first" HEAD
git -C "$F" worktree add -q --detach "$F/wt/revloop-wt-second" HEAD
echo measuring > "$F/wt/revloop-wt-second/artifact.txt"
record "$F" "$F/wt/revloop-wt-first"
record "$F/second" "$F/wt/revloop-wt-second"

OUT_F1=$( run_in "$F" )
expect "the first checkout sweeps its own"     "$OUT_F1" "WORKTREE=removed path=$F/wt/revloop-wt-first"
expect "and names the other checkout's"        "$OUT_F1" "WORKTREE=other path=$F/wt/revloop-wt-second"
expect "and says so once"                      "$OUT_F1" "WORKTREE=swept removed=1 other=1"
expect "the other checkout keeps its directory" "$(test -f "$F/wt/revloop-wt-second/artifact.txt" && echo PRESENT)" "PRESENT"
expect "and its registration"                  "$(git -C "$F" worktree list)" "$F/wt/revloop-wt-second"
expect "and the checkout itself is untouched"  "$(test -d "$F/second" && echo PRESENT)" "PRESENT"

OUT_F2=$( run_in "$F/second" )
expect "the second checkout then sweeps its own" "$OUT_F2" "WORKTREE=removed path=$F/wt/revloop-wt-second"
expect "with nothing left to name"             "$OUT_F2" "WORKTREE=swept removed=1 other=0"

# --- no ledger, family name: the fail-open direction ------------------------
G=$(new_repo unrecorded)
git -C "$G" worktree add -q --detach "$G/wt/revloop-wt-orphan" HEAD

OUT_G=$( run_in "$G" )
expect "an unrecorded worktree is only named"  "$OUT_G"  "WORKTREE=other path=$G/wt/revloop-wt-orphan"
expect "and the sweep removes nothing"         "$OUT_G"  "WORKTREE=swept removed=0 other=1"
expect "and it is still on disk"               "$(test -d "$G/wt/revloop-wt-orphan" && echo PRESENT)" "PRESENT"
# The fence must not create a ledger; the inside-worktree guard tests for one.
same "a sweep with no ledger creates none"     "$(test -e "$(git -C "$G" rev-parse --absolute-git-dir)/revloop/worktrees.txt" && echo PRESENT)" ""

# --- the ledger is not a file in the tree -----------------------------------
# The ledger is under the git dir so it never appears as an untracked file.
# This worktree sits outside the checkout; one inside would itself be untracked.
H=$(new_repo clean-tree)
git -C "$H" worktree add -q --detach "$TMP/h-scratch/revloop-wt-x" HEAD
record "$H" "$TMP/h-scratch/revloop-wt-x"

same "recording a worktree leaves the tree clean" "$(git -C "$H" status --porcelain -uall)" ""
same "and leaves nothing for the secret scan"     "$(git -C "$H" ls-files -o --exclude-standard)" ""

git -C "$H" add -A
same "and cannot be staged at all"             "$(git -C "$H" diff --cached --name-only)" ""

OUT_H=$( run_in "$H" )
expect "the hidden ledger is still the fence's" "$OUT_H" "WORKTREE=removed path=$TMP/h-scratch/revloop-wt-x"
expect "and the sweep says so"                  "$OUT_H" "WORKTREE=swept removed=1 other=0"

same "the rewrite leaves the tree clean too"    "$(git -C "$H" status --porcelain -uall)" ""
same "and leaves nothing for the secret scan"   "$(git -C "$H" ls-files -o --exclude-standard)" ""

# --- a path is authorized once, not forever ---------------------------------
# A swept line is retired, so a later worktree at the same path is not this run's.
I=$(new_repo reuse)
git -C "$I" worktree add -q --detach "$I/wt/revloop-wt-r1" HEAD
record "$I" "$I/wt/revloop-wt-r1"
LEDGER_I="$(git -C "$I" rev-parse --absolute-git-dir)/revloop/worktrees.txt"

OUT_I1=$( run_in "$I" )
expect "the first sweep removes what it owns" "$OUT_I1" "WORKTREE=removed path=$I/wt/revloop-wt-r1"
expect "and says the record was rewritten"    "$OUT_I1" "ledger=ok"
same   "the consumed line is retired"         "$(cat "$LEDGER_I")" ""

git -C "$I" worktree add -q --detach "$I/wt/revloop-wt-r1" HEAD
echo measuring > "$I/wt/revloop-wt-r1/artifact.txt"

OUT_I2=$( run_in "$I" )
refute "the second sweep removes nothing"     "$OUT_I2" "WORKTREE=removed"
expect "and names it as another's instead"    "$OUT_I2" "WORKTREE=other path=$I/wt/revloop-wt-r1"
expect "it keeps its untracked file"          "$(test -f "$I/wt/revloop-wt-r1/artifact.txt" && echo PRESENT)" "PRESENT"
expect "and its registration"                 "$(git -C "$I" worktree list)" "$I/wt/revloop-wt-r1"
expect "and the run owns nothing"             "$OUT_I2" "WORKTREE=swept removed=0 other=1 ledger=ok"

# --- a record outlives its worktree without outliving its authority ---------
# Removed by hand, so the loop over `worktree list` never reaches the line.
# The rewrite must still retire it.
J=$(new_repo hand-removed)
git -C "$J" worktree add -q --detach "$J/wt/revloop-wt-h" HEAD
record "$J" "$J/wt/revloop-wt-h"
LEDGER_J="$(git -C "$J" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
git -C "$J" worktree remove "$J/wt/revloop-wt-h"

OUT_J1=$( run_in "$J" )
expect "a sweep with nothing to do still rewrites" "$OUT_J1" "WORKTREE=swept removed=0 other=0 ledger=ok"
same   "and the dead line goes with it"            "$(cat "$LEDGER_J")" ""
git -C "$J" worktree add -q --detach "$J/wt/revloop-wt-h" HEAD

OUT_J2=$( run_in "$J" )
expect "so a later worktree there is another's"    "$OUT_J2" "WORKTREE=other path=$J/wt/revloop-wt-h"
refute "and is not removed"                        "$OUT_J2" "WORKTREE=removed"
expect "and is still on disk"                      "$(test -d "$J/wt/revloop-wt-h" && echo PRESENT)" "PRESENT"

# --- the record cannot be written -------------------------------------------
# The ledger directory is made read-only; rename needs write on the parent, so
# a read-only file would not block the rewrite. Nothing may be removed.
K=$(new_repo readonly-ledger)
git -C "$K" worktree add -q --detach "$K/wt/revloop-wt-w" HEAD
record "$K" "$K/wt/revloop-wt-w"
LEDGER_K_DIR="$(git -C "$K" rev-parse --absolute-git-dir)/revloop"
if [ "$(id -u)" = 0 ]; then
  printf '  note a read-only directory does not stop root; ledger=error unmeasured here\n'
else
  chmod a-w "$LEDGER_K_DIR"
  OUT_K=$( run_in "$K" ); RC_K=$?
  chmod u+w "$LEDGER_K_DIR"
  expect "an unwritable record refuses the sweep" "$OUT_K" "WORKTREE=error reason=ledger-unwritable path=$LEDGER_K_DIR/worktrees.txt"
  refute "and removes nothing"                "$OUT_K" "WORKTREE=removed"
  refute "and never claims a clean sweep"     "$OUT_K" "WORKTREE=swept"
  refute "nor a partial one"                  "$OUT_K" "WORKTREE=partial"
  expect "the worktree is still on disk"      "$(test -d "$K/wt/revloop-wt-w" && echo PRESENT)" "PRESENT"
  same   "and still exits zero"               "$RC_K"  "0"
  same   "the record is left exactly as it was" "$(cat "$LEDGER_K_DIR/worktrees.txt")" "$K/wt/revloop-wt-w"
fi

# --- the record cannot be read ----------------------------------------------
# A failed read must refuse the sweep instead of counting as an empty record.
N=$(new_repo unreadable-ledger)
git -C "$N" worktree add -q --detach "$N/wt/revloop-wt-u" HEAD
echo built > "$N/wt/revloop-wt-u/artifact.txt"
record "$N" "$N/wt/revloop-wt-u"
LEDGER_N_DIR="$(git -C "$N" rev-parse --absolute-git-dir)/revloop"
LEDGER_N="$LEDGER_N_DIR/worktrees.txt"
if [ "$(id -u)" = 0 ]; then
  printf '  note a mode of 000 does not stop root; ledger-unreadable unmeasured here\n'
else
  # Case 1: the file is unreadable.
  chmod a-r "$LEDGER_N"
  OUT_N1=$( run_in "$N" ); RC_N1=$?
  chmod u+r "$LEDGER_N"
  expect "an unreadable record refuses the sweep" "$OUT_N1" "WORKTREE=error reason=ledger-unreadable path=$LEDGER_N"
  refute "and never claims a clean one"           "$OUT_N1" "WORKTREE=swept"
  refute "nor a partial one"                      "$OUT_N1" "WORKTREE=partial"
  refute "and removes nothing"                    "$OUT_N1" "WORKTREE=removed"
  refute "and calls nothing another's"            "$OUT_N1" "WORKTREE=other"
  same   "and still exits zero"                   "$RC_N1"  "0"
  expect "the worktree keeps its directory"       "$(test -d "$N/wt/revloop-wt-u" && echo PRESENT)" "PRESENT"
  expect "and its untracked file"                 "$(cat "$N/wt/revloop-wt-u/artifact.txt")" "built"
  expect "and its registration"                   "$(git -C "$N" worktree list)" "$N/wt/revloop-wt-u"
  same   "and the record is untouched"            "$(cat "$LEDGER_N")" "$N/wt/revloop-wt-u"

  # Case 2: the directory is unsearchable, which makes `[ -e ]` on the file false.
  chmod a-rx "$LEDGER_N_DIR"
  OUT_N2=$( run_in "$N" ); RC_N2=$?
  chmod u+rx "$LEDGER_N_DIR"
  expect "an unsearchable ledger directory too" "$OUT_N2" "WORKTREE=error reason=ledger-unreadable path=$LEDGER_N"
  refute "with no clean sweep claimed"          "$OUT_N2" "WORKTREE=swept"
  refute "and nothing removed"                  "$OUT_N2" "WORKTREE=removed"
  same   "and still exiting zero"               "$RC_N2"  "0"
  expect "the worktree still on disk"           "$(test -d "$N/wt/revloop-wt-u" && echo PRESENT)" "PRESENT"
  same   "and the record still untouched"       "$(cat "$LEDGER_N")" "$N/wt/revloop-wt-u"

  # Case 3: `revloop` is a regular file where the directory should be.
  mv "$LEDGER_N_DIR" "$LEDGER_N_DIR.aside"
  : > "$LEDGER_N_DIR"
  OUT_N3=$( run_in "$N" ); RC_N3=$?
  rm -f "$LEDGER_N_DIR"; mv "$LEDGER_N_DIR.aside" "$LEDGER_N_DIR"
  expect "a record that is not a directory refuses too" "$OUT_N3" "WORKTREE=error reason=ledger-unreadable path=$LEDGER_N"
  refute "claiming no sweep"                            "$OUT_N3" "WORKTREE=swept"
  same   "and exiting zero"                             "$RC_N3"  "0"
  expect "with the worktree still there"                "$(test -d "$N/wt/revloop-wt-u" && echo PRESENT)" "PRESENT"

  OUT_N4=$( run_in "$N" )
  expect "and the same repository sweeps once readable" "$OUT_N4" "WORKTREE=removed path=$N/wt/revloop-wt-u"
  expect "saying so on the terminal line"               "$OUT_N4" "WORKTREE=swept removed=1 other=0 ledger=ok"
  same   "and retiring the line it spent"               "$(cat "$LEDGER_N")" ""
fi

# --- a clone of this project is not a measurement worktree ------------------
# A main checkout whose own directory is family-named. The guard must not fire:
# only a linked worktree's git dir holds a `gitdir` file.
L=$(new_repo revloop-wt-client)
git -C "$L" worktree add -q --detach "$L/wt/revloop-wt-a" HEAD

OUT_L1=$( run_in "$L" )
refute "a main checkout of the family name is not one" "$OUT_L1" "reason=inside-worktree"
expect "and it sweeps, owning nothing"                 "$OUT_L1" "WORKTREE=swept removed=0 other=2 ledger=ok"
# `worktree list` returns the checkout itself, and no ledger claims it.
expect "naming the checkout it stands in as another's" "$OUT_L1" "WORKTREE=other path=$L"
same   "and creating no ledger on the way"             "$(test -e "$(git -C "$L" rev-parse --absolute-git-dir)/revloop/worktrees.txt" && echo PRESENT)" ""
record "$L" "$L/wt/revloop-wt-a"

OUT_L2=$( run_in "$L" )
expect "and then removes what it recorded"             "$OUT_L2" "WORKTREE=removed path=$L/wt/revloop-wt-a"
expect "with the checkout still only named"            "$OUT_L2" "WORKTREE=swept removed=1 other=1 ledger=ok"
expect "and still on disk"                             "$(test -d "$L/.git" && echo PRESENT)" "PRESENT"

# --- a linked checkout that is somebody's working tree ----------------------
# A linked, family-named checkout with a ledger of its own. A measurement
# worktree never has one, so the guard must not fire here either.
M=$(new_repo linked-family)
git -C "$M" worktree add -q --detach "$M/revloop-wt-fix" HEAD
git -C "$M" worktree add -q --detach "$M/wt/revloop-wt-m" HEAD
echo built > "$M/wt/revloop-wt-m/artifact.txt"
record "$M/revloop-wt-fix" "$M/wt/revloop-wt-m"
LEDGER_M="$(git -C "$M/revloop-wt-fix" rev-parse --absolute-git-dir)/revloop/worktrees.txt"

OUT_M1=$( run_in "$M/revloop-wt-fix" )
refute "a linked checkout with a record of its own sweeps" "$OUT_M1" "reason=inside-worktree"
expect "and removes what it recorded"                      "$OUT_M1" "WORKTREE=removed path=$M/wt/revloop-wt-m"
expect "naming the checkout it stands in"                  "$OUT_M1" "WORKTREE=other path=$M/revloop-wt-fix"
expect "and says so once"                                  "$OUT_M1" "WORKTREE=swept removed=1 other=1 ledger=ok"
expect "and the checkout survives"                         "$(test -d "$M/revloop-wt-fix" && echo PRESENT)" "PRESENT"
# A ledger line claiming the checkout the fence stands in. `remove --force`
# would delete the cwd and exit 0, so the loop must skip it.
record "$M/revloop-wt-fix" "$M/revloop-wt-fix"

OUT_M2=$( run_in "$M/revloop-wt-fix" )
expect "the fence never removes what it stands in" "$OUT_M2" "WORKTREE=stuck path=$M/revloop-wt-fix"
expect "and the verdict says so"                   "$OUT_M2" "WORKTREE=partial removed=0 stuck=1 other=0 ledger=ok"
expect "and it is still on disk"                   "$(test -d "$M/revloop-wt-fix" && echo PRESENT)" "PRESENT"
expect "and still registered"                      "$(git -C "$M" worktree list)" "$M/revloop-wt-fix"
same   "and its line is kept, not retired"         "$(cat "$LEDGER_M")" "$M/revloop-wt-fix"

# --- a symlink planted at the temp path -------------------------------------
# A symlink at worktrees.txt.new: the rewrite must not write through it.
P=$(new_repo symlink-temp)
git -C "$P" worktree add -q --detach "$P/wt/revloop-wt-p" HEAD
record "$P" "$P/wt/revloop-wt-p"
LEDGER_P_DIR="$(git -C "$P" rev-parse --absolute-git-dir)/revloop"
echo untouched > "$P/victim.txt"
ln -s "$P/victim.txt" "$LEDGER_P_DIR/worktrees.txt.new"

OUT_P=$( run_in "$P" ); RC_P=$?
same   "a planted temp symlink truncates nothing" "$(cat "$P/victim.txt")" "untouched"
expect "the sweep still removes what it owns"     "$OUT_P" "WORKTREE=removed path=$P/wt/revloop-wt-p"
expect "and the record is written for real"       "$OUT_P" "WORKTREE=swept removed=1 other=0 ledger=ok"
same   "the record is a regular file, not a link" "$(test -L "$LEDGER_P_DIR/worktrees.txt" && echo LINK)" ""
same   "and holds the empty stuck set"            "$(cat "$LEDGER_P_DIR/worktrees.txt")" ""
same   "and the fence exits zero"                 "$RC_P" "0"

# --- a plant the unlink cannot clear ----------------------------------------
# The planted symlink cannot be unlinked in a read-only directory. The failed
# unlink must stop the write. This does not exercise the fence's `set -C`.
U=$(new_repo unclearable-plant)
git -C "$U" worktree add -q --detach "$U/wt/revloop-wt-v" HEAD
record "$U" "$U/wt/revloop-wt-v"
LEDGER_U_DIR="$(git -C "$U" rev-parse --absolute-git-dir)/revloop"
echo untouched > "$U/victim.txt"
ln -s "$U/victim.txt" "$LEDGER_U_DIR/worktrees.txt.new"
if [ "$(id -u)" = 0 ]; then
  printf '  note a read-only directory does not stop root; the noclobber write is unmeasured here\n'
else
  chmod a-w "$LEDGER_U_DIR"
  OUT_U=$( run_in "$U" ); RC_U=$?
  chmod u+w "$LEDGER_U_DIR"
  same   "a plant the unlink cannot clear truncates nothing" "$(cat "$U/victim.txt")" "untouched"
  same   "and the temp path is left as it was found"        "$(readlink "$LEDGER_U_DIR/worktrees.txt.new")" "$U/victim.txt"
  expect "the sweep is refused before any removal"       "$OUT_U" "WORKTREE=error reason=ledger-unwritable"
  refute "and nothing is removed"                       "$OUT_U" "WORKTREE=removed"
  expect "the worktree is still on disk"                "$(test -d "$U/wt/revloop-wt-v" && echo PRESENT)" "PRESENT"
  same   "the record is left exactly as it was"         "$(cat "$LEDGER_U_DIR/worktrees.txt")" "$U/wt/revloop-wt-v"
  same   "and the fence exits zero"                     "$RC_U" "0"
  # The fence's output is parsed, so rm's stderr must not reach it.
  refute "and says nothing that is not a WORKTREE line" "$OUT_U" "Permission denied"
fi

# --- a read-only record in a writable directory -----------------------------
# A mode-0444 record in a writable directory still sweeps: the rewrite renames
# over the record, which needs write on the directory only.
RO=$(new_repo readonly-record-writable-dir)
git -C "$RO" worktree add -q --detach "$RO/wt/revloop-wt-ro" HEAD
echo built > "$RO/wt/revloop-wt-ro/artifact.txt"
record "$RO" "$RO/wt/revloop-wt-ro"
RO_DIR="$(git -C "$RO" rev-parse --absolute-git-dir)/revloop"
if [ "$(id -u)" = 0 ]; then
  printf '  note a read-only file does not stop root; the rename-vs-truncate split is unmeasured here\n'
else
  chmod 0444 "$RO_DIR/worktrees.txt"
  OUT_RO=$( run_in "$RO" ); RC_RO=$?
  chmod 0644 "$RO_DIR/worktrees.txt"
  expect "a read-only record in a writable directory still sweeps" "$OUT_RO" "WORKTREE=removed path=$RO/wt/revloop-wt-ro"
  expect "and the rename carries the rewrite through"              "$OUT_RO" "WORKTREE=swept removed=1 other=0 ledger=ok"
  refute "so the write probe never refuses it"                     "$OUT_RO" "ledger-unwritable"
  refute "and the record is never called unwritten"                "$OUT_RO" "ledger=error"
  same   "the spent line is retired for real"                      "$(cat "$RO_DIR/worktrees.txt")" ""
  same   "and the fence exits zero"                                "$RC_RO" "0"
fi

# --- a directory standing at the rewrite's temp path ------------------------
# A directory at the temp path. `[ -w ]` on the ledger directory is true, yet
# the rewrite would fail, so the probe must refuse before any removal.
FN=$(new_repo dir-at-temp-path)
git -C "$FN" worktree add -q --detach "$FN/wt/revloop-wt-fn" HEAD
echo built > "$FN/wt/revloop-wt-fn/artifact.txt"
record "$FN" "$FN/wt/revloop-wt-fn"
FN_DIR="$(git -C "$FN" rev-parse --absolute-git-dir)/revloop"
mkdir -p "$FN_DIR/worktrees.txt.new/blocker"

OUT_FN=$( run_in "$FN" ); RC_FN=$?
expect "a directory at the temp path refuses the sweep" "$OUT_FN" "WORKTREE=error reason=ledger-unwritable path=$FN_DIR/worktrees.txt"
refute "and removes nothing"                            "$OUT_FN" "WORKTREE=removed"
refute "and never claims a clean sweep"                 "$OUT_FN" "WORKTREE=swept"
refute "nor a partial one"                              "$OUT_FN" "WORKTREE=partial"
expect "the worktree keeps its untracked file"          "$(cat "$FN/wt/revloop-wt-fn/artifact.txt")" "built"
same   "and the record still authorizes it"             "$(cat "$FN_DIR/worktrees.txt")" "$FN/wt/revloop-wt-fn"
same   "and the fence exits zero"                       "$RC_FN" "0"

rm -rf "$FN_DIR/worktrees.txt.new"
OUT_FN2=$( run_in "$FN" )
expect "and the same repository sweeps once the temp path is clear" "$OUT_FN2" "WORKTREE=removed path=$FN/wt/revloop-wt-fn"
expect "saying so on its terminal line"                             "$OUT_FN2" "WORKTREE=swept removed=1 other=0 ledger=ok"

# --- the rename the probe now performs --------------------------------------
# The probe copies the record to the temp path and renames it back.
IR=$(new_repo identity-rename-probe)
git -C "$IR" worktree add -q --detach "$IR/wt/revloop-wt-ir" HEAD
echo built > "$IR/wt/revloop-wt-ir/artifact.txt"
git -C "$IR" worktree add -q --detach "$IR/wt/revloop-wt-ir2" HEAD
record "$IR" "$IR/wt/revloop-wt-ir" "$IR/wt/revloop-wt-ir2"
IR_DIR="$(git -C "$IR" rev-parse --absolute-git-dir)/revloop"
IR_BEFORE=$(cat "$IR_DIR/worktrees.txt")

OUT_IR=$( run_in "$IR" ); RC_IR=$?
expect "the probe's rename does not disturb the record" "$OUT_IR" "WORKTREE=removed path=$IR/wt/revloop-wt-ir"
expect "and the second entry is swept from the same record" "$OUT_IR" "WORKTREE=removed path=$IR/wt/revloop-wt-ir2"
expect "and the terminal line is clean"                 "$OUT_IR" "WORKTREE=swept removed=2 other=0 ledger=ok"
same   "and both lines are retired for real"            "$(cat "$IR_DIR/worktrees.txt")" ""
same   "and the temp path is left behind by neither"    "$(test -e "$IR_DIR/worktrees.txt.new" && echo PRESENT)" ""
same   "and the fence exits zero"                       "$RC_IR" "0"
same   "the record really did name both before the run" "$IR_BEFORE" "$IR/wt/revloop-wt-ir
$IR/wt/revloop-wt-ir2"

# --- an empty record under an unwritable directory --------------------------
# An empty record authorizes nothing, so the write probe is skipped and the
# read-only directory does not refuse the sweep.
EM=$(new_repo empty-record-readonly-dir)
git -C "$EM" worktree add -q --detach "$EM/wt/revloop-wt-em" HEAD
echo built > "$EM/wt/revloop-wt-em/artifact.txt"
EM_DIR="$(git -C "$EM" rev-parse --absolute-git-dir)/revloop"
mkdir -p "$EM_DIR"; : > "$EM_DIR/worktrees.txt"
if [ "$(id -u)" = 0 ]; then
  printf '  note a read-only directory does not stop root; the skipped probe is unmeasured here\n'
else
  chmod a-w "$EM_DIR"
  OUT_EM=$( run_in "$EM" ); RC_EM=$?
  chmod u+w "$EM_DIR"
  expect "an empty record owns nothing"          "$OUT_EM" "WORKTREE=other path=$EM/wt/revloop-wt-em"
  expect "and the sweep completes"               "$OUT_EM" "WORKTREE=swept removed=0 other=1 ledger=ok"
  refute "removing nothing"                      "$OUT_EM" "WORKTREE=removed"
  refute "and never reaching the write probe"    "$OUT_EM" "ledger-unwritable"
  expect "the worktree keeps its untracked file" "$(cat "$EM/wt/revloop-wt-em/artifact.txt")" "built"
  same   "and the fence exits zero"              "$RC_EM" "0"
fi

# --- a symlink planted at the record itself ---------------------------------
# The record is a symlink to another file. `[ -e ]` and `[ -f ]` follow it.
Q=$(new_repo symlink-ledger)
git -C "$Q" worktree add -q --detach "$Q/wt/revloop-wt-q" HEAD
echo built > "$Q/wt/revloop-wt-q/artifact.txt"
record "$Q" "$Q/wt/revloop-wt-q"
LEDGER_Q="$(git -C "$Q" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
echo untouched > "$Q/victim.txt"
rm -f "$LEDGER_Q"
ln -s "$Q/victim.txt" "$LEDGER_Q"

OUT_Q=$( run_in "$Q" ); RC_Q=$?
expect "a record that is a symlink refuses the sweep" "$OUT_Q" "WORKTREE=error reason=ledger-not-regular path=$LEDGER_Q"
refute "and never claims a clean one"                 "$OUT_Q" "WORKTREE=swept"
refute "nor a partial one"                            "$OUT_Q" "WORKTREE=partial"
refute "and removes nothing"                          "$OUT_Q" "WORKTREE=removed"
refute "and calls nothing another's"                  "$OUT_Q" "WORKTREE=other"
same   "the file it pointed at keeps its bytes"       "$(cat "$Q/victim.txt")" "untouched"
expect "and the worktree keeps its directory"         "$(test -f "$Q/wt/revloop-wt-q/artifact.txt" && echo PRESENT)" "PRESENT"
same   "and the fence exits zero"                     "$RC_Q" "0"

# --- a FIFO planted at the record -------------------------------------------
# A FIFO would block `cat` forever, so this fixture runs under run_capped.
V=$(new_repo fifo-ledger)
git -C "$V" worktree add -q --detach "$V/wt/revloop-wt-v" HEAD
echo built > "$V/wt/revloop-wt-v/artifact.txt"
record "$V" "$V/wt/revloop-wt-v"
LEDGER_V="$(git -C "$V" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
cp "$LEDGER_V" "$V/ledger.bak"
rm -f "$LEDGER_V"
mkfifo "$LEDGER_V"

OUT_V=$( run_capped "$V" ); RC_V=$?
expect "a record that is a FIFO refuses the sweep" "$OUT_V" "WORKTREE=error reason=ledger-not-regular path=$LEDGER_V"
same   "and the fence terminates at all"           "$RC_V"  "0"
refute "never claiming a clean sweep"              "$OUT_V" "WORKTREE=swept"
refute "nor a partial one"                         "$OUT_V" "WORKTREE=partial"
refute "and removing nothing"                      "$OUT_V" "WORKTREE=removed"
refute "and calling nothing another's"             "$OUT_V" "WORKTREE=other"
expect "the worktree keeps its directory"          "$(test -d "$V/wt/revloop-wt-v" && echo PRESENT)" "PRESENT"
expect "and its untracked file"                    "$(cat "$V/wt/revloop-wt-v/artifact.txt")" "built"

rm -f "$LEDGER_V"; mv "$V/ledger.bak" "$LEDGER_V"
OUT_V2=$( run_capped "$V" )
expect "and the same repository sweeps once the record is regular" "$OUT_V2" "WORKTREE=removed path=$V/wt/revloop-wt-v"
expect "saying so on its terminal line"                            "$OUT_V2" "WORKTREE=swept removed=1 other=0 ledger=ok"

# --- a dangling symlink planted at the record -------------------------------
# A dangling link makes `[ -e ]` false. Without the `[ -L ]` test it would be
# reported as ledger-unreadable.
DL=$(new_repo dangling-ledger)
git -C "$DL" worktree add -q --detach "$DL/wt/revloop-wt-dl" HEAD
echo built > "$DL/wt/revloop-wt-dl/artifact.txt"
record "$DL" "$DL/wt/revloop-wt-dl"
LEDGER_DL="$(git -C "$DL" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
rm -f "$LEDGER_DL"
ln -s "$DL/target-that-is-not-there" "$LEDGER_DL"

OUT_DL=$( run_in "$DL" ); RC_DL=$?
expect "a record that is a dangling symlink refuses the sweep" "$OUT_DL" "WORKTREE=error reason=ledger-not-regular path=$LEDGER_DL"
refute "and is NOT reported as the unreadable record it is not" "$OUT_DL" "ledger-unreadable"
refute "and never claims a clean sweep"                         "$OUT_DL" "WORKTREE=swept"
refute "nor a partial one"                                      "$OUT_DL" "WORKTREE=partial"
refute "and removes nothing"                                    "$OUT_DL" "WORKTREE=removed"
expect "the worktree keeps its untracked file"                  "$(cat "$DL/wt/revloop-wt-dl/artifact.txt")" "built"
same   "and the fence exits zero"                               "$RC_DL" "0"

rm -f "$LEDGER_DL"; record "$DL" "$DL/wt/revloop-wt-dl"
OUT_DL2=$( run_in "$DL" )
expect "and the same repository sweeps once the record is regular" "$OUT_DL2" "WORKTREE=removed path=$DL/wt/revloop-wt-dl"
expect "saying so on its terminal line"                            "$OUT_DL2" "WORKTREE=swept removed=1 other=0 ledger=ok"

# --- a directory planted at the record --------------------------------------
DD=$(new_repo directory-ledger)
git -C "$DD" worktree add -q --detach "$DD/wt/revloop-wt-dd" HEAD
echo built > "$DD/wt/revloop-wt-dd/artifact.txt"
record "$DD" "$DD/wt/revloop-wt-dd"
LEDGER_DD="$(git -C "$DD" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
rm -f "$LEDGER_DD"
mkdir "$LEDGER_DD"

OUT_DD=$( run_in "$DD" ); RC_DD=$?
expect "a record that is a directory refuses the sweep" "$OUT_DD" "WORKTREE=error reason=ledger-not-regular path=$LEDGER_DD"
refute "and is not reported as an unreadable record"    "$OUT_DD" "ledger-unreadable"
refute "and never claims a clean sweep"                 "$OUT_DD" "WORKTREE=swept"
refute "nor a partial one"                              "$OUT_DD" "WORKTREE=partial"
refute "and removes nothing"                            "$OUT_DD" "WORKTREE=removed"
expect "the worktree keeps its untracked file"          "$(cat "$DD/wt/revloop-wt-dd/artifact.txt")" "built"
same   "and the fence exits zero"                       "$RC_DD" "0"

rmdir "$LEDGER_DD"; record "$DD" "$DD/wt/revloop-wt-dd"
OUT_DD2=$( run_in "$DD" )
expect "and the same repository sweeps once the record is regular" "$OUT_DD2" "WORKTREE=removed path=$DD/wt/revloop-wt-dd"
expect "saying so on its terminal line"                            "$OUT_DD2" "WORKTREE=swept removed=1 other=0 ledger=ok"

# --- a symlink planted at the ledger's directory ----------------------------
# `revloop` is a symlink to a directory holding a regular worktrees.txt, so
# every test on the leaf passes.
SD=$(new_repo symlink-ledger-dir)
git -C "$SD" worktree add -q --detach "$SD/wt/revloop-wt-sd" HEAD
echo built > "$SD/wt/revloop-wt-sd/artifact.txt"
record "$SD" "$SD/wt/revloop-wt-sd"
SD_G=$(git -C "$SD" rev-parse --absolute-git-dir)

mv "$SD_G/revloop" "$SD/real-ledger"
mkdir -p "$SD/elsewhere"
cp "$SD/real-ledger/worktrees.txt" "$SD/elsewhere/worktrees.txt"
ln -s "$SD/elsewhere" "$SD_G/revloop"

OUT_SD=$( run_in "$SD" ); RC_SD=$?
expect "a ledger directory that is a symlink refuses the sweep" "$OUT_SD" "WORKTREE=error reason=ledger-dir-not-regular path=$SD_G/revloop"
refute "and never claims a clean sweep"                         "$OUT_SD" "WORKTREE=swept"
refute "nor a partial one"                                      "$OUT_SD" "WORKTREE=partial"
refute "and removes nothing"                                    "$OUT_SD" "WORKTREE=removed"
refute "and calls nothing another's"                            "$OUT_SD" "WORKTREE=other"
refute "and does not misreport it as the leaf refusal"          "$OUT_SD" "reason=ledger-not-regular"
expect "the worktree keeps its directory"                       "$(test -d "$SD/wt/revloop-wt-sd" && echo PRESENT)" "PRESENT"
expect "and its untracked file"                                 "$(cat "$SD/wt/revloop-wt-sd/artifact.txt")" "built"
expect "and the file behind the link is untouched"              "$(cat "$SD/elsewhere/worktrees.txt")" "$SD/wt/revloop-wt-sd"
same   "and the fence exits zero"                               "$RC_SD" "0"

rm -f "$SD_G/revloop"; mv "$SD/real-ledger" "$SD_G/revloop"
OUT_SD2=$( run_in "$SD" )
expect "and the same repository sweeps once the directory is real" "$OUT_SD2" "WORKTREE=removed path=$SD/wt/revloop-wt-sd"
expect "saying so on its terminal line"                            "$OUT_SD2" "WORKTREE=swept removed=1 other=0 ledger=ok"

# --- a dangling symlink at the ledger's directory ---------------------------
# The guard must test the link itself: `[ -e ]` and `[ -d ]` are false here.
GD=$(new_repo dangling-ledger-dir)
git -C "$GD" worktree add -q --detach "$GD/wt/revloop-wt-gd" HEAD
echo built > "$GD/wt/revloop-wt-gd/artifact.txt"
record "$GD" "$GD/wt/revloop-wt-gd"
GD_G=$(git -C "$GD" rev-parse --absolute-git-dir)
mv "$GD_G/revloop" "$GD/real-ledger"
ln -s "$GD/no-such-directory" "$GD_G/revloop"

OUT_GD=$( run_in "$GD" ); RC_GD=$?
expect "a dangling ledger directory refuses the sweep" "$OUT_GD" "WORKTREE=error reason=ledger-dir-not-regular path=$GD_G/revloop"
refute "and is not reported as an unreadable record"   "$OUT_GD" "ledger-unreadable"
refute "and never claims a clean sweep"                "$OUT_GD" "WORKTREE=swept"
refute "and removes nothing"                           "$OUT_GD" "WORKTREE=removed"
expect "the worktree keeps its untracked file"         "$(cat "$GD/wt/revloop-wt-gd/artifact.txt")" "built"
same   "and the fence exits zero"                      "$RC_GD" "0"

rm -f "$GD_G/revloop"; mv "$GD/real-ledger" "$GD_G/revloop"
OUT_GD2=$( run_in "$GD" )
expect "and the same repository sweeps once the directory is real" "$OUT_GD2" "WORKTREE=removed path=$GD/wt/revloop-wt-gd"

# --- a stale temp file from an earlier run ----------------------------------
# `set -C` refuses an existing regular file too, so the fence's `rm -f` is what
# clears a leftover temp file.
R=$(new_repo stale-temp)
git -C "$R" worktree add -q --detach "$R/wt/revloop-wt-r" HEAD
record "$R" "$R/wt/revloop-wt-r"
LEDGER_R_DIR="$(git -C "$R" rev-parse --absolute-git-dir)/revloop"
echo leftover > "$LEDGER_R_DIR/worktrees.txt.new"

OUT_R=$( run_in "$R" )
expect "a stale temp file does not wedge the rewrite" "$OUT_R" "WORKTREE=swept removed=1 other=0 ledger=ok"
same   "and the record is rewritten"                  "$(cat "$LEDGER_R_DIR/worktrees.txt")" ""
same   "and the residue is gone"                      "$(test -e "$LEDGER_R_DIR/worktrees.txt.new" && echo PRESENT)" ""

# --- the family name with nothing after it ----------------------------------
T=$(new_repo empty-slug)
git -C "$T" worktree add -q --detach "$T/wt/revloop-wt-" HEAD
git -C "$T" worktree add -q --detach "$T/wt/revloop-wt" HEAD
record "$T" "$T/wt/revloop-wt-"
LEDGER_T="$(git -C "$T" rev-parse --absolute-git-dir)/revloop/worktrees.txt"

OUT_T=$( run_in "$T" ); LIST_T=$( git -C "$T" worktree list )
expect "the bare prefix is inside the family"     "$OUT_T"  "WORKTREE=removed path=$T/wt/revloop-wt-"
expect "and the sweep says so once"               "$OUT_T"  "WORKTREE=swept removed=1 other=0 ledger=ok"
same   "and the line it spent is retired"         "$(cat "$LEDGER_T")" ""
refute "the name without the hyphen is untouched" "$OUT_T"  "path=$T/wt/revloop-wt "
expect "and keeps its registration"               "$LIST_T" "$T/wt/revloop-wt "
expect "and its directory"                        "$(test -d "$T/wt/revloop-wt" && echo PRESENT)" "PRESENT"

# --- a record whose last line lost its newline ------------------------------
# `M=$(cat "$F")` strips trailing newlines, so the fence reads this record fine.
# The writer must restore the newline before appending, or two paths are glued.
W=$(new_repo unterminated-ledger)
git -C "$W" worktree add -q --detach "$W/wt/revloop-wt-w1" HEAD
git -C "$W" worktree add -q --detach "$W/wt/revloop-wt-w2" HEAD
LEDGER_W_DIR="$(git -C "$W" rev-parse --absolute-git-dir)/revloop"
mkdir -p "$LEDGER_W_DIR"
LEDGER_W="$LEDGER_W_DIR/worktrees.txt"
# a hand edit, or an editor that drops the final newline
printf '%s' "$(git -C "$W/wt/revloop-wt-w1" rev-parse --show-toplevel)" > "$LEDGER_W"
same   "the record starts with no final newline" "$(wc -l < "$LEDGER_W" | tr -d ' ')" "0"
record "$W" "$W/wt/revloop-wt-w2"
same   "and step 3's clause restores it"         "$(wc -l < "$LEDGER_W" | tr -d ' ')" "2"

OUT_W=$( run_in "$W" ); RC_W=$?
expect "so the first entry is still this run's"  "$OUT_W" "WORKTREE=removed path=$W/wt/revloop-wt-w1"
expect "and so is the second"                    "$OUT_W" "WORKTREE=removed path=$W/wt/revloop-wt-w2"
expect "with nothing handed to another checkout" "$OUT_W" "WORKTREE=swept removed=2 other=0 ledger=ok"
same   "and the fence exits zero"                "$RC_W"  "0"

# The append without the repair, pinned as its cost: both worktrees leak.
X=$(new_repo glued-ledger)
git -C "$X" worktree add -q --detach "$X/wt/revloop-wt-x1" HEAD
git -C "$X" worktree add -q --detach "$X/wt/revloop-wt-x2" HEAD
echo built > "$X/wt/revloop-wt-x1/artifact.txt"
LEDGER_X_DIR="$(git -C "$X" rev-parse --absolute-git-dir)/revloop"
mkdir -p "$LEDGER_X_DIR"
LEDGER_X="$LEDGER_X_DIR/worktrees.txt"
printf '%s' "$(git -C "$X/wt/revloop-wt-x1" rev-parse --show-toplevel)" > "$LEDGER_X"
git -C "$X/wt/revloop-wt-x2" rev-parse --show-toplevel >> "$LEDGER_X"
same   "the unrepaired append leaves one line"  "$(wc -l < "$LEDGER_X" | tr -d ' ')" "1"

OUT_X=$( run_in "$X" )
expect "and the first entry leaks as another's" "$OUT_X" "WORKTREE=other path=$X/wt/revloop-wt-x1"
expect "and so does the second"                 "$OUT_X" "WORKTREE=other path=$X/wt/revloop-wt-x2"
expect "under a line that still says swept"     "$OUT_X" "WORKTREE=swept removed=0 other=2 ledger=ok"
expect "with the worktree still on disk"        "$(test -d "$X/wt/revloop-wt-x1" && echo PRESENT)" "PRESENT"
expect "and its untracked file"                 "$(cat "$X/wt/revloop-wt-x1/artifact.txt")" "built"

# --- the rule is written in both procedures ---------------------------------
# Each procedure must still state the rule. local-loop.md cites the fence and
# must not copy it: tests/extract-fences.sh reads remote-loop.md only.
REMOTE="$ROOT/procedures/remote-loop.md"
LOCAL="$ROOT/procedures/local-loop.md"
found() { grep -o "$1" "$2" | head -1; }     # presence, never a count: a count of 12 contains "1"
foundf() { grep -oF "$1" "$2" | head -1; }   # fixed-string, for a phrase carrying regex metacharacters
FENCE_ID='revloop:fence id=worktree-teardown'
# The backticks are the procedures' markup and must reach grep unevaluated.
# shellcheck disable=SC2016
PREFIX_RULE='`revloop-wt-`'
# shellcheck disable=SC2016
LEDGER_RULE='`revloop/worktrees.txt`'
# record() above copies this clause, so the procedure is checked for it too.
NEWLINE_RULE='tail -c1'
# The rules below are in step 3's block, which no fixture here runs. Each literal
# must occur only in the command; one the prose also contains would pin nothing.
# shellcheck disable=SC2016
LINKDIR_RULE='[ ! -L "$D" ] && { [ ! -e "$D" ] || [ -d "$D" ]; }'
# shellcheck disable=SC2016
LEAFTYPE_RULE='[ ! -L "$D/worktrees.txt" ]'
# shellcheck disable=SC2016
NEWLINE_PATH_RULE='case $N in revloop-wt-*[!A-Za-z0-9._-]*|revloop-wt-) false ;; revloop-wt-*) true ;; *) false ;; esac'
# shellcheck disable=SC2016
READWRITE_RULE='[ -r "$D/worktrees.txt" ] && [ -w "$D/worktrees.txt" ]'
# shellcheck disable=SC2016
PREPARE_RULE='&& mkdir -p "$D" && { [ -e "$D/worktrees.txt" ] || : > "$D/worktrees.txt"; }'
# shellcheck disable=SC2016
DIRWRITE_RULE='[ -w "$D/worktrees.txt" ] && [ -w "$D" ]'
# shellcheck disable=SC2016
LEAFLINK_RULE='W="${P%/}/$N" && [ ! -L "$W" ]'
# shellcheck disable=SC2016
DOUBLEROOT_RULE='case $P in //[!/]*) false ;; *) true ;; esac'
# shellcheck disable=SC2016
GITDIR_RULE='D=$(git rev-parse --absolute-git-dir && printf x); D=${D%x}; D=${D%?}/revloop'
# shellcheck disable=SC2016
CANONICAL_RULE='P=$(cd "<scratch>" && pwd -P && printf x) && [ "$(printf '"'"'%s'"'"' "$P" | wc -l)" -eq 1 ]'
# shellcheck disable=SC2016
PROBE_RULE='rm -f "$D/worktrees.txt.new" && cp -p "$D/worktrees.txt" "$D/worktrees.txt.new" && mv -f "$D/worktrees.txt.new" "$D/worktrees.txt"'

expect "remote-loop holds the fence"        "$(found "$FENCE_ID" "$REMOTE")"        "$FENCE_ID"
expect "remote-loop states the name rule"   "$(found "$PREFIX_RULE" "$REMOTE")"     "$PREFIX_RULE"
expect "remote-loop names the ledger"       "$(foundf "$LEDGER_RULE" "$REMOTE")"    "$LEDGER_RULE"
expect "remote-loop restores the newline"   "$(foundf "$NEWLINE_RULE" "$REMOTE")"   "$NEWLINE_RULE"
expect "remote-loop types the ledger dir"        "$(foundf "$LINKDIR_RULE" "$REMOTE")" "$LINKDIR_RULE"
expect "remote-loop types the ledger leaf too"   "$(foundf "$LEAFTYPE_RULE" "$REMOTE")" "$LEAFTYPE_RULE"
expect "remote-loop validates the slug as a name" "$(foundf "$NEWLINE_PATH_RULE" "$REMOTE")" "$NEWLINE_PATH_RULE"
expect "remote-loop proves the ledger usable"      "$(foundf "$READWRITE_RULE" "$REMOTE")"    "$READWRITE_RULE"
expect "remote-loop makes the ledger first"        "$(foundf "$PREPARE_RULE" "$REMOTE")"      "$PREPARE_RULE"
expect "remote-loop proves what the fence needs"   "$(foundf "$DIRWRITE_RULE" "$REMOTE")"     "$DIRWRITE_RULE"
expect "remote-loop builds the path it records"    "$(foundf "$LEAFLINK_RULE" "$REMOTE")"     "$LEAFLINK_RULE"
expect "remote-loop refuses a double-root parent"  "$(foundf "$DOUBLEROOT_RULE" "$REMOTE")"   "$DOUBLEROOT_RULE"
expect "remote-loop keeps the git dir's own bytes" "$(foundf "$GITDIR_RULE" "$REMOTE")"       "$GITDIR_RULE"
expect "remote-loop checks the canonical path"     "$(foundf "$CANONICAL_RULE" "$REMOTE")"    "$CANONICAL_RULE"
expect "remote-loop runs the probe on both sides"  "$(foundf "$PROBE_RULE" "$REMOTE")"        "$PROBE_RULE"
expect "local-loop cites the teardown"      "$(found 'worktree-teardown' "$LOCAL")" "worktree-teardown"
expect "local-loop cites the creation rule" "$(found 'step 3 gives' "$LOCAL")"      "step 3 gives"
expect "local-loop names the ledger too"    "$(foundf "$LEDGER_RULE" "$LOCAL")"     "$LEDGER_RULE"
expect "local-loop names the other class"   "$(found 'WORKTREE=other' "$LOCAL")"    "WORKTREE=other"
refute "local-loop copies no fence"         "$(found 'revloop:fence' "$LOCAL")"     "revloop:fence"

summary "fence-worktree"
