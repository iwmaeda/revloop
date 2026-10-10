#!/usr/bin/env bash
# Structural guards on the fences in procedures/remote-loop.md and on what
# procedures/*.md and commands/*.md may carry. Also reads tests/fence-hashes.txt
# and docs/permissions.md.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
SRC="$ROOT/procedures/remote-loop.md"
# Procedures hold the fences. Commands hold the allowed-tools grant.
PROCS=("$ROOT"/procedures/*.md)
CMDS=("$ROOT"/commands/*.md)
IDS=$("$ROOT/tests/extract-fences.sh" --list)

echo "fence-guards:"

# An unexpanded glob is one path that does not exist; the guards would pass over it.
if [ ! -f "${PROCS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL procedures/*.md matched no file\n'
fi
if [ ! -f "${CMDS[0]}" ]; then
  FAIL=$((FAIL + 1)); printf '  FAIL commands/*.md matched no file\n'
fi
# One command per reviewer, plus the two that take a definition.
if [ "${#CMDS[@]}" -ge 7 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d commands were found\n' "${#CMDS[@]}"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d commands found; the glob is broken\n' "${#CMDS[@]}"
fi

# There is no set -e, so a failed --list leaves IDS empty and the loop runs zero times.
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

  # The shell reads an unsubstituted <placeholder> as a redirect, and bash -n accepts it.
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

# The gh stub ignores the query, so no fixture shows that the query fetches the
# reaction the jq program filters on. Without the field the mark hides nothing.
if grep -q '\.viewerHasReacted' "$TMP/wait-verdict.sh"; then
  q=$(grep -c 'reactionGroups{content viewerHasReacted ' "$TMP/wait-verdict.sh" || true)
  expect "wait-verdict queries the reaction its program filters on" "$q" "1"
else
  FAIL=$((FAIL + 1)); printf '  FAIL wait-verdict no longer filters on viewerHasReacted; the guard above checked nothing\n'
fi

# A failure token containing the success token makes `grep -q ALL_PASS` true on
# failure. Fences only: the Notes section names the bad token on purpose.
bad=$(cat "$TMP"/*.sh | grep -oE '[A-Za-z_]+ALL_PASS|ALL_PASS[A-Za-z_]+' | sort -u || true)
refute "no emitted token contains ALL_PASS" "$bad" "ALL_PASS"

# Neither a procedure nor a command may carry a repository-specific slug.
for src in "${PROCS[@]}" "${CMDS[@]}"; do
  name=$(basename "$src")
  slug=$(grep -oE 'repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pulls)' "$src" | grep -v 'repos/{owner}/{repo}/' || true)
  refute "$name uses no literal repo slug" "$slug" "repos/"
done

# A command's allowed-tools may grant only rules docs/permissions.md documents.
documented=$(grep -oE '"Bash\([^)]*\)"' "$ROOT/docs/permissions.md" | tr -d '"' | sort -u)
for src in "${CMDS[@]}"; do
  name=$(basename "$src")
  granted=$(awk 'NR>1 && /^---$/{exit} /^allowed-tools:/{print}' "$src" | grep -oE 'Bash\([^)]*\)' | sort -u)
  extra=$(comm -23 <(printf '%s\n' "$granted") <(printf '%s\n' "$documented"))
  expect "$name allowed-tools grants at least one Bash rule" "$granted" "Bash("
  refute "$name allowed-tools grants nothing docs/permissions.md does not" "$extra" "Bash("
done

# The host never installs procedures/, so a grant there would reach nobody.
for src in "${PROCS[@]}"; do
  name=$(basename "$src")
  fm=$(awk 'NR==1 && /^---$/{f=1} f{print} NR>1 && /^---$/{exit}' "$src")
  refute "$name carries no allowed-tools" "$fm" "allowed-tools:"
  refute "$name carries no frontmatter"   "$fm" "---"
done

# The trigger marker belongs to the procedure. A command prints none.
for src in "${CMDS[@]}"; do
  name=$(basename "$src")
  m=$(grep -o 'revloop:trigger v=' "$src" || true)
  refute "$name prints no trigger marker" "$m" "revloop:trigger"
done

# A fence change costs every user one re-approval, so the bytes are hash-pinned.
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

# Every marker $SRC prints must carry the four keys the wait fence reads.
# `attempt=` is absent on a round's first trigger, so it is not one of them.
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
    # Matched at a token boundary, as the fence does: `marker_head=` is not `head=`.
    missing=$(printf '%s\n' "$markers" | grep -cvE "(^|[[:space:]])$key=") || true
    if [ "$missing" -eq 0 ]; then
      PASS=$((PASS + 1)); printf '  ok   every printed marker carries %s=\n' "$key"
    else
      FAIL=$((FAIL + 1)); printf '  FAIL %d printed marker(s) carry no %s=\n' "$missing" "$key"
    fi
  done
fi

summary "fence-guards"
