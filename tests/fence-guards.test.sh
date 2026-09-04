#!/usr/bin/env bash
# Structural guards on the fences. These catch the failures that are invisible
# to a reader and to `bash -n`.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
SRC="$ROOT/procedures/remote-loop.md"
# TWO SETS, BECAUSE THE SPLIT PUT THE GRANT AND THE GRANTED TEXT IN DIFFERENT
# FILES. A procedure holds the fences and the fenced bash; a command holds the
# `allowed-tools` line that pre-approves it. Reading one glob for both would
# assert a missing grant on every procedure -- a file the host never installs as
# a command, and which therefore must not carry one.
PROCS=("$ROOT"/procedures/*.md)
CMDS=("$ROOT"/commands/*.md)
IDS=$("$ROOT/tests/extract-fences.sh" --list)

echo "fence-guards:"

# An unexpanded glob is a single path that does not exist. `grep` over it finds
# nothing, `refute` then passes, and the allowed-tools `expect` is the only
# assertion that would notice — reporting a missing grant rather than a missing
# file. The other two globbed guards fail on this explicitly; this one did not,
# which made a claim in the changelog untrue about a third of its subject.
if [ ! -f "${PROCS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL procedures/*.md matched no file\n'
fi
if [ ! -f "${CMDS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
fi
# One command per reviewer, plus the two that take a definition. A glob that
# matched three would satisfy the guard above while leaving four reviewers
# undriven, which is the same "green over a partial corpus" hole the floors in
# schema.test.sh and severity-ladder.test.sh exist for.
if [ "${#CMDS[@]}" -ge 7 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d commands were found\n' "${#CMDS[@]}"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d commands found; the glob is broken\n' "${#CMDS[@]}"
fi

# extract-fences.sh --list fails when $SRC does not exist, but this script has no
# `set -e`, so that failure is swallowed and IDS silently becomes empty. The for
# loop below would then run zero times -- parsing, placeholder, repo-slug, jq-pipe,
# globbing and hash-pinning checks all skipped with no FAIL and no note that
# anything was skipped. This is the same failure class PROCS[0] above was fixed
# for; IDS needs the same guard.
if [ -z "$IDS" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL extract-fences.sh --list produced no fence ids (missing %s?)\n' "$SRC"
fi

for id in $IDS; do
  "$ROOT/tests/extract-fences.sh" "$id" > "$TMP/$id.sh"

  if bash -n "$TMP/$id.sh" 2>"$TMP/err"; then
    PASS=$((PASS + 1)); printf '  ok   %s parses\n' "$id"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s does not parse\n%s\n' "$id" "$(cat "$TMP/err")"
  fi

  # An unsubstituted placeholder is read by the shell as a redirect from a file
  # of that name. It runs, it does the wrong thing, and `bash -n` says nothing.
  ph=$(grep -oE '<[a-z][a-z_-]*>' "$TMP/$id.sh" || true)
  refute "$id has no unsubstituted placeholder" "$ph" "<"

  # A literal owner/repo makes the fence non-portable; {owner}/{repo} is the form.
  sl=$(grep -oE 'repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/' "$TMP/$id.sh" || true)
  refute "$id uses no literal repo slug" "$sl" "repos/"

  # gh embeds a jq implementation; a standalone jq binary is not guaranteed.
  jqpipe=$(grep -E '\|[[:space:]]*jq([[:space:]]|$)' "$TMP/$id.sh" || true)
  refute "$id never pipes to jq" "$jqpipe" "jq"

  # Globbing would let a bot-authored body expand into filenames during `set --`.
  gl=$(grep -c '^set -f$' "$TMP/$id.sh" || true)
  expect "$id disables globbing" "$gl" "1"
done

# A failure token that contains the success token as a substring makes every
# `grep -q ALL_PASS` true on failure. Checked against the fences only: the Notes
# section names the bad token on purpose, to explain why it is not used.
bad=$(cat "$TMP"/*.sh | grep -oE '[A-Za-z_]+ALL_PASS|ALL_PASS[A-Za-z_]+' | sort -u || true)
refute "no emitted token contains ALL_PASS" "$bad" "ALL_PASS"

# Neither a procedure nor a command may carry a repository-specific slug.
for src in "${PROCS[@]}" "${CMDS[@]}"; do
  name=$(basename "$src")
  slug=$(grep -oE 'repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pulls)' "$src" | grep -v 'repos/{owner}/{repo}/' || true)
  refute "$name uses no literal repo slug" "$slug" "repos/"
done

# A command's own `allowed-tools` is a grant like any other. Shipping a rule
# there that the docs tell users NOT to grant hands it out silently for that
# command — which is how `Bash(gh api *)`, named in permissions.md as the rule
# that reaches every repository your token can touch, once sat in the frontmatter
# while three files explained why nobody should use it.
#
# EVERY COMMAND is read, because the grant is per file: the local family grants
# a strictly smaller set and needs no broad gh rule at all, and a guard that read
# only one would report on a file the user never installed alone.
documented=$(grep -oE '"Bash\([^)]*\)"' "$ROOT/docs/permissions.md" | tr -d '"' | sort -u)
for src in "${CMDS[@]}"; do
  name=$(basename "$src")
  granted=$(awk 'NR>1 && /^---$/{exit} /^allowed-tools:/{print}' "$src" | grep -oE 'Bash\([^)]*\)' | sort -u)
  extra=$(comm -23 <(printf '%s\n' "$granted") <(printf '%s\n' "$documented"))
  expect "$name allowed-tools grants at least one Bash rule" "$granted" "Bash("
  refute "$name allowed-tools grants nothing docs/permissions.md does not" "$extra" "Bash("
done

# A PROCEDURE IS NOT A COMMAND AND MUST NOT GRANT ANYTHING. The host installs
# `commands/` and never `procedures/`, so an `allowed-tools` line in a procedure
# is a grant nobody receives -- and worse, a reader who finds one will believe it
# applies. That is the same failure the block above exists for, seen from the
# other side: there, a rule granted that the docs refuse; here, a rule that reads
# as granted and is not.
for src in "${PROCS[@]}"; do
  name=$(basename "$src")
  fm=$(awk 'NR==1 && /^---$/{f=1} f{print} NR>1 && /^---$/{exit}' "$src")
  refute "$name carries no allowed-tools" "$fm" "allowed-tools:"
  refute "$name carries no frontmatter"   "$fm" "---"
done

# THE MARKER IS THE PROCEDURE'"'"'S AND A COMMAND MUST NOT PRINT ONE. Its four keys
# are what the wait fence parses a round'"'"'s identity out of; a second copy in a
# thin command is a second source of truth for exactly the thing the marker guard
# below exists to pin, and one that no test would compare against the first.
for src in "${CMDS[@]}"; do
  name=$(basename "$src")
  m=$(grep -o 'revloop:trigger v=' "$src" || true)
  refute "$name prints no trigger marker" "$m" "revloop:trigger"
done

# Fence bytes are a permission-relevant surface: a change costs every user one
# re-approval, so it has to be a deliberate, recorded act.
HASHES="$ROOT/tests/fence-hashes.txt"
if [ -f "$HASHES" ]; then
  for id in $IDS; do
    want=$(awk -v i="$id" '$2==i{print $1}' "$HASHES")
    got=$(sha256sum < "$TMP/$id.sh" | cut -d' ' -f1)
    if [ "$want" = "$got" ]; then
      PASS=$((PASS + 1)); printf '  ok   %s matches its recorded hash\n' "$id"
    else
      FAIL=$((FAIL + 1))
      printf '  FAIL %s changed.\n       Recording a new hash costs every user one re-approval.\n' "$id"
      printf '       Add a CHANGELOG entry, then run: tests/update-fence-hashes.sh\n'
      printf '       want %s\n       got  %s\n' "${want:-<none>}" "$got"
    fi
  done
else
  printf '  note tests/fence-hashes.txt is absent; run tests/update-fence-hashes.sh\n'
fi

# Every marker the procedure prints must carry the four keys the wait fence
# reads by name. SCOPED TO $SRC ON PURPOSE: procedures/local-loop.md posts no
# comment and prints no marker, so a glob here would assert over a file that
# has nothing to assert about and report a missing marker as a defect. `attempt=` is deliberately not in this list: it is absent on a
# round's first trigger, which is the shape the reviewer card measured. A doc
# edit that drops one of the four is the input step 7's "never put the literal
# in the focus" rule is entirely about — a marker whose keys were never reached
# reports marker_head=none and, with an empty bot=, stops filtering bots.
# Extracting fewer markers than the procedure holds would make every assertion
# below vacuous for the one that got away, so the count is checked first: a
# discarded row is not the same as a row that was never there.
#
# The key test is anchored to a token boundary, because the fence's `case`
# matches `head=*` against a whitespace-separated token and a bare `grep head=`
# does not. A marker whose `head=` had been typo'd to `marker_head=` satisfied
# the substring but not the fence, so it passed all four assertions while
# parsing to exactly the marker_head=none this block exists to catch — the
# guard going green on its own failure case. That is step 7's whole-token rule,
# which the procedure states twice and which applies to the test that guards it.
literals=$(grep -c 'revloop:trigger v=' "$SRC")
markers=$(grep -o '<!-- revloop:trigger [^>]*-->' "$SRC")
found=$(printf '%s\n' "$markers" | grep -c 'revloop:trigger') || true
if [ "$literals" = "$found" ]; then
  PASS=$((PASS + 1)); printf '  ok   every marker literal was extracted (%s)\n' "$found"
else
  FAIL=$((FAIL + 1)); printf '  FAIL %s marker literal(s) present, %s extracted\n' "$literals" "$found"
fi
if [ -z "$markers" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL the procedure prints no trigger marker to check\n'
else
  PASS=$((PASS + 1)); printf '  ok   the procedure prints at least one trigger marker\n'
  for key in reviewer bot head round; do
    missing=$(printf '%s\n' "$markers" | grep -cvE "(^|[[:space:]])$key=") || true
    if [ "$missing" -eq 0 ]; then
      PASS=$((PASS + 1)); printf '  ok   every printed marker carries %s=\n' "$key"
    else
      FAIL=$((FAIL + 1)); printf '  FAIL %d printed marker(s) carry no %s=\n' "$missing" "$key"
    fi
  done
fi

summary "fence-guards"
