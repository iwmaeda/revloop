#!/usr/bin/env bash
# Structural guards on the fences. These catch the failures that are invisible
# to a reader and to `bash -n`.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
SRC="$ROOT/commands/review-loop.md"
IDS=$("$ROOT/tests/extract-fences.sh" --list)

echo "fence-guards:"

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

# The procedure itself must carry no repository-specific slug.
slug=$(grep -oE 'repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pulls)' "$SRC" | grep -v 'repos/{owner}/{repo}/' || true)
refute "procedure uses no literal repo slug" "$slug" "repos/"

# The command's own `allowed-tools` is a grant like any other. Shipping a rule
# there that the docs tell users NOT to grant hands it out silently for this
# command — which is how `Bash(gh api *)`, named in permissions.md as the rule
# that reaches every repository your token can touch, once sat in the frontmatter
# while three files explained why nobody should use it.
granted=$(awk 'NR>1 && /^---$/{exit} /^allowed-tools:/{print}' "$SRC" | grep -oE 'Bash\([^)]*\)' | sort -u)
documented=$(grep -oE '"Bash\([^)]*\)"' "$ROOT/docs/permissions.md" | tr -d '"' | sort -u)
extra=$(comm -23 <(printf '%s\n' "$granted") <(printf '%s\n' "$documented"))
expect "allowed-tools grants at least one Bash rule" "$granted" "Bash("
refute "allowed-tools grants nothing docs/permissions.md does not" "$extra" "Bash("

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
# reads by name. `attempt=` is deliberately not in this list: it is absent on a
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
literals=$(grep -c 'revloop:trigger v=' "$ROOT/commands/review-loop.md")
markers=$(grep -o '<!-- revloop:trigger [^>]*-->' "$ROOT/commands/review-loop.md")
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
