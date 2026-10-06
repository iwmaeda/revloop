#!/usr/bin/env bash
# Exercises the merge fence against tests/fixtures/merge. The gate re-checks CI
# itself, so the assertions that matter are whether the PUT was fired.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
"$ROOT/tests/extract-fences.sh" merge > "$TMP/f.sh"
FX="$ROOT/tests/fixtures/merge"

# The fence pins sha= from HEAD, so it runs in a throwaway repository.
git init -q "$TMP/repo"
git -C "$TMP/repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init

r() { # r <fixture>  -> sets $out and $puts
  : > "$TMP/put.log"
  out=$(cd "$TMP/repo" && REVLOOP_FIXTURE="$FX/$1" REVLOOP_PUT_LOG="$TMP/put.log" \
        PATH="$ROOT/tests/bin:$PATH" bash "$TMP/f.sh" 2>/dev/null)
  puts=$(wc -l < "$TMP/put.log")
}

echo "merge:"

r ok
expect "green CI -> MERGE=ok"                    "$out" "MERGE=ok"
expect "  pins the sha it checked"               "$out" "sha="
expect "  reports the verified state"            "$out" "state=MERGED 2026-08-19T11:00:00Z"
expect "  the PUT was fired"                     "$puts" "1"

r ci-failed
expect "failed CI -> abort"                      "$out" "MERGE=abort reason=ci-failed"
expect "  the PUT was NOT fired"                 "$puts" "0"
expect "  the failing rows are printed"          "$out" "COMPLETED FAILURE test"

r ci-pending
expect "in-flight CI -> abort"                   "$out" "MERGE=abort reason=ci-not-ready"
expect "  the PUT was NOT fired"                 "$puts" "0"

# A 409 leaves the PR open. The fence must read the state back.
r put-409
expect "409 -> MERGE=failed, not ok"             "$out" "MERGE=failed"
refute "  never reported as merged"              "$out" "MERGE=ok"
expect "  surfaces the response body"            "$out" "Head branch was modified"
expect "  reports the state it read back"        "$out" "state=OPEN null"

# A detached HEAD leaves `--head` empty, which gh reads as no filter. The gate
# must stop before its CI re-check and the PUT.
: > "$TMP/put.log"
export REVLOOP_PUT_LOG="$TMP/put.log"
out=$(run_fence_detached "$TMP/f.sh" "$FX/ok")
unset REVLOOP_PUT_LOG
puts=$(wc -l < "$TMP/put.log")
expect "detached HEAD -> abort"                  "$out" "MERGE=abort reason=no-branch"
expect "  the PUT was NOT fired"                 "$puts" "0"
refute "  never reported as merged"              "$out" "MERGE=ok"

summary "merge"
