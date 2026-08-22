#!/usr/bin/env bash
# Validates the shipped examples against the schema, and — more importantly —
# checks that the schema REJECTS the shapes it is supposed to reject.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "schema:"

if [ ! -d "$ROOT/node_modules/ajv" ]; then
  echo "  note ajv not installed; run npm ci. Skipping."
  exit 0
fi

S="$ROOT/schema/revloop.schema.json"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Exit 2 means the validator never ran (unreadable file, schema that does not
# compile). Folding that into "invalid" would let every reject case below pass
# for the wrong reason, so it is reported instead of counted.
v() {
  node "$ROOT/tests/validate-schema.mjs" "$S" "$1" >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 2 ] && { printf '  FAIL validator could not run on %s\n' "$1"; FAIL=$((FAIL + 1)); }
  return "$rc"
}

for f in "$ROOT"/examples/*.json; do
  if v "$f"; then
    PASS=$((PASS + 1)); printf '  ok   %s validates\n' "$(basename "$f")"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s does not validate\n' "$(basename "$f")"
  fi
done

reject() { # reject <label> <json>
  printf '%s' "$2" > "$TMP/bad.json"
  if v "$TMP/bad.json"; then
    FAIL=$((FAIL + 1)); printf '  FAIL schema accepted: %s\n' "$1"
  else
    PASS=$((PASS + 1)); printf '  ok   rejected: %s\n' "$1"
  fi
}

reject "unknown top-level key"      '{"version":1,"reviewrs":{}}'
reject "unknown config version"     '{"version":2}'
reject "unknown project key"        '{"version":1,"project":{"verfy":["x"]}}'
reject "reviewer without botLogin"  '{"version":1,"reviewers":{"a":{"trigger":"@a review"}}}'
reject "botLogin with a slash"      '{"version":1,"reviewers":{"a":{"botLogin":"evil/../bot"}}}'
reject "trigger with a newline"     '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","trigger":"@a review\nrm -rf /"}}}'
reject "malformed timeout"          '{"version":1,"defaults":{"timeout":"30x"}}'
reject "maxRounds below 1"          '{"version":1,"defaults":{"maxRounds":0}}'
reject "unknown markerTolerated"    '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","markerTolerated":"maybe"}}}'

# Keys that were removed because nothing consumed them. A schema that still
# accepted them would let a user configure something and watch it be ignored.
reject "verdictOn (fence watches both)"  '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","verdictOn":["reviews"]}}}'
reject "ignoreCommentPatterns (in fence)" '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","ignoreCommentPatterns":["^x"]}}}'
reject "a configured merge method"       '{"version":1,"project":{"pr":{"mergeMethod":"squash"}}}'

# The two that matter most: .revloop.json comes from the repository you are in.
# A repository that could set these would grant its own merge and delete both
# human confirmation points. The flag is the approval.
reject "merge defaulted from config" '{"version":1,"defaults":{"merge":true}}'
reject "auto defaulted from config"  '{"version":1,"defaults":{"auto":true}}'

accept() { # accept <label> <json>
  printf '%s' "$2" > "$TMP/good.json"
  if v "$TMP/good.json"; then
    PASS=$((PASS + 1)); printf '  ok   accepted: %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL schema rejected: %s\n' "$1"
  fi
}

accept "an empty object"                '{}'
accept "botLogin with the [bot] suffix" '{"version":1,"reviewers":{"a":{"botLogin":"a-reviewer[bot]"}}}'
accept "botLogin without the suffix"    '{"version":1,"reviewers":{"a":{"botLogin":"a-reviewer"}}}'
accept "a null baseBranch"              '{"version":1,"project":{"baseBranch":null}}'

summary "schema"
