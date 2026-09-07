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
# only if it is a line in `<git dir>/revloop/worktrees.txt` AND its last component
# begins with `revloop-wt-`. The ledger is what says a worktree is this run's; the
# name is the second bound, held back for the ledger's bad day, so the ordinary
# repository below deliberately records a worktree of another name and asserts
# that recording it was not enough.
#
# AND THE FIRST CONDITION IS A LEASE RATHER THAN A LICENCE, which is the newest
# claim here and the one two repositories exist for. The ledger used to be
# append-only, so a path stayed authorized for that unconditional `--force`
# forever after its own worktree was gone -- and the name is no help at all
# there, because whatever turns up at that path next carries the same name. The
# sweep now rewrites the record to exactly the paths it could not remove, so
# `reuse` plants a second worktree at a path the first sweep consumed and
# `hand-removed` retires a line whose worktree left the repository some other
# way. Both assert the later worktree is named `WORKTREE=other` and keeps its
# untracked file.
#
# THE RECORD IS EMPTIED AND NEVER DELETED, and that is load-bearing rather than
# lazy. Its EXISTENCE is what the `inside-worktree` guard reads, so a sweep that
# unlinked an emptied ledger would make a checkout that has recorded worktrees
# look like one that never has -- see the guard paragraph below.
#
# THE LEDGER LIVES UNDER THE GIT DIRECTORY, NOT AT THE TOP LEVEL, and one fixture
# exists solely for that. revloop runs against somebody else's repository, where
# this project's .gitignore has no reach, so a record in the working tree is an
# untracked file that `git status --porcelain -uall` returns -- which is the
# clean-tree check the local procedure's step 4 depends on. `<git dir>` is also
# still per checkout, which is the property the previous design needed: measured
# at git 2.34.1, `rev-parse --absolute-git-dir` prints `.git` in an ordinary
# checkout and `.git/worktrees/<name>` in a linked one. `--git-common-dir` prints
# the same path in both and would have merged the two runs into one ledger.
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
# FOURTEEN REPOSITORIES, BECAUSE THE OUTCOMES CANNOT SHARE ONE. The ordinary sweep
# must print no `stuck` at all, so the worktree that produces one cannot stand in
# the same repository as that assertion; the no-prune case must hold a stale
# registration and NO worktree of the run's own, since the claim is about what
# the fence does when it owns nothing; the guards need a repository that is not
# one, and a cwd inside a worktree the fence would otherwise delete; the
# two-checkout case needs a repository with two of them; the fail-open case
# needs a family-named worktree with no ledger anywhere; the clean-tree case
# needs the one repository whose worktree is placed where step 3 actually says to
# put it -- outside the checkout -- because a worktree inside the checkout is
# itself untracked and would mask the assertion; the two retirement cases each
# need a repository they can sweep twice; the write-failure case needs one whose
# ledger directory can be made read-only without disturbing anything else; the
# unreadable case needs its own again, because it takes READ off where the
# other takes WRITE off and the two cannot be staged in one repository without
# each measuring the other's state; and the two guard false positives need
# repositories whose own NAMES are in the family, which no other fixture can be
# without changing what it measures.
#
# THE DIRECTORY IS WHAT IS MADE READ-ONLY, NOT THE FILE. The rewrite creates a
# sibling and renames over the target, and rename(2) needs write permission on
# the parent and none at all on the target -- so a read-only `worktrees.txt`
# would be replaced happily and the fixture would measure nothing. The EXIT trap
# chmods $TMP back before rm -rf, which is what makes leaving one behind safe.
# It restores `u+rwX` rather than `u+w`, and that is not tidiness: the
# unreadable-ledger fixture below takes SEARCH off a directory, and `rm -rf`
# cannot descend into one it may not enter. `X` sets execute on directories and
# leaves the fence extracted at the top of this file un-executable, which it has
# no reason to be.
#
# AN UNREADABLE RECORD IS NOT AN EMPTY ONE, and the fence used to treat them
# alike: `cat` failing meant `M=` meant every recorded path fell out as
# `WORKTREE=other`, the rewrite was skipped so `ledger=ok` survived, and the
# terminal line claimed a clean sweep over a record nothing had opened. Measured
# against the unfixed fence at git 2.34.1: `WORKTREE=swept removed=0 other=1
# ledger=ok` with the run's own worktree still on disk and its untracked file in
# it.
#
# THE GUARD ASKS ABOUT THE DIRECTORY AND NOT THE FILE, and `unreadable-ledger`
# needs three cases because that is what makes the choice loadbearing. Asking
# `[ -e "$F" ]` looks like the obvious test and is DEAD CODE: measured, a file
# that is `[ -e ]` implies its parent is `[ -d ]`, so the file test can never be
# the one that fires. And it is not merely redundant but weaker -- taking SEARCH
# off the directory makes `[ -e ]` on the file inside it false, since stat(2)
# needs search on every component, while stat on the directory needs search only
# on ITS parent. The three cases are therefore an unreadable file, a directory
# with search taken off, and a `revloop` that is a regular file where the
# directory should be; `[ -e "$G/revloop" ]` is true in all three and `[ -d ]`
# misses the last.
#
# `reason=inside-worktree` IS THREE CONDITIONS AND USED TO BE ONE. The old guard
# read the invoking checkout's basename alone, which reserved `revloop-wt-*` for
# every possible checkout anybody might run a loop from: a clone at
# `~/src/revloop-wt-client`, or a developer's linked checkout named
# `revloop-wt-fix`, aborted the WHOLE sweep and leaked every worktree the run had
# recorded. A real measurement worktree is family-named, is LINKED, and has no
# ledger of its own -- step 3 records into the creating checkout's git directory,
# never into the new worktree's. So `revloop-wt-client` and `linked-family` below
# are the two false positives, one per conjunct, and `cwd` is still the true one.
# `[ -f "$G/gitdir" ]` is the linked test: measured at git 2.34.1, a linked
# worktree's git directory holds a `gitdir` file and a main `.git` does not, and
# gitrepository-layout(5) documents it as part of the multiple-worktree layout --
# below the 2.17 that `worktree remove` already assumes, so the floor did not
# move. The third conjunct asks whether the ledger FILE exists, not whether it has
# content, because after the first clean sweep a real checkout's ledger is empty
# and still present.
#
# THE SELF-SKIP IS A SEPARATE LINE FROM THAT GUARD, and narrowing the guard is why
# it had to become one. Measured at git 2.34.1, `remove --force` deletes the
# worktree the shell is standing in, takes the working directory with it and exits
# 0 -- so the loop refuses `"$p" = "$HERE"` on its own and calls it `stuck`, which
# is exactly what it is: still on disk, still registered. `linked-family` plants a
# ledger line claiming the checkout the fence is standing in and asserts it
# survives.
#
# lib.sh's run_fence IS DELIBERATELY NOT USED. It builds its own throwaway
# repository, which this file has to pre-populate with worktrees, and it puts
# tests/bin on PATH for a `gh` stub this fence never calls. run_fence_detached
# exercises a no-branch guard that this fence does not have, because it resolves
# no pull request. Neither absence is an oversight.
#
# TWO GUARDS IN THE FENCE ARE NOT INDEPENDENTLY OBSERVABLE, and this file cannot
# fix that. `WORKTREE=error reason=not-a-repo` is printed from three places: a
# failing `git worktree list`, a failing `rev-parse --show-toplevel`, and a
# failing `rev-parse --absolute-git-dir`. Outside a repository all three fail
# together, and in a bare repository only `--show-toplevel` does -- so the
# fixtures below kill that one and no fixture kills the other two. The list guard
# stays because a `worktree list` that fails prints no rows, and an unguarded loop
# would then remove nothing and print a clean sweep over a repository it never
# read. The `--absolute-git-dir` guard is weaker again: `--show-toplevel` has
# already succeeded above it, so no reachable state has been found where it fires
# at all, and it is there because the alternative is an empty ledger and a `swept`
# line over a record nothing opened. `## Unexercised paths` in remote-loop.md
# records both gaps rather than hiding them.
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

# The ledger line is taken from git rather than from the path this file typed,
# for the reason step 3 gives: the fence matches whole lines against what
# `git worktree list --porcelain` prints, and git resolves the path it records.
# Recording a worktree therefore has to happen while its directory still exists,
# which is why the `-gone` fixtures are recorded before they are deleted.
#
# THE LEDGER'S DIRECTORY IS ASKED OF GIT TOO, and for a sharper reason: the
# two-checkout fixture below is only a test of the real derivation if this helper
# resolves the git dir the same way the fence does. A hardcoded `$1/.git` would
# be right for a main checkout and wrong for a linked one -- which is exactly the
# case that fixture exists for -- so it would plant both ledgers in one file and
# the fixture would pass while measuring nothing.
record() { # record <checkout> <worktree>... -- claim them in <checkout>'s ledger
  d=$(git -C "$1" rev-parse --absolute-git-dir)/revloop
  mkdir -p "$d"
  for w in "${@:2}"; do
    git -C "$w" rev-parse --show-toplevel >> "$d/worktrees.txt"
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
# The family name MINUS ITS TRAILING HYPHEN, which is not in the family: the
# pattern's own `-` is what refuses this, and the `?*` that used to follow it
# never was. The empty-slug fixture below is the other side of that line.
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
# THE ASSERTION THAT PICKS THE RETIREMENT RULE. Two lines were consumed by a
# removal and one -- `wt/mine` -- was refused by the name, and the record keeps
# none of them: what survives a sweep is the STUCK SET, not "everything the sweep
# did not remove". A `wt/mine` left behind would be an authorization nothing can
# ever consume and anything can inherit.
LEDGER_A="$(git -C "$A" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
same   "the sweep leaves only the stuck set"   "$(cat "$LEDGER_A")" ""
expect "and the record is still there to read" "$(test -f "$LEDGER_A" && echo PRESENT)" "PRESENT"
# THE ONE ASSERTION THAT PINS FIELD ORDER AND END OF LINE. lib.sh's expect is a
# substring test, so every terminal-line assertion in this file would stay green
# if a field were appended, renamed or reordered. This one would not.
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
# THE TOKEN SEPARATION. A failure verdict that contained the success token would
# make every `grep -q swept` true on a sweep that left something behind -- the
# hazard step 12 spends a paragraph on for CHECKS_FAILED and NOT_ALL_PASS.
refute "a failed sweep never claims success"   "$OUT_B"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_B"   "0"
expect "the stuck worktree is still there"     "$LIST_B" "revloop-wt-locked"
expect "and the bystander is untouched"        "$LIST_B" "$B/wt/keep"
# THE RETENTION HALF OF THE SAME RULE. A path the sweep could not remove keeps
# its line, so the next run in this checkout still has a claim on it -- which is
# the whole reason the rewrite is the stuck set rather than "drop everything".
LEDGER_B="$(git -C "$B" rev-parse --absolute-git-dir)/revloop/worktrees.txt"
same   "a stuck worktree keeps its ledger line" "$(cat "$LEDGER_B")" "$B/wt/revloop-wt-locked"
expect "and the rewrite is still reported ok"   "$OUT_B"  "ledger=ok"
OUT_B2=$( run_in "$B" )
expect "so a second sweep still finds it"       "$OUT_B2" "WORKTREE=stuck path=$B/wt/revloop-wt-locked"

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
# THE INVARIANT THE inside-worktree GUARD RESTS ON: only step 3 creates a ledger.
# The rewrite is skipped wholesale when there was nothing to read, so a checkout
# that has never recorded anything still has no record afterwards -- and the
# guard's third conjunct can therefore keep asking whether the file exists.
same "a sweep with no ledger creates none"     "$(test -e "$(git -C "$G" rev-parse --absolute-git-dir)/revloop/worktrees.txt" && echo PRESENT)" ""

# --- the ledger is not a file in the tree -----------------------------------
# THE FINDING THIS LOCATION ANSWERS. revloop runs against somebody else's
# repository, where this project's .gitignore has no reach, so a ledger at the
# checkout's top level is an untracked file there -- and `git status --porcelain
# -uall` is exactly what the local procedure's step 4 runs to require a clean
# tree, and `git ls-files -o --exclude-standard` is the secret-scan preflight in
# step 3. This is the ONE fixture that places the worktree where step 3 says to
# put it, under a scratch directory OUTSIDE the checkout: every repository above
# nests its worktrees inside the checkout for convenience, which is untracked in
# its own right and would mask the assertion.
H=$(new_repo clean-tree)
git -C "$H" worktree add -q --detach "$TMP/h-scratch/revloop-wt-x" HEAD
record "$H" "$TMP/h-scratch/revloop-wt-x"

same "recording a worktree leaves the tree clean" "$(git -C "$H" status --porcelain -uall)" ""
same "and leaves nothing for the secret scan"     "$(git -C "$H" ls-files -o --exclude-standard)" ""
# NEVER STAGED IS A PROPERTY HERE, NOT A RULE: nothing under $GIT_DIR can be
# added to the index, so an operator running `git add -A` cannot commit the
# ledger even by accident. That is the guarantee a .gitignore was standing in for
# in a repository that has one, held one level down in every repository.
git -C "$H" add -A
same "and cannot be staged at all"             "$(git -C "$H" diff --cached --name-only)" ""
# And the fence still finds it, from the same checkout, with no argument.
OUT_H=$( run_in "$H" )
expect "the hidden ledger is still the fence's" "$OUT_H" "WORKTREE=removed path=$TMP/h-scratch/revloop-wt-x"
expect "and the sweep says so"                  "$OUT_H" "WORKTREE=swept removed=1 other=0"
# AND THE REWRITE IS UNDER THE GIT DIRECTORY TOO, temp file included. The clean
# tree was asserted above the sweep; it has to hold below it as well, or the
# ledger's whole reason for moving would survive only until the first teardown.
same "the rewrite leaves the tree clean too"    "$(git -C "$H" status --porcelain -uall)" ""
same "and leaves nothing for the secret scan"   "$(git -C "$H" ls-files -o --exclude-standard)" ""

# --- a path is authorized once, not forever ---------------------------------
# THE HAZARD AN APPEND-ONLY LEDGER CARRIED. A line survived the worktree it was
# written for, so the path stayed authorized for that unconditional `--force`
# forever -- and the family name is no second bound here at all, because whatever
# turns up at that path next is family-named by construction. The sweep now
# rewrites the record, so the same path has to be earned again.
I=$(new_repo reuse)
git -C "$I" worktree add -q --detach "$I/wt/revloop-wt-r1" HEAD
record "$I" "$I/wt/revloop-wt-r1"
LEDGER_I="$(git -C "$I" rev-parse --absolute-git-dir)/revloop/worktrees.txt"

OUT_I1=$( run_in "$I" )
expect "the first sweep removes what it owns" "$OUT_I1" "WORKTREE=removed path=$I/wt/revloop-wt-r1"
expect "and says the record was rewritten"    "$OUT_I1" "ledger=ok"
same   "the consumed line is retired"         "$(cat "$LEDGER_I")" ""
# Somebody else's worktree at a path this checkout once owned -- a later round,
# another checkout, a person -- with its work still in it.
git -C "$I" worktree add -q --detach "$I/wt/revloop-wt-r1" HEAD
echo measuring > "$I/wt/revloop-wt-r1/artifact.txt"

OUT_I2=$( run_in "$I" )
refute "the second sweep removes nothing"     "$OUT_I2" "WORKTREE=removed"
expect "and names it as another's instead"    "$OUT_I2" "WORKTREE=other path=$I/wt/revloop-wt-r1"
expect "it keeps its untracked file"          "$(test -f "$I/wt/revloop-wt-r1/artifact.txt" && echo PRESENT)" "PRESENT"
expect "and its registration"                 "$(git -C "$I" worktree list)" "$I/wt/revloop-wt-r1"
expect "and the run owns nothing"             "$OUT_I2" "WORKTREE=swept removed=0 other=1 ledger=ok"

# --- a record outlives its worktree without outliving its authority ---------
# THE CASE "RETIRE ONLY WHAT WAS REMOVED" LEAVES OPEN, and the reason the rewrite
# is the stuck set instead. A worktree can leave the repository without this fence
# touching it -- an operator ran `git worktree remove` by hand, or a `gc` pruned it
# after the directory was cleared -- and the loop walks `worktree list`, so it
# never reaches that line to retire it. The line would then authorize the path
# forever without the fence ever having removed anything.
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
# THE FAIL-SAFE DIRECTION. The rewrite writes a sibling and renames over the
# target, so a failure leaves the OLD record whole: nothing is lost, and what
# persists is an over-broad authorization the terminal line has just named. The
# alternative -- truncating in place -- would lose the stuck entries on a failed
# write, which is the leak this fence exists to prevent, produced by the fence.
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
  expect "the removal happens even so"        "$OUT_K" "WORKTREE=removed path=$K/wt/revloop-wt-w"
  expect "and the verdict names the failure"  "$OUT_K" "ledger=error"
  refute "and never calls the record ok"      "$OUT_K" "ledger=ok"
  same   "and still exits zero"               "$RC_K"  "0"
  same   "the record is left exactly as it was" "$(cat "$LEDGER_K_DIR/worktrees.txt")" "$K/wt/revloop-wt-w"
fi

# --- the record cannot be read ----------------------------------------------
# A FAILED READ USED TO BE AN ABSENT RECORD, and that is the one direction this
# fence must never fail in. `cat` exiting non-zero left `M` empty, so every
# recorded path fell out as WORKTREE=other, the `[ -n "$M" ]` rewrite was
# skipped so `ledger=ok` survived, and the terminal line announced a clean sweep
# over a record it had not opened -- with the run's own worktree still on disk.
# Both cases below are asserted on the DIRECTORY surviving and on the ledger
# coming back byte-identical, because the claim is that the fence touched
# nothing at all, not merely that it printed a different word.
N=$(new_repo unreadable-ledger)
git -C "$N" worktree add -q --detach "$N/wt/revloop-wt-u" HEAD
echo built > "$N/wt/revloop-wt-u/artifact.txt"
record "$N" "$N/wt/revloop-wt-u"
LEDGER_N_DIR="$(git -C "$N" rev-parse --absolute-git-dir)/revloop"
LEDGER_N="$LEDGER_N_DIR/worktrees.txt"
if [ "$(id -u)" = 0 ]; then
  printf '  note a mode of 000 does not stop root; ledger-unreadable unmeasured here\n'
else
  # THE FILE. Still `[ -e ]` and still `[ -f ]` -- only the read fails.
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

  # THE DIRECTORY. Search taken off makes `[ -e ]` on the file inside it FALSE,
  # so a guard written against the FILE reads this as "never recorded" and
  # sweeps past it. Asking about the directory is what catches it: stat(2) needs
  # search on the parent and nothing on the directory itself. git 2.34.1.
  chmod a-rx "$LEDGER_N_DIR"
  OUT_N2=$( run_in "$N" ); RC_N2=$?
  chmod u+rx "$LEDGER_N_DIR"
  expect "an unsearchable ledger directory too" "$OUT_N2" "WORKTREE=error reason=ledger-unreadable path=$LEDGER_N"
  refute "with no clean sweep claimed"          "$OUT_N2" "WORKTREE=swept"
  refute "and nothing removed"                  "$OUT_N2" "WORKTREE=removed"
  same   "and still exiting zero"               "$RC_N2"  "0"
  expect "the worktree still on disk"           "$(test -d "$N/wt/revloop-wt-u" && echo PRESENT)" "PRESENT"
  same   "and the record still untouched"       "$(cat "$LEDGER_N")" "$N/wt/revloop-wt-u"

  # NOT A DIRECTORY AT ALL. Nothing step 3 does produces this -- it is what a
  # `revloop` clobbered by something else looks like -- and it is the case that
  # separates `[ -e "$G/revloop" ]` from `[ -d "$G/revloop" ]`: the second reads
  # it as "never recorded" and sweeps. There is no record to consult here, so
  # refusing is the fail-closed answer rather than an accurate one.
  mv "$LEDGER_N_DIR" "$LEDGER_N_DIR.aside"
  : > "$LEDGER_N_DIR"
  OUT_N3=$( run_in "$N" ); RC_N3=$?
  rm -f "$LEDGER_N_DIR"; mv "$LEDGER_N_DIR.aside" "$LEDGER_N_DIR"
  expect "a record that is not a directory refuses too" "$OUT_N3" "WORKTREE=error reason=ledger-unreadable path=$LEDGER_N"
  refute "claiming no sweep"                            "$OUT_N3" "WORKTREE=swept"
  same   "and exiting zero"                             "$RC_N3"  "0"
  expect "with the worktree still there"                "$(test -d "$N/wt/revloop-wt-u" && echo PRESENT)" "PRESENT"

  # AND THE REFUSAL IS THE PERMISSIONS, NOT THE FIXTURE. Without this the three
  # cases above are satisfied by a repository the fence could never sweep.
  OUT_N4=$( run_in "$N" )
  expect "and the same repository sweeps once readable" "$OUT_N4" "WORKTREE=removed path=$N/wt/revloop-wt-u"
  expect "saying so on the terminal line"               "$OUT_N4" "WORKTREE=swept removed=1 other=0 ledger=ok"
  same   "and retiring the line it spent"               "$(cat "$LEDGER_N")" ""
fi

# --- a clone of this project is not a measurement worktree ------------------
# THE FIRST OF THE TWO FALSE POSITIVES THE OLD GUARD HAD. `~/src/revloop-wt-client`
# is a plausible clone of a project called revloop. Reading the basename alone,
# the fence called it a measurement worktree, refused the WHOLE sweep and left
# behind every worktree the run had recorded -- the exact leak it exists to close.
# What separates it from a measurement worktree is that it is a MAIN worktree:
# measured at git 2.34.1, a linked worktree's git directory holds a `gitdir` file
# and a main `.git` does not.
L=$(new_repo revloop-wt-client)
git -C "$L" worktree add -q --detach "$L/wt/revloop-wt-a" HEAD

OUT_L1=$( run_in "$L" )
refute "a main checkout of the family name is not one" "$OUT_L1" "reason=inside-worktree"
expect "and it sweeps, owning nothing"                 "$OUT_L1" "WORKTREE=swept removed=0 other=2 ledger=ok"
# It names ITSELF, and that is correct rather than a wart: `worktree list` returns
# the checkout too, its last component is in the family, and no ledger claims it.
expect "naming the checkout it stands in as another's" "$OUT_L1" "WORKTREE=other path=$L"
same   "and creating no ledger on the way"             "$(test -e "$(git -C "$L" rev-parse --absolute-git-dir)/revloop/worktrees.txt" && echo PRESENT)" ""
record "$L" "$L/wt/revloop-wt-a"

OUT_L2=$( run_in "$L" )
expect "and then removes what it recorded"             "$OUT_L2" "WORKTREE=removed path=$L/wt/revloop-wt-a"
expect "with the checkout still only named"            "$OUT_L2" "WORKTREE=swept removed=1 other=1 ledger=ok"
expect "and still on disk"                             "$(test -d "$L/.git" && echo PRESENT)" "PRESENT"

# --- a linked checkout that is somebody's working tree ----------------------
# THE SECOND FALSE POSITIVE, and the one the `gitdir` test alone does not clear:
# a developer's branch checkout at `revloop-wt-fix` IS linked. What separates it
# is that it has recorded worktrees of its own, which no measurement worktree
# ever has -- step 3 records into the git directory of the checkout it is run
# from, never into the worktree it just created.
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
# THE LEDGER'S WORST DAY: a line claiming the checkout the fence is standing in.
# Measured at git 2.34.1, `remove --force` deletes the worktree the shell is in,
# takes the working directory with it and exits 0. The old basename guard used to
# refuse this case on the way past; now that the guard no longer fires here, the
# loop has to refuse it itself.
record "$M/revloop-wt-fix" "$M/revloop-wt-fix"

OUT_M2=$( run_in "$M/revloop-wt-fix" )
expect "the fence never removes what it stands in" "$OUT_M2" "WORKTREE=stuck path=$M/revloop-wt-fix"
expect "and the verdict says so"                   "$OUT_M2" "WORKTREE=partial removed=0 stuck=1 other=0 ledger=ok"
expect "and it is still on disk"                   "$(test -d "$M/revloop-wt-fix" && echo PRESENT)" "PRESENT"
expect "and still registered"                      "$(git -C "$M" worktree list)" "$M/revloop-wt-fix"
same   "and its line is kept, not retired"         "$(cat "$LEDGER_M")" "$M/revloop-wt-fix"

# --- a symlink planted at the temp path -------------------------------------
# THE REWRITE USED TO FOLLOW ONE. `$F.new` is a fixed, derivable name written
# with a plain `>`, so anything able to write the ledger's directory could plant
# a symlink there and have the redirection truncate whatever it pointed at --
# and the `mv` then left THE RECORD ITSELF a symlink to that file, so the next
# run's step 3 appended worktree paths into it and this fence read it back as
# the list of paths its unconditional --force may take. Measured against the
# unfixed fence at git 2.34.1: the victim truncated to zero bytes, the record a
# symlink to it, and `WORKTREE=swept removed=1 other=0 ledger=ok` printed over
# all of it. `rm -f` unlinks the symlink instead of following it, and `set -C`
# makes the redirection O_EXCL so a re-plant in that window fails the write
# rather than winning it -- measured at bash 5.1.16, noclobber refuses an
# existing symlink whether or not its target exists.
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
# WHY THE UNLINK IS THE FIRST LINK OF THE `&&` CHAIN AND NOT A STATEMENT BEFORE
# IT. With the ledger's directory read-only the unlink fails, and a read-only
# DIRECTORY does not stop a write THROUGH a link to a file outside it -- so a
# fence that unlinked, ignored the result and wrote anyway would truncate the
# victim and still report `ledger=error`, naming a failure other than the one
# that happened. Measured at bash 5.1.16. Chained, the failed unlink stops the
# write instead: if the temp path cannot be cleared, nothing is written through
# whatever is standing there. `set -C` is NOT what saves this case and this
# fixture does not measure it -- see `## Unexercised paths`, where it is the
# third guard in this fence that no fixture can turn red.
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
  expect "the removal still happens"                    "$OUT_U" "WORKTREE=removed path=$U/wt/revloop-wt-v"
  expect "and the verdict names the write failure"      "$OUT_U" "ledger=error"
  same   "the record is left exactly as it was"         "$(cat "$LEDGER_U_DIR/worktrees.txt")" "$U/wt/revloop-wt-v"
  same   "and the fence exits zero"                     "$RC_U" "0"
  # THE FENCE'S OUTPUT IS PARSED, so a failing unlink may not narrate itself:
  # `rm` writes `Permission denied` to stderr, and the report reads these lines.
  refute "and says nothing that is not a WORKTREE line" "$OUT_U" "Permission denied"
fi

# --- a symlink planted at the record itself ---------------------------------
# THE OTHER HALF, and the one that decides what the fence READS rather than what
# it writes. `[ -e ]` and `[ -f ]` both follow a symlink, so a record redirected
# at another file passes every test the read guard makes and is then used as the
# authorization list. Refusing is the same fail-closed shape as
# `ledger-unreadable` one level out: a record that is not a regular file is not
# an absent one. Asserted on the victim's BYTES and the worktree's DIRECTORY,
# because the claim is that the fence touched nothing at all.
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

# --- a stale temp file from an earlier run ----------------------------------
# `set -C` refuses an existing REGULAR file too -- measured at bash 5.1.16 -- so
# on its own it would wedge the rewrite into `ledger=error` for good the first
# time a rename failed and left the residue this file's `## Unexercised paths`
# entry describes. The `rm -f` is therefore not decoration on the symlink fix:
# it is what keeps that residue self-clearing, and it narrows the documented
# leftover from permanent to one sweep long.
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
# STEP 3'S TEMPLATE IS `revloop-wt-<slug>`, and an empty slug lands on the one
# string the pattern used to exclude: `?*` demanded a character AFTER the prefix
# while step 3's rule says the component BEGINS WITH it. A run that recorded
# such a path had it skipped in silence -- not removed, not named as another's,
# and its line retired by the rewrite regardless, under a `swept` line. The
# neighbour without the hyphen is still refused, and the pattern's own trailing
# `-` is what does that; the `?*` never was.
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
LEDGER_RULE='`revloop/worktrees.txt`'

expect "remote-loop holds the fence"        "$(found "$FENCE_ID" "$REMOTE")"        "$FENCE_ID"
expect "remote-loop states the name rule"   "$(found "$PREFIX_RULE" "$REMOTE")"     "$PREFIX_RULE"
expect "remote-loop names the ledger"       "$(foundf "$LEDGER_RULE" "$REMOTE")"    "$LEDGER_RULE"
expect "local-loop cites the teardown"      "$(found 'worktree-teardown' "$LOCAL")" "worktree-teardown"
expect "local-loop cites the creation rule" "$(found 'step 3 gives' "$LOCAL")"      "step 3 gives"
expect "local-loop names the ledger too"    "$(foundf "$LEDGER_RULE" "$LOCAL")"     "$LEDGER_RULE"
expect "local-loop names the other class"   "$(found 'WORKTREE=other' "$LOCAL")"    "WORKTREE=other"
refute "local-loop copies no fence"         "$(found 'revloop:fence' "$LOCAL")"     "revloop:fence"

summary "fence-worktree"
