#!/usr/bin/env bash
# Validates examples/*.json and reviewers/*.json against schema/*.schema.json,
# and checks that each schema rejects the shapes it must reject.
set -uo pipefail
shopt -s extglob
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "schema:"

if [ ! -d "$ROOT/node_modules/ajv" ]; then
  echo "  note ajv not installed; run npm ci. Skipping."
  exit 0
fi

S="$ROOT/schema/revloop.schema.json"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Exit 1 means the schema rejected the file and 2 means the validator never
# ran. The suite asserts rejections, so a 2 is reported as a failure.
v() {
  node "$ROOT/tests/validate-schema.mjs" "$S" "$1" >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 2 ] && { printf '  FAIL validator could not run on %s\n' "$1"; FAIL=$((FAIL + 1)); }
  return "$rc"
}

# Reviewer definitions (reviewers/*.json, --config) have their own schema.
SR="$ROOT/schema/reviewer.schema.json"
rv() {
  node "$ROOT/tests/validate-schema.mjs" "$SR" "$1" >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 2 ] && { printf '  FAIL reviewer validator could not run on %s\n' "$1"; FAIL=$((FAIL + 1)); }
  return "$rc"
}

# The file name prefix selects the schema, so a misnamed example fails.
EX=0
for f in "$ROOT"/examples/*.json; do
  base=$(basename "$f")
  case "$base" in
    revloop.*) sch=v ;;
    reviewer.*) sch=rv ;;
    *) FAIL=$((FAIL + 1)); printf '  FAIL %s matches no example family\n' "$base"; continue ;;
  esac
  EX=$((EX + 1))
  if "$sch" "$f"; then
    PASS=$((PASS + 1)); printf '  ok   %s validates\n' "$base"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s does not validate\n' "$base"
  fi
done
if [ "$EX" -ge 6 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d examples were validated\n' "$EX"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d examples validated; the glob is broken\n' "$EX"
fi

# --- the shipped reviewer definitions ---------------------------------------
DEFS=0
for def in "$ROOT"/reviewers/*.json; do
  base=$(basename "$def")
  DEFS=$((DEFS + 1))
  if rv "$def"; then
    PASS=$((PASS + 1)); printf '  ok   %s validates\n' "$base"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s does not validate\n' "$base"
  fi
done
if [ "$DEFS" -ge 5 ]; then
  PASS=$((PASS + 1)); printf '  ok   %d reviewer definitions were found\n' "$DEFS"
else
  FAIL=$((FAIL + 1)); printf '  FAIL only %d reviewer definitions found; the glob is broken\n' "$DEFS"
fi

# Every definition has a card and every card has a definition.
for def in "$ROOT"/reviewers/*.json; do
  stem=$(basename "$def" .json)
  if [ -f "$ROOT/reviewers/$stem.md" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s has a card\n' "$stem"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s has no card at reviewers/%s.md\n' "$stem" "$stem"
  fi
done
for card in "$ROOT"/reviewers/*.md; do
  stem=$(basename "$card" .md)
  [ "$stem" = "README" ] && continue
  if [ -f "$ROOT/reviewers/$stem.json" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s has a definition\n' "$stem"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s has no definition at reviewers/%s.json\n' "$stem" "$stem"
  fi
done

# The file stem is the reviewer's name and is written into the trigger marker
# as reviewer=<name>, which the wait fence parses as space-separated pairs.
for def in "$ROOT"/reviewers/*.json; do
  stem=$(basename "$def" .json)
  case "$stem" in
    [a-z0-9]*([a-z0-9-])) PASS=$((PASS + 1)); printf '  ok   %s is a marker-safe name\n' "$stem" ;;
    *) FAIL=$((FAIL + 1)); printf '  FAIL %s is not a marker-safe reviewer name\n' "$stem" ;;
  esac
  has_name=$(grep -c '"name"' "$def" || true)
  if [ "$has_name" = "0" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s carries no name key\n' "$stem"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s carries a name key; the file name is the name\n' "$stem"
  fi
done

# The text a definition passes to --append-system-prompt must appear verbatim
# in its card. It is read off the raw line, between the escaped quotes.
quoted=0
for def in "$ROOT"/reviewers/*.json; do
  stem=$(basename "$def" .json)
  arg=$(sed -n 's/.*--append-system-prompt \\"\([^"\\]*\)\\".*/\1/p' "$def")
  [ -n "$arg" ] || continue
  quoted=$((quoted + 1))
  if grep -qF -- "$arg" "$ROOT/reviewers/$stem.md"; then
    PASS=$((PASS + 1)); printf '  ok   %s quotes the instruction its definition carries\n' "$stem"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL reviewers/%s.md does not quote the --append-system-prompt text in %s.json\n' "$stem" "$stem"
  fi
done
if [ "$quoted" -ge 1 ]; then
  PASS=$((PASS + 1)); printf '  ok   a definition carrying an instruction was found\n'
else
  FAIL=$((FAIL + 1)); printf '  FAIL no definition carries --append-system-prompt; the pin above checked nothing\n'
fi

# A plain `gh pr view` fails on gh 2.4.0, so the ECC reviewer's instruction
# names the form that works there.
arg=$(sed -n 's/.*--append-system-prompt \\"\([^"\\]*\)\\".*/\1/p' "$ROOT/reviewers/ecc-review-pr.json")
if printf '%s' "$arg" | grep -qF -- 'gh pr view --json'; then
  PASS=$((PASS + 1)); printf '  ok   ecc-review-pr is told to read the pull request with gh pr view --json\n'
else
  FAIL=$((FAIL + 1)); printf '  FAIL the ecc-review-pr instruction does not name gh pr view --json\n'
fi

# --- reject cases -----------------------------------------------------------
reject() { # reject <label> <json>
  printf '%s' "$2" > "$TMP/bad.json"
  if v "$TMP/bad.json"; then
    FAIL=$((FAIL + 1)); printf '  FAIL schema accepted: %s\n' "$1"
  else
    PASS=$((PASS + 1)); printf '  ok   rejected: %s\n' "$1"
  fi
}

rreject() { # rreject <label> <reviewer-json>
  printf '%s' "$2" > "$TMP/bad.json"
  if rv "$TMP/bad.json"; then
    FAIL=$((FAIL + 1)); printf '  FAIL reviewer schema accepted: %s\n' "$1"
  else
    PASS=$((PASS + 1)); printf '  ok   rejected: %s\n' "$1"
  fi
}

reject "unknown top-level key"      '{"version":1,"reviewrs":{}}'
reject "unknown config version"     '{"version":2}'
reject "unknown project key"        '{"version":1,"project":{"verfy":["x"]}}'
rreject "reviewer without botLogin" '{"trigger":"@a review"}'
rreject "botLogin with a slash" '{"botLogin":"evil/../bot"}'
rreject "trigger with a newline" '{"botLogin":"a[bot]","trigger":"@a review\nrm -rf /"}'

rreject "github-comment without trigger" '{"botLogin":"a[bot]"}'
# The wait fence splits a marker on the literal 'revloop:trigger '.
rreject "trigger containing the literal marker key" '{"botLogin":"a[bot]","trigger":"see revloop:trigger below"}'
reject "malformed timeout"          '{"version":1,"defaults":{"timeout":"30x"}}'
reject "maxRounds below 1"          '{"version":1,"defaults":{"maxRounds":0}}'
rreject "unknown markerTolerated" '{"botLogin":"a[bot]","markerTolerated":"maybe"}'

# Keys with no consumer.
rreject "verdictOn (fence watches both)" '{"botLogin":"a[bot]","verdictOn":["reviews"]}'
rreject "ignoreCommentPatterns (in fence)" '{"botLogin":"a[bot]","ignoreCommentPatterns":["^x"]}'
reject "a configured merge method"       '{"version":1,"project":{"pr":{"mergeMethod":"squash"}}}'

# .revloop.json comes from the repository, so it cannot set what only a flag
# may grant.
reject "merge defaulted from config" '{"version":1,"defaults":{"merge":true}}'
reject "auto defaulted from config"  '{"version":1,"defaults":{"auto":true}}'

# The rigor level has no key on either surface. acceptAt is its former name.
reject "rigor defaulted from config"      '{"version":1,"defaults":{"rigor":"minimal"}}'
rreject "rigor on a reviewer" '{"botLogin":"a[bot]","rigor":"minimal"}'
reject "acceptAt defaulted from config"   '{"version":1,"defaults":{"acceptAt":"HIGH"}}'
rreject "acceptAt on a reviewer" '{"botLogin":"a[bot]","acceptAt":"P2"}'

# Grading follows from the reviewer's shape and has no key either.
reject "gradeSeverity from config"        '{"version":1,"defaults":{"gradeSeverity":true}}'
rreject "gradeSeverity on a reviewer" '{"botLogin":"a[bot]","gradeSeverity":true}'

# --- the two reviewer kinds -------------------------------------------------
#
# The kinds share one object and are separated by if/then, so these cases are
# the only evidence that the separation holds.
rreject "local-command without invoke" '{"kind":"local-command","command":"x"}'
rreject "local-command without command" '{"kind":"local-command","invoke":"skill"}'
rreject "local-command with botLogin" '{"kind":"local-command","invoke":"skill","command":"x","botLogin":"a[bot]"}'
rreject "local-command with trigger" '{"kind":"local-command","invoke":"skill","command":"x","trigger":"@a review"}'
# cleanPatterns has no consumer in the local loop. rateLimitPatterns has one
# and is accepted below.
rreject "local-command with cleanPatterns" '{"kind":"local-command","invoke":"skill","command":"x","cleanPatterns":["^ok"]}'
rreject "local-command with markerTolerated" '{"kind":"local-command","invoke":"skill","command":"x","markerTolerated":"verified"}'
rreject "unknown invoke" '{"kind":"local-command","invoke":"exec","command":"x"}'
rreject "unknown kind" '{"kind":"webhook","botLogin":"a[bot]"}'
rreject "a skill name with a space" '{"kind":"local-command","invoke":"skill","command":"ecc:review pr"}'
rreject "a skill name with a slash" '{"kind":"local-command","invoke":"skill","command":"../../evil"}'
rreject "a command with a newline" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x\nrm -rf /"}'
rreject "an empty severityLevels ladder" '{"botLogin":"a[bot]","severityLevels":[]}'
# The map is present so that uniqueItems is what rejects this.
rreject "a ladder with a repeated rung" '{"botLogin":"a[bot]","severityLevels":["P1","P1"],"severityMap":{"P1":"critical"}}'

# severityLevels and severityMap require each other, and a map value must be a
# canonical rung. The map's totality and ordering are beyond the schema.
rreject "a map onto a rung off the ladder" '{"botLogin":"a[bot]","severityLevels":["P1"],"severityMap":{"P1":"blocker"}}'
rreject "a map with no severityLevels" '{"botLogin":"a[bot]","severityMap":{"P1":"critical"}}'
rreject "a ladder with no severityMap" '{"botLogin":"a[bot]","severityLevels":["P1","P2"]}'
rreject "an empty severityMap" '{"botLogin":"a[bot]","severityLevels":["P1"],"severityMap":{}}'

# A github-comment reviewer may not carry the local keys.
rreject "github-comment with a command" '{"botLogin":"a[bot]","command":"x"}'
rreject "github-comment with invoke" '{"botLogin":"a[bot]","invoke":"skill"}'
rreject "github-comment with requiresPr" '{"botLogin":"a[bot]","requiresPr":true}'
# An empty command runs nothing, which reads as a clean review.
rreject "an empty subprocess command" '{"kind":"local-command","invoke":"subprocess","command":""}'
rreject "an empty skill name" '{"kind":"local-command","invoke":"skill","command":""}'
# So does a command of spaces.
rreject "a whitespace-only command" '{"kind":"local-command","invoke":"subprocess","command":"   "}'
# The local command grants Bash(git:*) and a permission rule matches a string
# prefix, so a command may not begin with git, however the word ends.
rreject "a subprocess command that is git" '{"kind":"local-command","invoke":"subprocess","command":"git push --force"}'
rreject "  with leading whitespace" '{"kind":"local-command","invoke":"subprocess","command":"  git push"}'
rreject "  with a leading tab" '{"kind":"local-command","invoke":"subprocess","command":"\tgit push"}'
rreject "  bare, with no argument at all" '{"kind":"local-command","invoke":"subprocess","command":"git"}'
# git followed by a shell separator.
rreject "git ended by a semicolon" '{"kind":"local-command","invoke":"subprocess","command":"git;rm -rf /"}'
rreject "git ended by &&" '{"kind":"local-command","invoke":"subprocess","command":"git&&rm -rf /"}'
rreject "git ended by a background &" '{"kind":"local-command","invoke":"subprocess","command":"git&"}'
rreject "git ended by a pipe" '{"kind":"local-command","invoke":"subprocess","command":"git|tee out"}'
rreject "git ended by a redirect out" '{"kind":"local-command","invoke":"subprocess","command":"git>out"}'
rreject "git ended by a redirect in" '{"kind":"local-command","invoke":"subprocess","command":"git<in"}'
rreject "git ended by a subshell paren" '{"kind":"local-command","invoke":"subprocess","command":"git(x)"}'
# git"" is still the word git.
rreject "git ended by an empty quote pair" '{"kind":"local-command","invoke":"subprocess","command":"git\"\" push --force"}'
# A longer name that starts with git matches the granted prefix too.
rreject "a git-prefixed longer name" '{"kind":"local-command","invoke":"subprocess","command":"gitlint --diff"}'
rreject "a hyphenated git-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"git-review -c"}'
rreject "a dotted git-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"git.exe --version"}'

# The same for gh. The ban is on bare gh, wider than the gh prefixes granted.
rreject "a subprocess command that is gh" '{"kind":"local-command","invoke":"subprocess","command":"gh pr merge 1"}'
rreject "  gh with leading whitespace" '{"kind":"local-command","invoke":"subprocess","command":"  gh pr create"}'
rreject "  gh with a leading tab" '{"kind":"local-command","invoke":"subprocess","command":"\tgh repo view"}'
rreject "  gh bare" '{"kind":"local-command","invoke":"subprocess","command":"gh"}'
rreject "gh ended by a semicolon" '{"kind":"local-command","invoke":"subprocess","command":"gh;rm -rf /"}'
rreject "a gh-prefixed longer name" '{"kind":"local-command","invoke":"subprocess","command":"ghreview --diff"}'
rreject "a hyphenated gh-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"gh-review -c"}'
rreject "a dotted gh-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"gh.exe --version"}'

# {reviewModel} is substituted before the command runs, so a leading
# placeholder would let the flag's value choose the first token.
rreject "a leading {reviewModel}" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel} push --force"}'
rreject "  a leading placeholder, spaced" '{"kind":"local-command","invoke":"subprocess","command":"  {reviewModel} -p x"}'
# The placeholder followed by a shell separator.
rreject "placeholder ended by a semicolon" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel};rm -rf /"}'
rreject "placeholder ended by an &&" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}&&rm -rf /"}'
rreject "placeholder ended by a pipe" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}|tee out"}'
rreject "placeholder ended by a redirect" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}>out"}'
# A joined suffix, and the placeholder alone.
rreject "a placeholder-prefixed longer name" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}lint --diff"}'
rreject "  a bare placeholder" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}"}'

# --review-model is expanded into a command line, so no config key sets it.
reject "reviewModel defaulted from config" '{"version":1,"defaults":{"reviewModel":"sonnet"}}'
reject "localReviewModel from config"     '{"version":1,"defaults":{"localReviewModel":"sonnet"}}'
rreject "a model key on a reviewer" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x","model":"sonnet"}'

# Publishing has no config key yet. Adding one means deleting these cases.
reject "publish defaulted from config"    '{"version":1,"defaults":{"publish":true}}'
reject "noPublish defaulted from config"  '{"version":1,"defaults":{"noPublish":true}}'
reject "localPublish defaulted from config" '{"version":1,"defaults":{"localPublish":false}}'

# --- accept cases -----------------------------------------------------------
accept() { # accept <label> <json>
  printf '%s' "$2" > "$TMP/good.json"
  if v "$TMP/good.json"; then
    PASS=$((PASS + 1)); printf '  ok   accepted: %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL schema rejected: %s\n' "$1"
  fi
}

raccept() { # raccept <label> <reviewer-json>
  printf '%s' "$2" > "$TMP/good.json"
  if rv "$TMP/good.json"; then
    PASS=$((PASS + 1)); printf '  ok   accepted: %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL reviewer schema rejected: %s\n' "$1"
  fi
}

accept "an empty object"                '{}'
raccept "botLogin with the [bot] suffix" '{"botLogin":"a-reviewer[bot]","trigger":"@a review"}'
raccept "botLogin without the suffix" '{"botLogin":"a-reviewer","trigger":"@a review"}'
accept "a null baseBranch"              '{"version":1,"project":{"baseBranch":null}}'

# An absent kind means github-comment.
raccept "a reviewer with no kind at all" '{"botLogin":"a[bot]","trigger":"@a review"}'
raccept "an explicit github-comment kind" '{"kind":"github-comment","botLogin":"a[bot]","trigger":"@a review"}'
# Only the literal 'revloop:trigger' is banned.
raccept "a trigger that just mentions the word trigger" '{"botLogin":"a[bot]","trigger":"@a review triggers a run"}'
raccept "a skill-invoked local reviewer" '{"kind":"local-command","invoke":"skill","command":"ecc:review-pr","severityLevels":["CRITICAL","HIGH","MEDIUM","LOW"],"severityMap":{"CRITICAL":"critical","HIGH":"high","MEDIUM":"medium","LOW":"low"},"requiresPr":true}'
raccept "a subprocess local reviewer" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review medium\""}'
raccept "a local reviewer with no ladder" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x"}'
# Which reviewer runs is decided by the command typed, so no key selects it.
reject "a default reviewer"       '{"version":1,"defaults":{"reviewer":"codex"}}'
reject "a default local reviewer" '{"version":1,"defaults":{"localReviewer":"code-review"}}'
reject "a reviewers map"          '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]"}}}'
accept "a per-loop round cap pair"        '{"version":1,"defaults":{"maxRounds":20,"localMaxRounds":5}}'
raccept "a command with an inner space" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x"}'
# The git ban applies to the leading token of a subprocess command only.
raccept "a command mentioning git later" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review git-history\""}'
raccept "a skill named after git" '{"kind":"local-command","invoke":"skill","command":"git-review"}'
# The same for gh. A skill name is never a shell command.
raccept "a command mentioning gh later" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review gh-actions\""}'
raccept "a skill named after gh" '{"kind":"local-command","invoke":"skill","command":"gh-review"}'

# The two shipped presets, in the form they ship.
raccept "the shipped code-review preset" '{"kind":"local-command","invoke":"subprocess","command":"claude --model {reviewModel} -p \"/code-review medium\""}'
# The longest shipped command. This pins that it fits the schema's length cap.
raccept "the shipped ecc-review-pr preset" '{"kind":"local-command","invoke":"subprocess","command":"claude --model {reviewModel} --effort medium --append-system-prompt \"Non-interactive run: never ask and never retry a denied call. Finish without it and list what did not run. Read the pull request with gh pr view --json number,title,files and gh pr diff, never plain gh pr view. If it cannot be read, say so and stop. Open the report with its number, title and changed files.\" -p \"/ecc:review-pr\"","requiresPr":true,"rateLimitPatterns":["You'"'"'ve hit your session limit"]}'
# A command without {reviewModel} is valid.
raccept "a subprocess command, unpinned" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review medium\""}'

# The map is allowed on both kinds.
raccept "a github reviewer with a map" '{"botLogin":"a[bot]","trigger":"@a review","severityLevels":["P1","P2","P3"],"severityMap":{"P1":"critical","P2":"high","P3":"low"}}'
raccept "a local reviewer with a map" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x","severityLevels":["CRITICAL","HIGH","MEDIUM","LOW"],"severityMap":{"CRITICAL":"critical","HIGH":"high","MEDIUM":"medium","LOW":"low"}}'

# rateLimitPatterns is allowed on both kinds.
raccept "a local reviewer with a rate limit" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x","rateLimitPatterns":["out of quota"]}'
raccept "a github reviewer with one too" '{"botLogin":"a[bot]","trigger":"@a review","rateLimitPatterns":["quota exceeded"]}'

# A ladder longer than the canonical one must share a rung, so sharing is valid.
raccept "a five-rung ladder sharing a rung" '{"botLogin":"a[bot]","trigger":"@a review","severityLevels":["S0","S1","S2","S3","S4"],"severityMap":{"S0":"critical","S1":"high","S2":"high","S3":"medium","S4":"low"}}'

summary "schema"
