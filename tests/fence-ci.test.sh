#!/usr/bin/env bash
# Exercises the wait-ci fence. Green is asserted only for literal SUCCESS on
# every row; everything else must fall back to retry or to an explicit error.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
extract_accelerated wait-ci "$TMP/f.sh"
FX="$ROOT/tests/fixtures/ci"
r() { run_fence "$TMP/f.sh" "$FX/$1"; }

echo "wait-ci:"

o=$(r all-pass);      expect "all SUCCESS -> ALL_PASS"           "$o" "ALL_PASS"
o=$(r checks-failed); expect "a FAILURE -> CHECKS_FAILED"        "$o" "CHECKS_FAILED"
refute "  failure token does not contain ALL_PASS"               "$(printf 'CHECKS_FAILED')" "ALL_PASS"
o=$(r skipped);       expect "SKIPPED stops green"               "$o" "CHECKS_FAILED"
refute "  SKIPPED is not reported as green"                      "$o" "$(printf 'ALL_PASS\n')"

# A check name containing spaces must not shift the status columns.
o=$(r spaces)
expect "space in a check name -> still FAILED"                   "$o" "CHECKS_FAILED"
expect "  the offending row is printed"                          "$o" "Workers Builds: widgets"

o=$(r pending); expect "in-flight checks -> retry then timeout"  "$o" "CI_WAIT=timeout"
expect "  the last rows are printed for diagnosis"               "$o" "IN_PROGRESS"
o=$(r empty);   expect "zero rows -> timeout, never green"       "$o" "CI_WAIT=timeout"
refute "  zero rows is not green"                                "$o" "ALL_PASS"
o=$(r no-pr);   expect "no open PR -> no-pr"                     "$o" "CI_WAIT=error reason=no-pr"

o=$(run_fence_detached "$TMP/f.sh" "$FX/all-pass")
expect "detached HEAD -> no-branch"                              "$o" "CI_WAIT=error reason=no-branch"
refute "  a stranger's green CI is not adopted"                  "$o" "ALL_PASS"

o=$(ACCEL_CI_ITERS=20 bash -c '. "$1"; extract_accelerated wait-ci "$2/f2.sh"; run_fence "$2/f2.sh" "$3/api-fail"' _ "$ROOT/tests/lib.sh" "$TMP" "$FX")
expect "5 consecutive fetch failures -> api"                     "$o" "CI_WAIT=error reason=api"

summary "wait-ci"
