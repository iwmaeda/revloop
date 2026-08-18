#!/usr/bin/env bash
# Runs every fence test. Exit code is the gate CI uses.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rc=0
for t in "$ROOT"/tests/*.test.sh; do
  bash "$t" || rc=1
  echo
done
[ "$rc" -eq 0 ] && echo "all fence tests passed" || echo "FENCE TESTS FAILED"
exit "$rc"
