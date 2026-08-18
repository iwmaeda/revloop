# Shared helpers for the fence tests.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

# Extract a fence and shrink its wall-clock budget so tests finish in seconds.
# This changes only durations, never logic. If either substitution stops
# matching, the fence changed shape and the accelerator must be revisited —
# so we fail loudly instead of silently testing the un-accelerated fence.
extract_accelerated() {
  local id="$1" out="$2" src
  src="$("$ROOT/tests/extract-fences.sh" "$id")"
  case "$id" in
    wait-verdict)
      printf '%s\n' "$src" | grep -q 'SECONDS + 480' || { echo "accel: budget pattern missing in $id" >&2; exit 2; }
      src="${src//SECONDS + 480/SECONDS + ${ACCEL_BUDGET:-3}}"
      src="${src//waited=480/waited=accel}"
      ;;
    wait-ci)
      printf '%s\n' "$src" | grep -q 'seq 1 20' || { echo "accel: loop pattern missing in $id" >&2; exit 2; }
      src="${src//seq 1 20/seq 1 ${ACCEL_CI_ITERS:-2}}"
      ;;
  esac
  printf '%s\n' "$src" | grep -q 'sleep 30' && src="${src//sleep 30/sleep 1}"
  printf '%s\n' "$src" > "$out"
}

run_fence() { # run_fence <script> <fixture-dir>
  REVLOOP_FIXTURE="$2" PATH="$ROOT/tests/bin:$PATH" bash "$1" 2>/dev/null
}

expect() { # expect <label> <actual> <expected-substring>
  if printf '%s' "$2" | grep -qF -- "$3"; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want substring: %s\n       got: %s\n' "$1" "$3" "$2"
  fi
}

refute() { # refute <label> <actual> <forbidden-substring>
  if printf '%s' "$2" | grep -qF -- "$3"; then
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       forbidden substring present: %s\n       got: %s\n' "$1" "$3" "$2"
  else
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  fi
}

summary() {
  printf '%s: %d passed, %d failed\n' "$1" "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
