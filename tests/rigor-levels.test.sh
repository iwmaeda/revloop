#!/usr/bin/env bash
# The four rigor levels, their round caps and the default must agree wherever
# they are tabulated. procedures/rigor-levels.md is the source. README.md,
# README.ja.md, docs/configuration.md and commands/*.md are compared against it.
# Copies of the numbers in prose are not checked.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

echo "rigor-levels:"

SPEC="$ROOT/procedures/rigor-levels.md"

same() { # same <label> <actual> <expected> -- exact, unlike lib.sh's substring expect
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$3" "$2"
  fi
}

# --- one table at a time ---
# Rows of the table whose header row holds <marker>. The spec has three tables
# with the same row shape, so a table is selected by its header.

rows_of() { # rows_of <file> <header-marker>
  awk -v hdr="$2" '
    /^ *\|/ && index($0, hdr) { t = 1; next }
    t && /^ *\| *-/ { next }
    t && /^ *\|/    { print; next }
    t               { exit }
  ' "$1"
}

# The level is the first cell's backticked word. The rest of the cell is ignored.
# shellcheck disable=SC2016
level_of() { sed -nE 's/^ *\|[^`]*`([a-z-]+)`.*/\1/p'; }

# The cap pair, found by shape because its column differs between files. The spec
# splits it over two cells, so `|N|M|` is normalised to `|N/M|` first.
pair_of() { # -> "<remote> <local>" or nothing
  sed -E 's/[[:space:]]+//g; s/\|([0-9]+)\|([0-9]+)\|/|\1\/\2|/' |
    grep -oE '\|[0-9]+/[0-9]+\|' | head -1 | tr -d '|' | tr '/' ' '
}

table_pairs() { # table_pairs <file> <header-marker> -> "<level> <remote> <local>" per row
  local row
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    local lvl pair
    lvl=$(printf '%s\n' "$row" | level_of)
    pair=$(printf '%s\n' "$row" | pair_of)
    [ -n "$pair" ] && printf '%s %s\n' "$lvl" "$pair"
  done < <(rows_of "$1" "$2")
}

table_levels() { # table_levels <file> <header-marker> -> "<level>" per row
  rows_of "$1" "$2" | level_of
}

flat() { printf '%s' "$1" | tr '\n' ' '; }

# --- the canonical values ---
CAPS=$(table_pairs "$SPEC" 'remote-loop.md')
LEVELS=$(printf '%s\n' "$CAPS" | awk '{print $1}')

DEFAULT=$(rows_of "$SPEC" 'remote-loop.md' | grep -F '**(default)**' | level_of)
DEFAULT_BLOCKING=$(rows_of "$SPEC" 'Blocking' | grep -F '**(default)**' | level_of)

# Checked first: an empty extraction would compare nothing to nothing below.
NCAPS=$(printf '%s\n' "$CAPS" | grep -c . || true)
same "the spec's cap table has four rows" "$NCAPS" "4"
same "and they read minimal to exhaustive" "$(flat "$LEVELS")" "minimal standard thorough exhaustive"
same "one level is marked the default"     "$(flat "$DEFAULT")" "standard"
same "and both tables mark the same one"   "$(flat "$DEFAULT_BLOCKING")" "$(flat "$DEFAULT")"

REMOTE_DEFAULT=$(printf '%s\n' "$CAPS" | awk -v d="$DEFAULT" '$1 == d {print $2}')
LOCAL_DEFAULT=$(printf '%s\n' "$CAPS" | awk -v d="$DEFAULT" '$1 == d {print $3}')

# The spec names the levels once per table.
same "the blocking table names the same four" \
  "$(flat "$(table_levels "$SPEC" 'Blocking')")" "$(flat "$LEVELS")"
same "the sweep table names the same four" \
  "$(flat "$(table_levels "$SPEC" 'Owed for every class fixed')")" "$(flat "$LEVELS")"

# --- the tabular copies ---
COPIES=0
for rel in README.md README.ja.md docs/configuration.md; do
  got=$(table_pairs "$ROOT/$rel" '(remote / local)')
  COPIES=$((COPIES + $(printf '%s\n' "$got" | grep -c . || true)))
  same "$rel repeats the spec's table exactly" "$(flat "$got")" "$(flat "$CAPS")"
done

# Floor: four levels in each of three files.
if [ "$COPIES" -ge 12 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d cap cells were found across the copies\n' "$COPIES"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d cap cells found; the sweep is broken\n' "$COPIES"
fi

# --- the commands' --rigor and --max-rounds defaults ---

flag_default() { # flag_default <file> <flag> -> the default cell, backticks stripped
  awk -F'|' -v f="$2" '
    index($2, "`" f) { d = $3; gsub(/`/, "", d); gsub(/^ +| +$/, "", d); print d; exit }
  ' "$1"
}

CMDS=0
for f in "$ROOT"/commands/*.md; do
  name=$(basename "$f")
  case "$name" in
    remote-*) want_cap="$REMOTE_DEFAULT" ;;
    local-*)  want_cap="$LOCAL_DEFAULT"  ;;
    *) FAIL=$((FAIL + 1)); printf '  FAIL %s matches neither loop family\n' "$name"; continue ;;
  esac
  CMDS=$((CMDS + 1))
  same "$name defaults --rigor to the spec's default" "$(flag_default "$f" '--rigor')" "$DEFAULT"
  same "$name defaults --max-rounds to that level's cap" "$(flag_default "$f" '--max-rounds')" "$want_cap"
done

if [ "$CMDS" -ge 7 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d commands were checked\n' "$CMDS"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d commands checked\n' "$CMDS"
fi

# --- no fifth level anywhere ---
STRAY=$(for rel in README.md README.ja.md docs/configuration.md; do
  table_levels "$ROOT/$rel" '(remote / local)'
done | sort -u | grep -vxF "$LEVELS" | sed 's/^/STRAY /' || true)
refute "no copy names a level the spec does not" "$STRAY" "STRAY "

# --- the extractors against drifted copies ---
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

drifted() { # drifted <table-body> -> DRIFT | CLEAN
  printf '| Level | a | Round cap (remote / local) |\n| --- | --- | --- |\n%s\n' "$1" > "$TMP/t.md"
  [ "$(flat "$(table_pairs "$TMP/t.md" '(remote / local)')")" = "$(flat "$CAPS")" ] && echo CLEAN || echo DRIFT
}

# Candidates are generated from the spec's own values under a named mutation, so
# the cases survive a change to the numbers.
gen() { # gen <mutation> -> a copy of the spec's table, mutated one named way
  printf '%s\n' "$CAPS" | awk -v m="$1" '
    m == "rename" && NR == 1 { $1 = "basic" }
    m == "bump"   && NR == 2 { $2 = $2 + 1 }
    m == "swap"   && NR == 3 { t = $2; $2 = $3; $3 = t }
    m == "drop"   && NR == 4 { next }
    { printf "| `%s` | x | %s / %s |\n", $1, $2, $3 }'
}

expect "an agreeing copy is clean"  "$(drifted "$(gen none)")"        CLEAN
expect "a changed cap drifts"       "$(drifted "$(gen bump)")"        DRIFT
expect "a renamed level drifts"     "$(drifted "$(gen rename)")"      DRIFT
expect "a dropped row drifts"       "$(drifted "$(gen drop)")"        DRIFT
expect "a swapped pair drifts"      "$(drifted "$(gen swap)")"        DRIFT
expect "a reordered table drifts"   "$(drifted "$(gen none | tac)")"  DRIFT

# A superset contains the expectation without being equal to it.
exact() { [ "$1" = "$2" ] && echo SAME || echo DIFF; }
subst() { printf '%s' "$1" | grep -qF -- "$2" && echo SAME || echo DIFF; }
expect "a superset is not the same set" "$(exact 'basic standard' 'standard')" DIFF
expect "though it does contain it"      "$(subst 'basic standard' 'standard')" SAME

summary "rigor-levels"
