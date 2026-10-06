#!/usr/bin/env bash
# Checks commands/*.md: frontmatter, the flags each command advertises, the
# procedure and reviewer definition it names, and that it holds no runnable
# text. Also reads reviewers/*.json, README.md and README.ja.md.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "commands:"

CMDS=("$ROOT"/commands/*.md)

# An unexpanded glob is one path that does not exist; every sweep would read nothing and pass.
if [ ! -f "${CMDS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
  summary "commands"
  exit 1
fi

# One per shipped reviewer, plus the two that take a definition.
if [ "${#CMDS[@]}" -ge 7 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d commands were found\n' "${#CMDS[@]}"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d commands found\n' "${#CMDS[@]}"
fi

fm() { awk 'NR==1 { if ($0 != "---") exit; next } /^---$/ { exit } { print }' "$1"; }

# A flag is a whole token: --merge must not match inside --merge-method.
hasflag() { # hasflag <text> <flag> -> YES | NO
  if printf '%s' "$1" | grep -qE "(^|[^A-Za-z0-9-])$2([^A-Za-z0-9-]|\$)"; then echo YES; else echo NO; fi
}

# --- hasflag itself ---
expect "a bare flag matches"            "$(hasflag 'run with --merge now' '--merge')"        YES
expect "a flag in a code span matches"  "$(hasflag "the \`--merge\` flag" '--merge')"        YES
refute "a longer flag does not match"   "$(hasflag 'pass --merge-method'  '--merge')"        YES
refute "the bare word does not match"   "$(hasflag 'this never merges'    '--merge')"        YES
refute "a prefixed flag does not match" "$(hasflag 'pass --no-merge'      '--merge')"        YES

# --- frontmatter, per file ---
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  head=$(fm "$f")
  expect "$name declares a description"      "$head" "description:"
  expect "$name declares an argument-hint"   "$head" "argument-hint:"
  expect "$name is not model-invocable"      "$head" "disable-model-invocation: true"
  expect "$name grants allowed-tools"        "$head" "allowed-tools:"
done

# --- the flag matrix ---
# The argument-hint and the body's flag table must list the same flags.
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

# A flag from one family must not appear in the other.
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
  expect "$name offers --rigor" "$(hasflag "$body" '--rigor')" YES
  # Removed flags stay removed.
  refute "$name names no --reviewer"       "$(hasflag "$body" '--reviewer')"       YES
  refute "$name names no --review-model"   "$(hasflag "$body" '--review-model')"   YES
  refute "$name names no --grade-severity" "$(hasflag "$body" '--grade-severity')" YES
  refute "$name names no --accept-at"      "$(hasflag "$body" '--accept-at')"      YES
done

# --- procedure wiring ---
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
  # Counted over the two loop procedures; the grader and level specs are procedures too.
  n=$(printf '%s\n' "$refs" | grep -cE '^procedures/(remote|local)-loop\.md$' || true)
  if [ "$n" -eq 1 ]; then
    PASS=$((PASS + 1)); printf '  ok   %s names exactly one loop procedure\n' "$name"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s names %d loop procedures\n' "$name" "$n"
  fi
  expect "$name names procedures/rigor-levels.md" "$refs" "procedures/rigor-levels.md"
  for p in $refs; do
    if [ -f "$ROOT/$p" ]; then
      PASS=$((PASS + 1)); printf '  ok   %s resolves\n' "$p"
    else
      FAIL=$((FAIL + 1)); printf '  FAIL %s names %s, which does not exist\n' "$name" "$p"
    fi
  done
done

# ${CLAUDE_PLUGIN_ROOT} is substituted in an installed command's body. A relative
# ../procedures path is not, and resolves only in this checkout.
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  bad=$(grep -oE '\.\./(procedures|reviewers)/[a-z.-]+' "$f" || true)
  refute "$name uses no relative plugin path" "$bad" "../"
  root=$(grep -o 'CLAUDE_PLUGIN_ROOT' "$f" | head -1)
  expect "$name uses \${CLAUDE_PLUGIN_ROOT}" "$root" "CLAUDE_PLUGIN_ROOT"
done

# --- reviewer wiring: one driver per definition, one definition per command ---
DEFS=0
for def in "$ROOT"/reviewers/*.json; do
  stem=$(basename "$def" .json)
  DEFS=$((DEFS + 1))
  # prettier pads the column, so whitespace in the row is matched loosely.
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

# A command either ships a definition or takes one with --config.
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

# --- thinness: a command holds no fence, marker or ladder of its own ---
for f in "${CMDS[@]}"; do
  name=$(basename "$f")
  bash_fence=$(grep -cE '^ *```bash$' "$f" || true)
  expect "$name carries no bash fence"   "$bash_fence" "0"
  refute "$name carries no fence marker" "$(grep -o 'revloop:fence' "$f" || true)" "revloop:fence"
  refute "$name prints no trigger marker" "$(grep -o 'revloop:trigger' "$f" || true)" "revloop:trigger"
  refute "$name spells out no ladder" \
    "$(grep -oE '\b[a-z][a-z-]* > [a-z][a-z-]*( > [a-z][a-z-]*)*' "$f" || true)" " > "
done

# --- one allowed-tools string per family ---
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
# The local family must not pre-approve the subcommand that merges.
refute "no local command grants Bash(gh pr:*)" "$L" "Bash(gh pr:*)"

# --- both READMEs list every command ---
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
