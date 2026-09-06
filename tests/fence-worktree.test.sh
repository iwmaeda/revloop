#!/usr/bin/env bash
# The teardown fence removes the worktrees THIS RUN created, and nothing else.
#
# THE CLAIM UNDER TEST IS THE SECOND HALF, NOT THE FIRST. That `git worktree
# remove` removes a worktree is git's behaviour and needs no test here. What
# needs one is the bound: the fence carries an unconditional `--force`, and the
# only thing between that and somebody's uncommitted work is what it matches on.
# So every scenario below plants a worktree the fence must NOT touch, and the
# assertion that it survived -- with its directory, not only its registration --
# is the one this file exists for.
#
# THE BOUND IS TWO CONDITIONS, AND BOTH ARE FIXTURED SEPARATELY. A path is swept
# only if it is a line in `<top level>/.revloop/worktrees.txt` AND its last
# component begins with `revloop-wt-`. The ledger is what says a worktree is this
# run's; the name is the second bound, held back for the ledger's bad day, so the
# ordinary repository below deliberately records a worktree of another name and
# asserts that recording it was not enough.
#
# OWNERSHIP IS A FILE THE TEST WRITES, which is the whole reason this file no
# longer contains any process-identity machinery. The rule it replaced put the
# run's pid in the worktree's name, and a harness that routes every shell call
# through one app-server hands two concurrent runs the same pid -- so the fixture
# had to own the pid it matched on, and the real thing could not tell two runs
# apart at all. A ledger is plantable with `record` and separates the runs that
# can actually coexist: two checkouts of one repository.
#
# THE FIXTURES ARE THROWAWAY REPOSITORIES, for the reason tests/lib.sh gives
# about the fence harness: the checkout these tests run in is a real branch
# locally and a detached HEAD under GitHub Actions' default PR checkout. It is
# also the only safe place to exercise a command that deletes worktrees --
# pointing this file at the repository it lives in would put
# `git worktree remove --force` one recorded line away from a developer's own
# tree.
#
# SIX REPOSITORIES, BECAUSE THE OUTCOMES CANNOT SHARE ONE. The ordinary sweep
# must print no `stuck` at all, so the worktree that produces one cannot stand in
# the same repository as that assertion; the no-prune case must hold a stale
# registration and NO worktree of the run's own, since the claim is about what
# the fence does when it owns nothing; the guards need a repository that is not
# one, and a cwd inside a worktree the fence would otherwise delete; the
# two-checkout case needs a repository with two of them; and the fail-open case
# needs a family-named worktree with no ledger anywhere.
#
# lib.sh's run_fence IS DELIBERATELY NOT USED. It builds its own throwaway
# repository, which this file has to pre-populate with worktrees, and it puts
# tests/bin on PATH for a `gh` stub this fence never calls. run_fence_detached
# exercises a no-branch guard that this fence does not have, because it resolves
# no pull request. Neither absence is an oversight.
#
# ONE GUARD IN THE FENCE IS NOT INDEPENDENTLY OBSERVABLE, and this file cannot
# fix that. `WORKTREE=error reason=not-a-repo` is printed from two places: a
# failing `git worktree list` and a failing `rev-parse --show-toplevel`. Outside
# a repository both fail, and in a bare repository only the second does -- so the
# fixtures below kill the second and no fixture kills the first. It stays because
# a `worktree list` that fails prints no rows, and an unguarded loop would then
# remove nothing and print a clean sweep over a repository it never read.
# `## Unexercised paths` in remote-loop.md records the gap rather than hiding it.
#
# `git worktree lock` IS HOW `stuck` IS REACHED, and it is a stand-in rather than
# the real case. What a run would actually hit is a permission error or a
# filesystem that will not release the directory; a lock is the one refusal that
# can be produced deterministically and without root. What it pins is that a
# refusal becomes a named line and a `partial` verdict rather than silence -- not
# the specific cause.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "fence-worktree:"

# lib.sh's expect asks whether the wanted text is a SUBSTRING of the actual,
# which is right for asserting that output says something and wrong for an exit
# status: `expect 0` is satisfied by 10, by 20 and by 130. rigor-levels.test.sh
# carries the same helper for the same reason.
same() { # same <label> <actual> <expected> -- exact, unlike lib.sh's expect
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$3" "$2"
  fi
}

# `pwd -P` because the assertions compare absolute paths against what git
# recorded, and git resolves symlinks. A contributor whose TMPDIR is behind one
# -- /tmp on macOS is -- would otherwise get a red suite that is green in CI.
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
FENCE="$TMP/worktree-teardown.sh"
"$ROOT/tests/extract-fences.sh" worktree-teardown > "$FENCE"

# A repository with one commit, so `worktree add` has something to point at.
new_repo() { # new_repo <name> -> path
  d="$TMP/$1"
  git init -q "$d"
  git -C "$d" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  printf '%s' "$d"
}

# The ledger line is taken from git rather than from the path this file typed,
# for the reason step 3 gives: the fence matches whole lines against what
# `git worktree list --porcelain` prints, and git resolves the path it records.
# Recording a worktree therefore has to happen while its directory still exists,
# which is why the `-gone` fixtures are recorded before they are deleted.
record() { # record <checkout> <worktree>... -- claim them in <checkout>'s ledger
  mkdir -p "$1/.revloop"
  for w in "${@:2}"; do
    git -C "$w" rev-parse --show-toplevel >> "$1/.revloop/worktrees.txt"
  done
}

run_in() { # run_in <dir> -> the fence's output, run with <dir> as the cwd
  ( cd "$1" && bash "$FENCE" 2>&1 )
}

# --- the ordinary sweep -----------------------------------------------------
A=$(new_repo ordinary)
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-base" HEAD
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-gone" HEAD
git -C "$A" worktree add -q --detach "$A/wt/mine" HEAD
# A path that CONTAINS the family name without ending in it. The fence matches
# the last component, and a version that matched the whole path would take this
# one with it -- which is how a prefix rule quietly becomes a substring rule.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-outer/inner" HEAD
# The family name with nothing after it. The `?*` in the fence's case pattern is
# what refuses this, and without a fixture nothing would notice it being dropped.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt" HEAD
# ANOTHER CHECKOUT'S, live and dirty: family-named, and in nobody's ledger here.
# This is the one a sweep bounded by the name alone would delete.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-theirs" HEAD
echo measuring > "$A/wt/revloop-wt-theirs/artifact.txt"
# And another run's stale registration. `remove --force` would deregister it and
# a `prune` would too; the ledger is what keeps the fence away from both.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-theirs-gone" HEAD
# Untracked output is what a baseline worktree accumulates -- a build, a linked
# node_modules -- and it is what plain `remove` refuses on: measured, one such
# file is enough for exit 128. Without this the --force is untested and anyone
# could drop it.
echo built > "$A/wt/revloop-wt-base/artifact.txt"
# THE LEDGER'S BAD DAY. `wt/mine` is recorded and must still survive: a
# truncated, hand-edited or half-written ledger line cannot aim the --force
# outside the family, because the name is checked too.
record "$A" "$A/wt/revloop-wt-base" "$A/wt/revloop-wt-gone" "$A/wt/mine"
# A registration whose directory is gone. `/tmp` cleared between sessions is the
# measured way this arrives. It is here to pin the reason the fence carries no
# `git worktree prune`: `remove --force` already deregisters this state, so a
# prune would add nothing while reaching past the ledger -- which the repository
# that owns nothing is what actually proves.
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
# THE ASSERTIONS THIS FILE IS FOR. A worktree of another name keeps both its
# registration and its directory EVEN WHEN THE LEDGER CLAIMS IT: --force is
# bounded by two conditions, and neither is anything git checks.
expect "a recorded worktree of another name is left registered" "$LIST_A" "$A/wt/mine"
expect "and is left on disk"                   "$(test -d "$A/wt/mine" && echo PRESENT)" "PRESENT"
refute "and is not even named as another's"    "$OUT_A"  "WORKTREE=other path=$A/wt/mine"
expect "a nested path keeps its registration"  "$LIST_A" "$A/wt/revloop-wt-outer/inner"
expect "and its directory"                     "$(test -d "$A/wt/revloop-wt-outer/inner" && echo PRESENT)" "PRESENT"
expect "the bare family name is not a match"   "$LIST_A" "$A/wt/revloop-wt "
expect "and keeps its directory too"           "$(test -d "$A/wt/revloop-wt" && echo PRESENT)" "PRESENT"
refute "and is not counted as another's"       "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt "
# AND THE SAME ASSERTIONS FOR THE WORK NEXT DOOR. This is the concurrency bound:
# two checkouts share a repository and therefore share `git worktree list`, so
# the name alone is not a bound at all.
expect "an unrecorded worktree is named"       "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt-theirs"
expect "and left registered"                   "$LIST_A" "$A/wt/revloop-wt-theirs"
expect "and left on disk, dirty"               "$(test -f "$A/wt/revloop-wt-theirs/artifact.txt" && echo PRESENT)" "PRESENT"
expect "its stale registration is named too"   "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt-theirs-gone"
expect "and survives, which no prune would allow" "$LIST_A" "$A/wt/revloop-wt-theirs-gone"
expect "the repository's own checkout survives" "$(test -d "$A/.git" && echo PRESENT)" "PRESENT"

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
# THE TOKEN SEPARATION. A failure verdict that contained the success token would
# make every `grep -q swept` true on a sweep that left something behind -- the
# hazard step 12 spends a paragraph on for CHECKS_FAILED and NOT_ALL_PASS.
refute "a failed sweep never claims success"   "$OUT_B"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_B"   "0"
expect "the stuck worktree is still there"     "$LIST_B" "revloop-wt-locked"
expect "and the bystander is untouched"        "$LIST_B" "$B/wt/keep"

# --- the fence owns nothing, and touches nothing ----------------------------
# The no-prune claim, which is the one thing a `git worktree prune` in this fence
# would break: a registration of SOMEBODY ELSE'S whose directory is missing --
# an unmounted drive, an encrypted volume before unlock -- must survive a run
# that created no worktree of its own.
C=$(new_repo bystander-stale)
git -C "$C" worktree add -q --detach "$C/wt/theirs" HEAD
rm -rf "$C/wt/theirs"

OUT_C=$( run_in "$C" )
LIST_C=$( git -C "$C" worktree list )

expect "a run that owns nothing says so"       "$OUT_C"  "WORKTREE=swept removed=0 other=0"
expect "and leaves a stale registration alone" "$LIST_C" "$C/wt/theirs"

# --- the two guards ---------------------------------------------------------
# Outside a repository `git worktree list` exits 128 and prints no rows, so an
# unguarded loop would remove nothing and print the success line over a
# repository it never read.
mkdir -p "$TMP/notrepo"
OUT_D=$( run_in "$TMP/notrepo" ); RC_D=$?
expect "outside a repository the fence says so" "$OUT_D" "WORKTREE=error reason=not-a-repo"
refute "and never claims a sweep"              "$OUT_D"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_D"   "0"

# A bare repository is the one state that separates the two calls behind that
# line: `worktree list` succeeds there and `rev-parse --show-toplevel` exits 128,
# measured at git 2.34.1. It is also the state where the fence has no ledger to
# read, because a ledger lives at a top level and there is not one.
git init -q --bare "$TMP/bare.git"
OUT_D2=$( run_in "$TMP/bare.git" ); RC_D2=$?
expect "a repository with no work tree says so" "$OUT_D2" "WORKTREE=error reason=not-a-repo"
refute "and never claims a sweep"              "$OUT_D2" "WORKTREE=swept"
same   "and still exits zero"                  "$RC_D2"  "0"

# Run from inside a measurement worktree the fence would read the WRONG ledger --
# that worktree's own top level, where there is none -- and would report every
# one of the run's worktrees as somebody else's under a `swept` line. It refuses
# the whole sweep instead. The guard also disarms a measured hazard on the way
# past: `git worktree remove --force` will delete the worktree the shell is
# standing in, exit 0, and take the working directory with it.
E=$(new_repo cwd)
git -C "$E" worktree add -q --detach "$E/wt/revloop-wt-self" HEAD
git -C "$E" worktree add -q --detach "$E/wt/revloop-wt-sibling" HEAD
record "$E" "$E/wt/revloop-wt-self" "$E/wt/revloop-wt-sibling"

OUT_E=$( run_in "$E/wt/revloop-wt-self" ); RC_E=$?
expect "the fence refuses to sweep from inside one" "$OUT_E" "WORKTREE=error reason=inside-worktree path=$E/wt/revloop-wt-self"
refute "and never claims a sweep"              "$OUT_E"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_E"   "0"
expect "its own directory is still there"      "$(test -d "$E/wt/revloop-wt-self" && echo PRESENT)" "PRESENT"
# The refusal is the WHOLE sweep, not one entry: a recorded sibling the fence
# could have removed correctly is left alone too, because the ledger it read was
# the wrong one.
expect "and so is the sibling it did not sweep" "$(test -d "$E/wt/revloop-wt-sibling" && echo PRESENT)" "PRESENT"

# --- two checkouts of one repository ----------------------------------------
# THE REGRESSION THIS DESIGN EXISTS FOR. `git worktree list` answers for the
# whole repository, so each of these runs has the other's measurement worktree in
# its list. Nothing about the two processes distinguishes them -- they may share
# a parent, and under a harness that routes every shell call through one
# app-server they do. The ledgers distinguish them, because each sits at its own
# checkout's top level.
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
# AND THE SYMMETRY: sweeping first does not make the second checkout's worktree
# unsweepable. Whoever runs is answered by their own ledger, in either order.
OUT_F2=$( run_in "$F/second" )
expect "the second checkout then sweeps its own" "$OUT_F2" "WORKTREE=removed path=$F/wt/revloop-wt-second"
expect "with nothing left to name"             "$OUT_F2" "WORKTREE=swept removed=1 other=0"

# --- no ledger, family name: the fail-open direction ------------------------
# A worktree created without its ledger line -- the half of step 3's rule that
# nothing enforces -- is left exactly where it is. This fixture is here so that
# the failure is a pinned, named behaviour rather than a surprise: `## Notes`
# says the rule fails open, and this is what that costs.
G=$(new_repo unrecorded)
git -C "$G" worktree add -q --detach "$G/wt/revloop-wt-orphan" HEAD

OUT_G=$( run_in "$G" )
expect "an unrecorded worktree is only named"  "$OUT_G"  "WORKTREE=other path=$G/wt/revloop-wt-orphan"
expect "and the sweep removes nothing"         "$OUT_G"  "WORKTREE=swept removed=0 other=1"
expect "and it is still on disk"               "$(test -d "$G/wt/revloop-wt-orphan" && echo PRESENT)" "PRESENT"

# --- the rule is written in both procedures ---------------------------------
#
# A tripwire, not a proof: it asks whether each file still says a run sweeps what
# it created, because the fence is in one file and the obligation has to reach
# the other. local-loop.md cites rather than copies -- tests/extract-fences.sh
# reads remote-loop.md alone, so a copied fence would sit outside the hash pin,
# outside lint:sh, and outside every assertion above.
REMOTE="$ROOT/procedures/remote-loop.md"
LOCAL="$ROOT/procedures/local-loop.md"
found() { grep -o "$1" "$2" | head -1; }     # presence, never a count: a count of 12 contains "1"
foundf() { grep -oF "$1" "$2" | head -1; }   # fixed-string, for a phrase carrying regex metacharacters
FENCE_ID='revloop:fence id=worktree-teardown'
# The backticks are the procedures' own markup and must reach grep unevaluated,
# which is why each phrase is written once, in single quotes, rather than inline
# at two call sites.
# shellcheck disable=SC2016
PREFIX_RULE='`revloop-wt-`'
# shellcheck disable=SC2016
LEDGER_RULE='`.revloop/worktrees.txt`'

expect "remote-loop holds the fence"        "$(found "$FENCE_ID" "$REMOTE")"        "$FENCE_ID"
expect "remote-loop states the name rule"   "$(found "$PREFIX_RULE" "$REMOTE")"     "$PREFIX_RULE"
expect "remote-loop names the ledger"       "$(foundf "$LEDGER_RULE" "$REMOTE")"    "$LEDGER_RULE"
expect "local-loop cites the teardown"      "$(found 'worktree-teardown' "$LOCAL")" "worktree-teardown"
expect "local-loop cites the creation rule" "$(found 'step 3 gives' "$LOCAL")"      "step 3 gives"
expect "local-loop names the ledger too"    "$(foundf "$LEDGER_RULE" "$LOCAL")"     "$LEDGER_RULE"
expect "local-loop names the other class"   "$(found 'WORKTREE=other' "$LOCAL")"    "WORKTREE=other"
refute "local-loop copies no fence"         "$(found 'revloop:fence' "$LOCAL")"     "revloop:fence"

summary "fence-worktree"
