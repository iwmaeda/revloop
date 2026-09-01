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

# The acceptance floor is the same class as the two above and has no key at all,
# so it is rejected wherever a reader might reach for one. A repository that
# could set its own --accept-at would lower its own review bar on a checkout you
# just cloned, while the run still reported a clean convergence.
reject "acceptAt defaulted from config"   '{"version":1,"defaults":{"acceptAt":"HIGH"}}'
reject "acceptAt on a reviewer"           '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","acceptAt":"P2"}}}'

# --- the two reviewer kinds ------------------------------------------------
#
# The kinds share one object with additionalProperties:false, so every key of
# both is declared and the separation is enforced by if/then rather than by two
# schemas. That means the cases below are the only evidence the separation holds
# at all: an if/then that never fires accepts everything, and looks identical to
# one that fires and passes.
reject "local-command without invoke"     '{"version":1,"reviewers":{"a":{"kind":"local-command","command":"x"}}}'
reject "local-command without command"    '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill"}}}'
reject "local-command with botLogin"      '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"x","botLogin":"a[bot]"}}}'
reject "local-command with trigger"       '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"x","trigger":"@a review"}}}'
reject "local-command with cleanPatterns" '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"x","cleanPatterns":["^ok"]}}}'
reject "local-command with markerTolerated" '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"x","markerTolerated":"verified"}}}'
reject "unknown invoke"                   '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"exec","command":"x"}}}'
reject "unknown kind"                     '{"version":1,"reviewers":{"a":{"kind":"webhook","botLogin":"a[bot]"}}}'
reject "a skill name with a space"        '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"ecc:review pr"}}}'
reject "a skill name with a slash"        '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"../../evil"}}}'
reject "a command with a newline"         '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"claude -p x\nrm -rf /"}}}'
reject "an empty severityLevels ladder"   '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","severityLevels":[]}}}'
reject "a ladder with a repeated rung"    '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","severityLevels":["P1","P1"]}}}'

# The other direction: a github-comment reviewer may not carry the local keys.
# Without this the two kinds would share every key and `kind` would be a label
# rather than a discriminator — a local reviewer could be given a botLogin the
# local loop never reads, and a GitHub reviewer a command nothing ever runs.
reject "github-comment with a command"    '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","command":"x"}}}'
reject "github-comment with invoke"       '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","invoke":"skill"}}}'
reject "github-comment with requiresPr"   '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]","requiresPr":true}}}'
# An empty command validates as a string and runs as nothing, and "the reviewer
# returned no findings" is what running nothing looks like.
reject "an empty subprocess command"      '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":""}}}'
reject "an empty skill name"              '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":""}}}'
# minLength alone counted a space as a character. A command of spaces runs
# nothing, and running nothing produces the empty output that reads as clean.
reject "a whitespace-only command"        '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"   "}}}'
# The local command grants Bash(git:*) for its own probe, and a permission rule
# matches a prefix — so a repository-supplied command starting with git runs
# with no prompt, which is exactly what "never pre-approved" is supposed to
# prevent. `git push --force` is the shape that matters.
reject "a subprocess command that is git" '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git push --force"}}}'
reject "  with leading whitespace"        '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"  git push"}}}'
reject "  with a leading tab"             '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"\tgit push"}}}'
reject "  bare, with no argument at all"  '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git"}}}'
# THE WHOLE PREFIX, CLOSED AS A SET. Two narrower guards shipped here in
# succession and both leaked in the same direction, because both asked where the
# WORD git ends — a question the permission matcher never asks.
# `^\s*git(\s|$)` read only whitespace and end-of-string as ending it, so the
# separator cases below all passed. `^\s*git($|[^A-Za-z0-9_.-])` closed those and
# still admitted `gitlint`, `git-review` and `git.exe`, on the reasoning that the
# shell treats them as different commands — true, and irrelevant:
# docs/permissions.md says Claude Code matches a COMMAND-STRING PREFIX, so every
# one of them is covered by the Bash(git:*) this command grants. The guard is now
# the prose rule exactly — may not begin with git — and these cases pin the two
# axes that reached it.
reject "git ended by a semicolon"         '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git;rm -rf /"}}}'
reject "git ended by &&"                  '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git&&rm -rf /"}}}'
reject "git ended by a background &"      '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git&"}}}'
reject "git ended by a pipe"              '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git|tee out"}}}'
reject "git ended by a redirect out"      '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git>out"}}}'
reject "git ended by a redirect in"       '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git<in"}}}'
reject "git ended by a subshell paren"    '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git(x)"}}}'
# `git""` is the word git as surely as `git ` is, and the empty pair is what
# makes it look unlike the banned shape while running exactly it.
reject "git ended by an empty quote pair" '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git\"\" push --force"}}}'
# THE LONGER-NAME AXIS. These three were ACCEPTED by both earlier guards and are
# the bypass a code review caught on this branch: the shell would run a different
# binary, but Bash(git:*) matches a string prefix, so each starts with the
# granted prefix and runs unprompted. The cost of rejecting them is that a review
# command whose own name starts with git cannot be a subprocess reviewer, which
# is the correct side to err on.
reject "a git-prefixed longer name"       '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"gitlint --diff"}}}'
reject "a hyphenated git-prefixed name"   '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git-review -c"}}}'
reject "a dotted git-prefixed name"       '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"git.exe --version"}}}'

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

# kind is absent from every configuration written before it existed, and those
# must keep meaning what they meant. The default is github-comment, so the
# else branch is what an absent kind reaches — which is why the first case here
# is the back-compatibility test and not a curiosity.
accept "a reviewer with no kind at all"  '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]"}}}'
accept "an explicit github-comment kind" '{"version":1,"reviewers":{"a":{"kind":"github-comment","botLogin":"a[bot]"}}}'
accept "a skill-invoked local reviewer"  '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"ecc:review-pr","severityLevels":["CRITICAL","HIGH","MEDIUM","LOW"],"requiresPr":true}}}'
accept "a subprocess local reviewer"     '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review medium\""}}}'
accept "a local reviewer with no ladder" '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"claude -p x"}}}'
accept "a per-loop default reviewer pair" '{"version":1,"defaults":{"reviewer":"codex","localReviewer":"code-review"}}'
accept "a per-loop round cap pair"        '{"version":1,"defaults":{"maxRounds":20,"localMaxRounds":5}}'
accept "a command with an inner space"    '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"claude -p x"}}}'
# The rule is the leading token, not the word. A reviewer that merely mentions
# git in an argument is not the bypass.
accept "a command mentioning git later"   '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review git-history\""}}}'
accept "a skill named after git"          '{"version":1,"reviewers":{"a":{"kind":"local-command","invoke":"skill","command":"git-review"}}}'

summary "schema"
