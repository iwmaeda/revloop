#!/usr/bin/env bash
# The four rigor levels and their eight round caps are written out in many
# places. This pins them to one.
#
# `minimal` / `standard` / `thorough` / `exhaustive`, the cap each level supplies
# to each loop, and which level is the default are spelled in `procedures/`, in
# both READMEs, in `docs/configuration.md` and in all seven files under
# `commands/`. Copies drift, and this set had no guard at all: renaming a level
# in the canonical table alone, and separately changing the default's caps from
# `5 / 3` to `6 / 4`, each left `npm test` fully green while every other file
# kept the old value.
#
# THE PROCEDURE IS THE SOURCE, AND THAT IS WHAT DIFFERS FROM
# `severity-ladder.test.sh`. That file derives from the reviewer schema's enum
# because the enum is the copy a machine reads. There is no equivalent here:
# `--rigor` deliberately has no configuration key -- `procedures/rigor-levels.md`
# argues that adding one would be a defect, since a repository that could set it
# would lower its own review bar -- so nothing machine-readable holds these
# values and `procedures/rigor-levels.md` is the authority. Deriving from it
# rather than restating it here is what keeps this file a guard instead of one
# more copy.
#
# TABLES ARE FOUND BY THEIR HEADER, NEVER BY A ROW SHAPE. The spec holds three
# tables whose rows all open with a backticked level -- blocking bands, round
# caps, sweep obligations -- so a matcher keyed on the row alone reads all three
# as one set. Written that way, this file passed while the level table said
# `basic` and the other two said `minimal`: the concatenation still contained the
# expected sequence. Each table is now cut out by a string from its own header
# row and compared on its own.
#
# `same` EXISTS BECAUSE `expect` IS A SUBSTRING CHECK. lib.sh's helper asks
# whether the wanted text appears in the actual, which is right for asserting
# that prose says something and wrong for comparing two extracted sets: a set
# carrying every expected member plus a stray one contains the expectation and
# passes. That is the second half of the same false green above.
#
# CHANGELOG.md IS EXCLUDED, DELIBERATELY. It carries the same table inside the
# 0.8.0 entry, and its own preamble says an entry states what was true when it
# was written. Sweeping it would make every future cap change demand an edit to
# a historical record, which is the opposite of what that file is for.
#
# WHAT THIS DOES NOT CATCH is prose. `docs/configuration.md` says the default's
# numbers "are 5 and 3" in a sentence, and both schema descriptions state the
# default's cap in English. Those are copies and they can drift past this file.
# This is a tripwire for the tabular copies, not a proof about every copy -- the
# same distinction `procedure-refs.test.sh` states about its own citation rules.
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

# --- one table at a time -----------------------------------------------------
# Cut out the rows of the table whose header row holds <marker>, stopping at the
# first line that is not a table row.

rows_of() { # rows_of <file> <header-marker>
  awk -v hdr="$2" '
    /^ *\|/ && index($0, hdr) { t = 1; next }
    t && /^ *\| *-/ { next }
    t && /^ *\|/    { print; next }
    t               { exit }
  ' "$1"
}

# The level is the first cell's backticked word. Everything after it in that
# cell -- `**(default)**`, a Japanese gloss -- is deliberately ignored.
# The backticks are the level's own markup, not command substitution, and the
# pattern has to stay single-quoted for the same reason lint-shell.sh excludes
# SC2016 over the fences: what is inside must reach the tool untouched.
# shellcheck disable=SC2016
level_of() { sed -nE 's/^ *\|[^`]*`([a-z-]+)`.*/\1/p'; }

# The cap pair, wherever it sits and whichever shape it takes. Its column index
# differs between files -- the READMEs carry a sweeps column the others do not --
# so it is found by shape; and the spec splits the pair across two cells where
# every copy merges it into one, so `|N|M|` is normalised to `|N/M|` first.
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

# --- the canonical values ----------------------------------------------------
CAPS=$(table_pairs "$SPEC" 'remote-loop.md')
LEVELS=$(printf '%s\n' "$CAPS" | awk '{print $1}')
# Read through the same row cutter as everything else. A second regex spelling
# the row shape again would be a copy of the extractor, and one that a linter
# reads as command substitution besides -- backticks are the level's own markup.
DEFAULT=$(rows_of "$SPEC" 'remote-loop.md' | grep -F '**(default)**' | level_of)
DEFAULT_BLOCKING=$(rows_of "$SPEC" 'Blocking' | grep -F '**(default)**' | level_of)

# Asserted before anything derived from them is used. An extraction that found
# nothing yields empty sets, and every comparison below then compares nothing to
# nothing -- loud, but for the wrong reason and naming the wrong file.
NCAPS=$(printf '%s\n' "$CAPS" | grep -c . || true)
same "the spec's cap table has four rows" "$NCAPS" "4"
same "and they read minimal to exhaustive" "$(flat "$LEVELS")" "minimal standard thorough exhaustive"
same "one level is marked the default"     "$(flat "$DEFAULT")" "standard"
same "and both tables mark the same one"   "$(flat "$DEFAULT_BLOCKING")" "$(flat "$DEFAULT")"

REMOTE_DEFAULT=$(printf '%s\n' "$CAPS" | awk -v d="$DEFAULT" '$1 == d {print $2}')
LOCAL_DEFAULT=$(printf '%s\n' "$CAPS" | awk -v d="$DEFAULT" '$1 == d {print $3}')

# The spec names the levels three times, once per table. A rename applied to one
# is the cheapest way for the authority to contradict itself, and it is the drift
# an earlier draft of this file read straight past.
same "the blocking table names the same four" \
  "$(flat "$(table_levels "$SPEC" 'Blocking')")" "$(flat "$LEVELS")"
same "the sweep table names the same four" \
  "$(flat "$(table_levels "$SPEC" 'Owed for every class fixed')")" "$(flat "$LEVELS")"

# --- the tabular copies ------------------------------------------------------
COPIES=0
for rel in README.md README.ja.md docs/configuration.md; do
  got=$(table_pairs "$ROOT/$rel" '(remote / local)')
  COPIES=$((COPIES + $(printf '%s\n' "$got" | grep -c . || true)))
  same "$rel repeats the spec's table exactly" "$(flat "$got")" "$(flat "$CAPS")"
done

# A sweep that matched nothing would report three agreements over three empty
# sets. Four levels in each of three files is the floor.
if [ "$COPIES" -ge 12 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d cap cells were found across the copies\n' "$COPIES"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d cap cells found; the sweep is broken\n' "$COPIES"
fi

# --- the commands ------------------------------------------------------------
# `commands.test.sh` asserts that each file offers `--rigor` and cites the spec.
# Neither check reads the numbers beside them, which is how a command could
# advertise a default the file it cites does not carry.

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

# --- no fifth level anywhere -------------------------------------------------
# Broader than comparing the copies row for row: this asks what words appear
# where a level belongs, so a level invented in one file is named even when the
# row-for-row comparison has already failed for some other reason.
STRAY=$(for rel in README.md README.ja.md docs/configuration.md; do
  table_levels "$ROOT/$rel" '(remote / local)'
done | sort -u | grep -vxF "$LEVELS" | sed 's/^/STRAY /' || true)
refute "no copy names a level the spec does not" "$STRAY" "STRAY "

# --- the extractors are predicates, and the corpus cannot witness what they
# --- fail to reject. These are the ways a copy drifts.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

drifted() { # drifted <table-body> -> DRIFT | CLEAN
  printf '| Level | a | Round cap (remote / local) |\n| --- | --- | --- |\n%s\n' "$1" > "$TMP/t.md"
  # Normalised the same way both sides of every comparison above are: piping the
  # raw output would carry a trailing newline the other side never has.
  [ "$(flat "$(table_pairs "$TMP/t.md" '(remote / local)')")" = "$(flat "$CAPS")" ] && echo CLEAN || echo DRIFT
}

# Each candidate is generated FROM the spec's own values under a named mutation,
# never by substituting a literal `5 / 3`. A negative written against today's
# numbers stops testing anything the day those numbers legitimately change -- and
# fails for that reason rather than for the drift it was written to catch.
# The mutation is named rather than handed over as an awk program: a program
# passed through a shell function is a single-quoted string full of `$2`, which
# reads to a linter as a shell expansion that will not expand.
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

# The exact/substring distinction is the other half of the false green, so it is
# asserted as a predicate rather than left to the reader to notice.
exact() { [ "$1" = "$2" ] && echo SAME || echo DIFF; }
subst() { printf '%s' "$1" | grep -qF -- "$2" && echo SAME || echo DIFF; }
expect "a superset is not the same set" "$(exact 'basic standard' 'standard')" DIFF
expect "though it does contain it"      "$(subst 'basic standard' 'standard')" SAME

summary "rigor-levels"
