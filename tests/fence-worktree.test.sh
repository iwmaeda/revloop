#!/usr/bin/env bash
# The teardown fence removes the worktrees a run created and nothing else.
#
# THE CLAIM UNDER TEST IS THE SECOND HALF, NOT THE FIRST. That `git worktree
# remove` removes a worktree is git's behaviour and needs no test here. What
# needs one is the bound: the fence carries an unconditional `--force`, and the
# only thing between that and somebody's uncommitted work is the `revloop-wt-`
# prefix. So every scenario below plants a worktree the fence must NOT touch, and
# the assertion that it survived -- with its directory, not only its
# registration -- is the one this file exists for.
#
# THE FIXTURES ARE THROWAWAY REPOSITORIES, for the reason tests/lib.sh gives
# about the fence harness: the checkout these tests run in is a real branch
# locally and a detached HEAD under GitHub Actions' default PR checkout. It is
# also the only safe place to exercise a command that deletes worktrees --
# pointing this file at the repository it lives in would put
# `git worktree remove --force` one prefix collision away from a developer's own
# tree, which is the collision `revloop-wt-` was chosen to avoid in the first
# place: this project is called revloop, and `../revloop-fix` is a plausible
# worktree name for somebody working on it.
#
# FIVE REPOSITORIES, BECAUSE THE OUTCOMES CANNOT SHARE ONE. The ordinary sweep
# must print no `stuck` at all, so the worktree that produces one cannot stand in
# the same repository as that assertion; the no-prune case must hold a stale
# registration and NO worktree of the run's own, since the claim is about what
# the fence does when it owns nothing; and the two guards need a repository that
# is not one, and a cwd inside a worktree the fence would otherwise delete.
#
# lib.sh's run_fence IS DELIBERATELY NOT USED. It builds its own throwaway
# repository, which this file has to pre-populate with worktrees, and it puts
# tests/bin on PATH for a `gh` stub this fence never calls. run_fence_detached
# exercises a no-branch guard that this fence does not have, because it resolves
# no pull request. Neither absence is an oversight.
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

# --- the ordinary sweep -----------------------------------------------------
A=$(new_repo ordinary)
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-base" HEAD
git -C "$A" worktree add -q --detach "$A/wt/mine" HEAD
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-gone" HEAD
# A path that CONTAINS the prefix without ending in it. The fence matches the
# last component, and a version that matched the whole path would take this one
# with it -- which is how a prefix rule quietly becomes a substring rule.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt-outer/inner" HEAD
# The prefix with nothing after it. The `?*` in the fence's case pattern is what
# refuses this, and without a fixture nothing would notice it being dropped.
git -C "$A" worktree add -q --detach "$A/wt/revloop-wt" HEAD
# Untracked output is what a baseline worktree accumulates -- a build, a linked
# node_modules -- and it is what plain `remove` refuses on: measured, one such
# file is enough for exit 128. Without this the --force is untested and anyone
# could drop it.
echo built > "$A/wt/revloop-wt-base/artifact.txt"
# A registration whose directory is gone. `/tmp` cleared between sessions is the
# measured way this arrives. It is here to pin the reason the fence carries no
# `git worktree prune`: `remove --force` already deregisters this state, so a
# prune would add nothing while reaching past the prefix -- which the third
# repository below is what actually proves.
rm -rf "$A/wt/revloop-wt-gone"

OUT_A=$( cd "$A" && bash "$FENCE" 2>&1 ); RC_A=$?
LIST_A=$( git -C "$A" worktree list )

expect "the created worktree is removed"       "$OUT_A"  "WORKTREE=removed path=$A/wt/revloop-wt-base"
expect "a stale registration goes with it"     "$OUT_A"  "WORKTREE=removed path=$A/wt/revloop-wt-gone"
expect "the sweep reports success once"        "$OUT_A"  "WORKTREE=swept removed=2"
refute "an ordinary sweep reports nothing stuck" "$OUT_A" "WORKTREE=stuck"
same   "the fence exits zero"                  "$RC_A"   "0"
refute "the created worktree is deregistered"  "$LIST_A" "revloop-wt-base"
refute "the stale registration is deregistered" "$LIST_A" "revloop-wt-gone"
# THE ASSERTIONS THIS FILE IS FOR. A worktree of another name keeps both its
# registration and its directory: --force is bounded by the prefix, not by
# anything git checks.
expect "a worktree of another name is left registered" "$LIST_A" "$A/wt/mine"
expect "and is left on disk"                   "$(test -d "$A/wt/mine" && echo PRESENT)" "PRESENT"
expect "a nested path keeps its registration"  "$LIST_A" "$A/wt/revloop-wt-outer/inner"
expect "and its directory"                     "$(test -d "$A/wt/revloop-wt-outer/inner" && echo PRESENT)" "PRESENT"
expect "the bare prefix is not a match"        "$LIST_A" "$A/wt/revloop-wt "
expect "and keeps its directory too"           "$(test -d "$A/wt/revloop-wt" && echo PRESENT)" "PRESENT"
expect "the repository's own checkout survives" "$(test -d "$A/.git" && echo PRESENT)" "PRESENT"

# --- a removal that fails ---------------------------------------------------
B=$(new_repo stuck)
git -C "$B" worktree add -q --detach "$B/wt/revloop-wt-locked" HEAD
git -C "$B" worktree add -q --detach "$B/wt/keep" HEAD
git -C "$B" worktree lock "$B/wt/revloop-wt-locked"

OUT_B=$( cd "$B" && bash "$FENCE" 2>&1 ); RC_B=$?
LIST_B=$( git -C "$B" worktree list )

expect "a refused removal is named"            "$OUT_B"  "WORKTREE=stuck path=$B/wt/revloop-wt-locked"
expect "and the verdict says so"               "$OUT_B"  "WORKTREE=partial removed=0 stuck=1"
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

OUT_C=$( cd "$C" && bash "$FENCE" 2>&1 )
LIST_C=$( git -C "$C" worktree list )

expect "a run that owns nothing says so"       "$OUT_C"  "WORKTREE=swept removed=0"
expect "and leaves a stale registration alone" "$LIST_C" "$C/wt/theirs"

# --- the two guards ---------------------------------------------------------
# Outside a repository `git worktree list` exits 128 and prints no rows, so an
# unguarded loop would remove nothing and print the success line over a
# repository it never read.
mkdir -p "$TMP/notrepo"
OUT_D=$( cd "$TMP/notrepo" && bash "$FENCE" 2>&1 ); RC_D=$?
expect "outside a repository the fence says so" "$OUT_D" "WORKTREE=error reason=not-a-repo"
refute "and never claims a sweep"              "$OUT_D"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_D"   "0"

# Measured: `git worktree remove --force` will delete the worktree the shell is
# standing in, exit 0, and take the working directory with it.
E=$(new_repo cwd)
git -C "$E" worktree add -q --detach "$E/wt/revloop-wt-self" HEAD
OUT_E=$( cd "$E/wt/revloop-wt-self" && bash "$FENCE" 2>&1 )
expect "the fence refuses to delete its own cwd" "$OUT_E" "WORKTREE=stuck reason=cwd path=$E/wt/revloop-wt-self"
expect "and reports the sweep as partial"      "$OUT_E"  "WORKTREE=partial removed=0 stuck=1"
expect "and the directory is still there"      "$(test -d "$E/wt/revloop-wt-self" && echo PRESENT)" "PRESENT"

# --- the rule is written in both procedures ---------------------------------
#
# A tripwire, not a proof: it asks whether each file still says a run sweeps what
# it created, because the fence is in one file and the obligation has to reach
# the other. local-loop.md cites rather than copies -- tests/extract-fences.sh
# reads remote-loop.md alone, so a copied fence would sit outside the hash pin,
# outside lint:sh, and outside every assertion above.
REMOTE="$ROOT/procedures/remote-loop.md"
LOCAL="$ROOT/procedures/local-loop.md"
found() { grep -o "$1" "$2" | head -1; }   # presence, never a count: a count of 12 contains "1"
FENCE_ID='revloop:fence id=worktree-teardown'
# The backticks are the procedures' own markup and must reach grep unevaluated,
# which is why the phrase is written once, in single quotes, rather than inline
# at two call sites.
# shellcheck disable=SC2016
PREFIX_RULE='`revloop-wt-`'

expect "remote-loop holds the fence"        "$(found "$FENCE_ID" "$REMOTE")"        "$FENCE_ID"
expect "remote-loop states the prefix rule" "$(found "$PREFIX_RULE" "$REMOTE")"     "$PREFIX_RULE"
expect "local-loop cites the teardown"      "$(found 'worktree-teardown' "$LOCAL")" "worktree-teardown"
expect "local-loop cites the creation rule" "$(found 'step 3 gives' "$LOCAL")"      "step 3 gives"
refute "local-loop copies no fence"         "$(found 'revloop:fence' "$LOCAL")"     "revloop:fence"

summary "fence-worktree"
