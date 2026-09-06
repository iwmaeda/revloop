#!/usr/bin/env bash
# The teardown fence removes the worktrees THIS RUN created, and nothing else.
#
# THE CLAIM UNDER TEST IS THE SECOND HALF, NOT THE FIRST. That `git worktree
# remove` removes a worktree is git's behaviour and needs no test here. What
# needs one is the bound: the fence carries an unconditional `--force`, and the
# only thing between that and somebody's uncommitted work is the name it matches
# on. So every scenario below plants a worktree the fence must NOT touch, and
# the assertion that it survived -- with its directory, not only its
# registration -- is the one this file exists for.
#
# THERE ARE TWO BYSTANDER CLASSES, AND THE SECOND IS WHY THE NAME CARRIES A RUN
# ID. `git worktree list` answers for the whole repository, so a second loop
# running against it at the same time has its worktrees in the same list; a
# fence bounded by `revloop-wt-` alone would `--force` the measurement that run
# is standing in. The fence matches `revloop-wt-$PPID-` and prints
# `WORKTREE=other` for anything else under the prefix, so each repository below
# plants a neighbouring run's worktree as well as a stranger's.
#
# RUNNING THE FENCE MEANS OWNING THE $PPID IT MATCHES ON, so the fixtures cannot
# be named before the shell that will run it exists. `run_scoped` is that shell:
# it prints the id it is about to lend the fence, calls a setup function with
# it, and then runs the fence. Its trailing `exit $?` is load-bearing -- bash may
# exec the last command of a subshell in place of the subshell, which would
# reparent the fence and change the id it matches on.
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

run_scoped() { # run_scoped <repo> <setup-fn> -> RUNPID=<id>, then the fence's output
  ( cd "$1" || exit 99
    echo "RUNPID=$BASHPID"
    "$2" "$1" "$BASHPID" || exit 98
    bash "$FENCE" 2>&1
    exit $? )    # NOT the last command by accident -- see the header
}

run_id() { # run_id <output> -> the id the fence ran under
  printf '%s\n' "$1" | sed -n 's/^RUNPID=//p' | head -1
}

# --- the ordinary sweep -----------------------------------------------------
# The neighbouring run is `$id + 1` rather than a constant, because a constant
# is one collision away from being the id the fence is actually running under,
# and that collision would make this file green for the wrong reason.
plant_ordinary() { # plant_ordinary <repo> <run-id>
  o=$(( $2 + 1 ))
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$2-base" HEAD
  git -C "$1" worktree add -q --detach "$1/wt/mine" HEAD
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$2-gone" HEAD
  # A path that CONTAINS the prefix without ending in it. The fence matches the
  # last component, and a version that matched the whole path would take this one
  # with it -- which is how a prefix rule quietly becomes a substring rule.
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$2-outer/inner" HEAD
  # The prefix with nothing after it. The `?*` in the fence's case patterns is
  # what refuses this, and without a fixture nothing would notice it being
  # dropped.
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt" HEAD
  # ANOTHER RUN'S, live and dirty: this is the one the prefix alone would delete.
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$o-base" HEAD
  echo measuring > "$1/wt/revloop-wt-$o-base/artifact.txt"
  # And another run's stale registration. `remove --force` would deregister it
  # and a `prune` would too; the run id is what keeps the fence away from both.
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$o-gone" HEAD
  # Untracked output is what a baseline worktree accumulates -- a build, a linked
  # node_modules -- and it is what plain `remove` refuses on: measured, one such
  # file is enough for exit 128. Without this the --force is untested and anyone
  # could drop it.
  echo built > "$1/wt/revloop-wt-$2-base/artifact.txt"
  # A registration whose directory is gone. `/tmp` cleared between sessions is
  # the measured way this arrives. It is here to pin the reason the fence carries
  # no `git worktree prune`: `remove --force` already deregisters this state, so
  # a prune would add nothing while reaching past the name -- which the third
  # repository below is what actually proves.
  rm -rf "$1/wt/revloop-wt-$2-gone" "$1/wt/revloop-wt-$o-gone"
}

A=$(new_repo ordinary)
OUT_A=$( run_scoped "$A" plant_ordinary ); RC_A=$?
ID_A=$(run_id "$OUT_A"); OTHER_A=$(( ID_A + 1 ))
LIST_A=$( git -C "$A" worktree list )

expect "the created worktree is removed"       "$OUT_A"  "WORKTREE=removed path=$A/wt/revloop-wt-$ID_A-base"
expect "a stale registration goes with it"     "$OUT_A"  "WORKTREE=removed path=$A/wt/revloop-wt-$ID_A-gone"
expect "the sweep reports success once"        "$OUT_A"  "WORKTREE=swept removed=2 other=2"
refute "an ordinary sweep reports nothing stuck" "$OUT_A" "WORKTREE=stuck"
same   "the fence exits zero"                  "$RC_A"   "0"
refute "the created worktree is deregistered"  "$LIST_A" "revloop-wt-$ID_A-base"
refute "the stale registration is deregistered" "$LIST_A" "revloop-wt-$ID_A-gone"
# THE ASSERTIONS THIS FILE IS FOR. A worktree of another name keeps both its
# registration and its directory: --force is bounded by the name, not by
# anything git checks.
expect "a worktree of another name is left registered" "$LIST_A" "$A/wt/mine"
expect "and is left on disk"                   "$(test -d "$A/wt/mine" && echo PRESENT)" "PRESENT"
expect "a nested path keeps its registration"  "$LIST_A" "$A/wt/revloop-wt-$ID_A-outer/inner"
expect "and its directory"                     "$(test -d "$A/wt/revloop-wt-$ID_A-outer/inner" && echo PRESENT)" "PRESENT"
expect "the bare prefix is not a match"        "$LIST_A" "$A/wt/revloop-wt "
expect "and keeps its directory too"           "$(test -d "$A/wt/revloop-wt" && echo PRESENT)" "PRESENT"
refute "and is not counted as another run's"   "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt "
# AND THE SAME ASSERTIONS FOR THE RUN NEXT DOOR. This is the concurrency bound:
# two loops share a repository and therefore share `git worktree list`, so the
# prefix alone is not a bound at all.
expect "a neighbouring run's worktree is named" "$OUT_A" "WORKTREE=other path=$A/wt/revloop-wt-$OTHER_A-base"
expect "and left registered"                   "$LIST_A" "$A/wt/revloop-wt-$OTHER_A-base"
expect "and left on disk, dirty"               "$(test -f "$A/wt/revloop-wt-$OTHER_A-base/artifact.txt" && echo PRESENT)" "PRESENT"
expect "its stale registration is named too"   "$OUT_A"  "WORKTREE=other path=$A/wt/revloop-wt-$OTHER_A-gone"
expect "and survives, which no prune would allow" "$LIST_A" "$A/wt/revloop-wt-$OTHER_A-gone"
expect "the repository's own checkout survives" "$(test -d "$A/.git" && echo PRESENT)" "PRESENT"

# --- a removal that fails ---------------------------------------------------
plant_stuck() { # plant_stuck <repo> <run-id>
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$2-locked" HEAD
  git -C "$1" worktree add -q --detach "$1/wt/keep" HEAD
  git -C "$1" worktree lock "$1/wt/revloop-wt-$2-locked"
}

B=$(new_repo stuck)
OUT_B=$( run_scoped "$B" plant_stuck ); RC_B=$?
ID_B=$(run_id "$OUT_B")
LIST_B=$( git -C "$B" worktree list )

expect "a refused removal is named"            "$OUT_B"  "WORKTREE=stuck path=$B/wt/revloop-wt-$ID_B-locked"
expect "and the verdict says so"               "$OUT_B"  "WORKTREE=partial removed=0 stuck=1 other=0"
# THE TOKEN SEPARATION. A failure verdict that contained the success token would
# make every `grep -q swept` true on a sweep that left something behind -- the
# hazard step 12 spends a paragraph on for CHECKS_FAILED and NOT_ALL_PASS.
refute "a failed sweep never claims success"   "$OUT_B"  "WORKTREE=swept"
same   "and still exits zero"                  "$RC_B"   "0"
expect "the stuck worktree is still there"     "$LIST_B" "revloop-wt-$ID_B-locked"
expect "and the bystander is untouched"        "$LIST_B" "$B/wt/keep"

# --- the fence owns nothing, and touches nothing ----------------------------
# The no-prune claim, which is the one thing a `git worktree prune` in this fence
# would break: a registration of SOMEBODY ELSE'S whose directory is missing --
# an unmounted drive, an encrypted volume before unlock -- must survive a run
# that created no worktree of its own.
plant_bystander_stale() { # plant_bystander_stale <repo> <run-id>
  git -C "$1" worktree add -q --detach "$1/wt/theirs" HEAD
  rm -rf "$1/wt/theirs"
}

C=$(new_repo bystander-stale)
OUT_C=$( run_scoped "$C" plant_bystander_stale )
LIST_C=$( git -C "$C" worktree list )

expect "a run that owns nothing says so"       "$OUT_C"  "WORKTREE=swept removed=0 other=0"
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
plant_cwd() { # plant_cwd <repo> <run-id>
  git -C "$1" worktree add -q --detach "$1/wt/revloop-wt-$2-self" HEAD
  cd "$1/wt/revloop-wt-$2-self" || return 1
}

E=$(new_repo cwd)
OUT_E=$( run_scoped "$E" plant_cwd )
ID_E=$(run_id "$OUT_E")
expect "the fence refuses to delete its own cwd" "$OUT_E" "WORKTREE=stuck reason=cwd path=$E/wt/revloop-wt-$ID_E-self"
expect "and reports the sweep as partial"      "$OUT_E"  "WORKTREE=partial removed=0 stuck=1 other=0"
expect "and the directory is still there"      "$(test -d "$E/wt/revloop-wt-$ID_E-self" && echo PRESENT)" "PRESENT"

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
foundf() { grep -oF "$1" "$2" | head -1; }   # fixed-string, for a pattern carrying `$`
FENCE_ID='revloop:fence id=worktree-teardown'
# The backticks are the procedures' own markup and must reach grep unevaluated,
# which is why the phrase is written once, in single quotes, rather than inline
# at two call sites. `$PPID` has to survive the same way, and it is the reason
# the run-scoped rule is asserted with -F rather than as a regex.
# shellcheck disable=SC2016
PREFIX_RULE='`revloop-wt-`'
# shellcheck disable=SC2016
SCOPED_RULE='`revloop-wt-$PPID-`'

expect "remote-loop holds the fence"        "$(found "$FENCE_ID" "$REMOTE")"        "$FENCE_ID"
expect "remote-loop states the prefix rule" "$(found "$PREFIX_RULE" "$REMOTE")"     "$PREFIX_RULE"
expect "remote-loop scopes it to the run"   "$(foundf "$SCOPED_RULE" "$REMOTE")"    "$SCOPED_RULE"
expect "local-loop cites the teardown"      "$(found 'worktree-teardown' "$LOCAL")" "worktree-teardown"
expect "local-loop cites the creation rule" "$(found 'step 3 gives' "$LOCAL")"      "step 3 gives"
expect "local-loop names the other class"   "$(found 'WORKTREE=other' "$LOCAL")"    "WORKTREE=other"
refute "local-loop copies no fence"         "$(found 'revloop:fence' "$LOCAL")"     "revloop:fence"

summary "fence-worktree"
