#!/usr/bin/env bash
# Validates the shipped examples against the schema, and — more importantly —
# checks that the schema REJECTS the shapes it is supposed to reject.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "schema:"

# ajv-cli has no --version that exits zero, so probe for the binary itself.
AJV="$ROOT/node_modules/.bin/ajv"
if [ ! -x "$AJV" ]; then
  echo "  note ajv-cli not installed; run npm ci. Skipping."
  exit 0
fi

S="$ROOT/schema/revloop.schema.json"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
v() { "$AJV" validate --spec=draft2020 --strict=false -s "$S" -d "$1" >/dev/null 2>&1; }

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
reject "unknown verdict endpoint"   '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","verdictOn":["emails"]}}}'
reject "unknown merge method"       '{"version":1,"project":{"pr":{"mergeMethod":"fast-forward"}}}'

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
