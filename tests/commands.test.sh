#!/usr/bin/env bash
# Guards the shape the reviewer-per-command split introduced.
#
# The old surface was two commands and a `--reviewer` string, and the string was
# the defect: a flag that selects a reviewer is a flag that can select the wrong
# one, and nothing could check that the flags a command advertised were the flags
# it could act on. There are seven commands now and each names one reviewer, so
# the questions this file asks are new ones -- does every command advertise
# exactly the flags it offers, does every definition have exactly one driver, and
# does every command still point at a procedure that exists.
#
# THE THINNESS GUARDS ARE THE POINT, NOT A TIDINESS RULE. Seven files that each
# restated a step would be seven copies of the thing this repository keeps in one
# place, and `permissions.test.sh` splits its own axes on the assumption that the
# runnable text is in `procedures/` and the grants are in `commands/`. The no-bash
# guard below is what makes that split true rather than merely intended.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "commands:"

CMDS=("$ROOT"/commands/*.md)

# An unexpanded glob is a single path that does not exist. Every sweep below
# would then read nothing and pass, which is the "green over an empty corpus"
# hole every other suite in this directory guards for.
if [ ! -f "${CMDS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
  summary "commands"
  exit 1
fi

# One per shipped reviewer, plus the two that take a definition. A glob matching
# three satisfies the guard above while leaving four reviewers undriven.
if [ "${#CMDS[@]}" -ge 7 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d commands were found\n' "${#CMDS[@]}"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d commands found\n' "${#CMDS[@]}"
fi

fm() { awk 'NR==1 { if ($0 != "---") exit; next } /^---$/ { exit } { print }' "$1"; }

# A flag is a whole token. `--merge` must not match inside `--merge-method`, and
# the bare word "merge" in "never merges" must not match at all -- the negatives
# below are the assertions that matter most in this file, and a matcher that
# fired on a substring would make them pass while the flag was really there.
hasflag() { # hasflag <text> <flag> -> YES | NO
  if printf '%s' "$1" | grep -qE "(^|[^A-Za-z0-9-])$2([^A-Za-z0-9-]|\$)"; then echo YES; else echo NO; fi
}

# --- the matcher is a predicate, and the corpus cannot witness what it fails to
# --- reject. These are the four ways it goes wrong.
expect "a bare flag matches"            "$(hasflag 'run with --merge now' '--merge')"        YES
expect "a flag in a code span matches"  "$(hasflag "the \`--merge\` flag" '--merge')"        YES
refute "a longer flag does not match"   "$(hasflag 'pass --merge-method'  '--merge')"        YES
refute "the bare word does not match"   "$(hasflag 'this never merges'    '--merge')"        YES
refute "a prefixed flag does not match" "$(hasflag 'pass --no-merge'      '--merge')"        YES

# --- frontmatter, per file rather than in aggregate ------------------------
#
# Aggregated, one command with no frontmatter at all hides behind six that have
# it -- the same hole `permissions.test.sh` closed when it stopped concatenating.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  head=$(fm "$f")
  expect "$name declares a description"      "$head" "description:"
  expect "$name declares an argument-hint"   "$head" "argument-hint:"
  expect "$name is not model-invocable"      "$head" "disable-model-invocation: true"
  expect "$name grants allowed-tools"        "$head" "allowed-tools:"
done

# --- the flag matrix -------------------------------------------------------
#
# Read from two places that must agree: the `argument-hint`, which is what the
# host shows you, and the body's flag table, which is what a reader acts on. A
# command whose hint advertises a flag its table does not document is a command
# that accepts something nothing defines, which is the drift this file exists for.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  hint=$(fm "$f" | grep '^argument-hint:' | grep -oE '\-\-[a-z][a-z-]*' | sort -u)
  table=$(grep -oE '^\| `--[a-z][a-z-]*' "$f" | sed 's/^| `//' | sort -u)
  only_hint=$(comm -23 <(printf '%s\n' "$hint") <(printf '%s\n' "$table") | sed 's/^/UNDOCUMENTED /')
  only_table=$(comm -13 <(printf '%s\n' "$hint") <(printf '%s\n' "$table") | sed 's/^/UNADVERTISED /')
  expect "$name advertises at least one flag" "$hint" "--"
  refute "$name advertises no flag its table omits" "$only_hint"  "UNDOCUMENTED "
  refute "$name documents no flag its hint omits"   "$only_table" "UNADVERTISED "
done

# The negatives. A reviewer-specific flag on the wrong family is the single most
# dangerous paste in this directory: `--merge` on a local command would advertise
# a merge from a procedure that must never perform one.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  body=$(cat "$f")
  case "$name" in
    local-*)
      refute "$name offers no --merge"   "$(hasflag "$body" '--merge')"   YES
      refute "$name offers no --timeout" "$(hasflag "$body" '--timeout')" YES
      ;;
    remote-*)
      refute "$name offers no --model"      "$(hasflag "$body" '--model')"      YES
      refute "$name offers no --no-publish" "$(hasflag "$body" '--no-publish')" YES
      ;;
    *)
      FAIL=$((FAIL + 1)); printf '  FAIL %s is neither remote-* nor local-*\n' "$name"
      ;;
  esac
  # Every command carries the rigor level. A command that quietly did not would
  # make `--rigor` mean "supported here, ignored there" -- and since the level
  # decides when the loop may stop, a command missing it is a command with no
  # stopping condition it can name.
  expect "$name offers --rigor" "$(hasflag "$body" '--rigor')" YES
  # The four that were removed, staying removed. CHANGELOG.md records them and
  # is out of scope for the same reason procedure-refs.test.sh scopes it out:
  # a changelog has to be able to quote what it records removing.
  refute "$name names no --reviewer"       "$(hasflag "$body" '--reviewer')"       YES
  refute "$name names no --review-model"   "$(hasflag "$body" '--review-model')"   YES
  refute "$name names no --grade-severity" "$(hasflag "$body" '--grade-severity')" YES
  refute "$name names no --accept-at"      "$(hasflag "$body" '--accept-at')"      YES
done

# --- procedure wiring ------------------------------------------------------
#
# A thin command that cannot find its body is the whole risk of this design, and
# it is the one failure CI cannot reproduce: the path resolves in the checkout
# and may not resolve once the plugin is installed. What CI can check is that the
# path is spelled the way that survives installation, and that it points at a
# file that exists.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  case "$name" in
    remote-*) want=remote-loop ;;
    local-*)  want=local-loop ;;
    *)        want= ;;
  esac
  [ -n "$want" ] || continue
  refs=$(grep -oE 'procedures/[a-z-]+\.md' "$f" | sort -u)
  expect "$name names procedures/$want.md" "$refs" "procedures/$want.md"
  # Exactly one LOOP procedure, so a command cannot quietly drive both. The
  # grader spec is a procedure too and is cited by every command that can reach
  # it, so the count is over the two loops rather than over the directory.
  n=$(printf '%s\n' "$refs" | grep -cE '^procedures/(remote|local)-loop\.md$' || true)
  if [ "$n" -eq 1 ]; then
    PASS=$((PASS + 1)); printf '  ok   %s names exactly one loop procedure\n' "$name"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s names %d loop procedures\n' "$name" "$n"
  fi
  # The level spec is a procedure too, and it is the one every command's flag
  # table now defers to. A command advertising --rigor and naming nothing that
  # defines it is the thin-command failure this file exists for, one file over
  # from the loop procedure it already checks.
  expect "$name names procedures/rigor-levels.md" "$refs" "procedures/rigor-levels.md"
  for p in $refs; do
    if [ -f "$ROOT/$p" ]; then
      PASS=$((PASS + 1)); printf '  ok   %s resolves\n' "$p"
    else
      FAIL=$((FAIL + 1)); printf '  FAIL %s names %s, which does not exist\n' "$name" "$p"
    fi
  done
done

# THE PATH MUST BE THE ONE THAT SURVIVES INSTALLATION. `${CLAUDE_PLUGIN_ROOT}` is
# substituted in a plugin command's body; a relative `../procedures/...` reaches
# the model as literal text and resolves against an unspecified working
# directory. Both work in this checkout, which is exactly why the difference is
# invisible without this assertion.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  bad=$(grep -oE '\.\./(procedures|reviewers)/[a-z.-]+' "$f" || true)
  refute "$name uses no relative plugin path" "$bad" "../"
  root=$(grep -o 'CLAUDE_PLUGIN_ROOT' "$f" | head -1)
  expect "$name uses \${CLAUDE_PLUGIN_ROOT}" "$root" "CLAUDE_PLUGIN_ROOT"
done

# --- reviewer wiring -------------------------------------------------------
#
# Every shipped definition has exactly one driver, and every built-in command
# names exactly one definition. A definition nobody drives is a reviewer that
# cannot be run, and two commands naming one definition is two front doors to the
# same reviewer with different flag surfaces.
DEFS=0
for def in "$ROOT"/reviewers/*.json; do
  stem=$(basename "$def" .json)
  DEFS=$((DEFS + 1))
  # The column padding is prettier's and varies with the widest cell, so the row
  # is matched with tolerant whitespace. Anchoring on the exact single space held
  # until the first table whose other rows were longer.
  n=$(grep -lE "^\| *Definition +\| .*reviewers/$stem\.json" "${CMDS[@]}" 2>/dev/null | wc -l)
  if [ "$n" -eq 1 ]; then
    PASS=$((PASS + 1)); printf '  ok   %s is driven by exactly one command\n' "$stem"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s is named by %d commands, not 1\n' "$stem" "$n"
  fi
done
if [ "$DEFS" -ge 5 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d definitions were checked\n' "$DEFS"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d definitions found\n' "$DEFS"
fi

# A command either ships a definition or takes one. Neither is a command that
# cannot say what it drives; both is a command with two answers.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  named=$(grep -cE '^\| *Definition +\| .*reviewers/[a-z-]+\.json' "$f" || true)
  takes=$(hasflag "$(cat "$f")" '--config')
  case "$name" in
    *-custom-loop.md)
      expect "$name takes --config"          "$takes" YES
      expect "$name ships no definition"     "$named" "0"
      ;;
    *)
      refute "$name does not take --config"  "$takes" YES
      expect "$name names one definition"    "$named" "1"
      ;;
  esac
done

# --- thinness, mechanically ------------------------------------------------
#
# Each of these is a second source of truth for something a procedure or a fence
# already owns, and each would be invisible to the suite that owns it:
# `permissions.test.sh` would not know a command ran an ungranted subcommand if
# it never looked at commands, `fence-guards.test.sh` compares markers only
# within the file it reads, and `severity-ladder.test.sh` would sweep a ladder
# spelled here into its count while the copy that matters stayed unchecked.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  bash_fence=$(grep -cE '^ *```bash$' "$f" || true)
  expect "$name carries no bash fence"   "$bash_fence" "0"
  refute "$name carries no fence marker" "$(grep -o 'revloop:fence' "$f" || true)" "revloop:fence"
  refute "$name prints no trigger marker" "$(grep -o 'revloop:trigger' "$f" || true)" "revloop:trigger"
  refute "$name spells out no ladder" \
    "$(grep -oE '\b[a-z][a-z-]* > [a-z][a-z-]*( > [a-z][a-z-]*)*' "$f" || true)" " > "
done

# --- the grant is one string per family ------------------------------------
#
# The procedure is one file, so the grant it needs is one string: any per-command
# variation within a family is fiction. This is one assertion that catches a
# copy-paste error in any of the seven, and it is the cheap half of the guard
# `permissions.test.sh` makes expensively against docs/permissions.md.
famtools() { # famtools <prefix> -> the distinct allowed-tools lines in that family
  for f in "$ROOT"/commands/"$1"*.md; do fm "$f" | grep '^allowed-tools:'; done | sort -u
}
R=$(famtools remote); L=$(famtools local)
expect "every remote command grants the same tools" "$(printf '%s\n' "$R" | grep -c .)" "1"
expect "every local command grants the same tools"  "$(printf '%s\n' "$L" | grep -c .)" "1"
if [ "$R" != "$L" ]; then
  PASS=$((PASS + 1)); printf '  ok   the two families grant different tools\n'
else
  FAIL=$((FAIL + 1)); printf '  FAIL both families grant the same tools\n'
fi
# The local family must never pre-approve the subcommand that merges. This is
# prose in the local procedure and was enforced by nothing; with three local
# commands it is three chances to paste the wrong line.
refute "no local command grants Bash(gh pr:*)" "$L" "Bash(gh pr:*)"

# --- both READMEs list the same commands -----------------------------------
#
# NOTHING TESTED README.ja.md BEFORE, and it is the file in this repository most
# likely to drift: it mirrors every section of the English one, by hand, and a
# release that renames every command touches all of them. This does not compare
# prose -- it compares the one thing a translation cannot legitimately differ on,
# which is which commands exist. A command added to one README and not the other
# is the drift, and it fails here rather than in front of a reader.
for f in "${CMDS[@]}"; do
slug="/revloop:$(basename "$f" .md)"
en=$(grep -c -- "$slug" "$ROOT/README.md" || true)
ja=$(grep -c -- "$slug" "$ROOT/README.ja.md" || true)
if [ "$en" -gt 0 ] && [ "$ja" -gt 0 ]; then
  PASS=$((PASS + 1)); printf '  ok   %s appears in both READMEs\n' "$slug"
else
  FAIL=$((FAIL + 1)); printf '  FAIL %s appears in README.md %d time(s), README.ja.md %d\n' "$slug" "$en" "$ja"
fi
done


summary "commands"
