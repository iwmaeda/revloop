#!/usr/bin/env bash
# Validates the shipped examples against the schema, and — more importantly —
# checks that the schema REJECTS the shapes it is supposed to reject.
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

# Exit 2 means the validator never ran (unreadable file, schema that does not
# compile). Folding that into "invalid" would let every reject case below pass
# for the wrong reason, so it is reported instead of counted.
v() {
  node "$ROOT/tests/validate-schema.mjs" "$S" "$1" >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 2 ] && { printf '  FAIL validator could not run on %s\n' "$1"; FAIL=$((FAIL + 1)); }
  return "$rc"
}

# THE REVIEWER OBJECT HAS ITS OWN SCHEMA NOW, because it has its own files: the
# five definitions this plugin ships under reviewers/, and whatever a user names
# with --config. It is no longer reachable through .revloop.json at all, so a
# case that wrapped a reviewer in {version, reviewers} would now be rejected for
# the wrong reason -- an unknown top-level key -- and every reject below would
# pass while asserting nothing about the reviewer rules.
SR="$ROOT/schema/reviewer.schema.json"
rv() {
  node "$ROOT/tests/validate-schema.mjs" "$SR" "$1" >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 2 ] && { printf '  FAIL reviewer validator could not run on %s\n' "$1"; FAIL=$((FAIL + 1)); }
  return "$rc"
}

# TWO FAMILIES OF EXAMPLE, VALIDATED AGAINST TWO SCHEMAS, and the file name says
# which: revloop.*.json is a .revloop.json, reviewer.*.json is a definition of the
# kind --config takes. Routing on the prefix rather than on the content is what
# makes a misnamed example fail here instead of validating against the schema it
# happened to fit.
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
#
# These are the files the built-in commands drive, and they are shipped
# configuration exactly as the examples are. They used to live as fenced ```json
# blocks inside the cards, extracted by awk and wrapped in two levels before they
# could be validated at all. THEY ARE FILES NOW, so the extraction and the
# wrapping are both gone -- and with them the failure where a card that lost its
# fence was silently skipped rather than failed.
#
# THE FLOOR IS STILL THE POINT. A broken glob validates nothing and goes green,
# which is the same guard the `allowed-tools` block in `permissions.test.sh`
# states for the same reason. Five reviewers ship; the floor is five.
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

# EVERY DEFINITION HAS A CARD AND EVERY CARD HAS A DEFINITION. The pairing is the
# whole reason the two files share a stem: the definition is what the loop loads
# and the card is what says whether anyone has watched it work, and one without
# the other is either a reviewer nobody measured or a measurement of a reviewer
# nothing can drive. Both directions, because they fail differently.
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

# THE FILE NAME IS THE NAME, so there is no name key to drift from it. A stem
# that cannot go in the trigger marker is the one that would fail at runtime
# rather than here: the pull-request procedure writes it as reviewer=<name> and
# the wait fence parses that marker as space-separated key=value pairs.
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
# A github-comment reviewer with no trigger cannot be driven -- the procedure has
# only the comment path -- so the schema now catches it rather than leaving it to
# step 1's reason=no-comment-trigger abort.
rreject "github-comment without trigger" '{"botLogin":"a[bot]"}'
# The wait fence splits a comment's marker on the literal 'revloop:trigger ', so a
# trigger carrying that literal collides with the fence's own marker parsing --
# see the trap in procedures/remote-loop.md. Only the exact literal is banned, not
# the word "trigger" on its own.
rreject "trigger containing the literal marker key" '{"botLogin":"a[bot]","trigger":"see revloop:trigger below"}'
reject "malformed timeout"          '{"version":1,"defaults":{"timeout":"30x"}}'
reject "maxRounds below 1"          '{"version":1,"defaults":{"maxRounds":0}}'
rreject "unknown markerTolerated" '{"botLogin":"a[bot]","markerTolerated":"maybe"}'

# Keys that were removed because nothing consumed them. A schema that still
# accepted them would let a user configure something and watch it be ignored.
rreject "verdictOn (fence watches both)" '{"botLogin":"a[bot]","verdictOn":["reviews"]}'
rreject "ignoreCommentPatterns (in fence)" '{"botLogin":"a[bot]","ignoreCommentPatterns":["^x"]}'
reject "a configured merge method"       '{"version":1,"project":{"pr":{"mergeMethod":"squash"}}}'

# The two that matter most: .revloop.json comes from the repository you are in.
# A repository that could set these would grant its own merge and delete both
# human confirmation points. The flag is the approval.
reject "merge defaulted from config" '{"version":1,"defaults":{"merge":true}}'
reject "auto defaulted from config"  '{"version":1,"defaults":{"auto":true}}'

# The rigor level is the same class as the two above and has no key at all, so
# it is rejected wherever a reader might reach for one. A repository that could
# set its own --rigor would lower its own review bar on a checkout you just
# cloned, while the run still reported a clean convergence. Its predecessor's
# spelling is pinned beside it: a key removed from the schema is only removed
# while additionalProperties keeps refusing it, and the reader most likely to
# reintroduce one is the reader migrating from the old name.
reject "rigor defaulted from config"      '{"version":1,"defaults":{"rigor":"minimal"}}'
rreject "rigor on a reviewer" '{"botLogin":"a[bot]","rigor":"minimal"}'
reject "acceptAt defaulted from config"   '{"version":1,"defaults":{"acceptAt":"HIGH"}}'
rreject "acceptAt on a reviewer" '{"botLogin":"a[bot]","acceptAt":"P2"}'

# GRADING IS NOT ADDRESSABLE AT ALL, so the key that would have switched it on is
# rejected on both surfaces. It was a flag until 0.7.0 and is now a consequence of
# the reviewer's shape: it fires iff the resolved level has an acceptable band
# and the definition declares no severityLevels. A repository that could switch it on would decide,
# for a checkout you just cloned, that its reviewer's silence is no obstacle to
# converging -- and one that could switch it OFF would turn an estimated floor
# back into an abort under a run that had asked for neither.
reject "gradeSeverity from config"        '{"version":1,"defaults":{"gradeSeverity":true}}'
rreject "gradeSeverity on a reviewer" '{"botLogin":"a[bot]","gradeSeverity":true}'

# --- the two reviewer kinds ------------------------------------------------
#
# The kinds share one object with additionalProperties:false, so every key of
# both is declared and the separation is enforced by if/then rather than by two
# schemas. That means the cases below are the only evidence the separation holds
# at all: an if/then that never fires accepts everything, and looks identical to
# one that fires and passes.
rreject "local-command without invoke" '{"kind":"local-command","command":"x"}'
rreject "local-command without command" '{"kind":"local-command","invoke":"skill"}'
rreject "local-command with botLogin" '{"kind":"local-command","invoke":"skill","command":"x","botLogin":"a[bot]"}'
rreject "local-command with trigger" '{"kind":"local-command","invoke":"skill","command":"x","trigger":"@a review"}'
# `cleanPatterns` STAYS OUT WHILE `rateLimitPatterns` CROSSED, and the pair is the
# evidence that the split is still a rule rather than a habit. The local loop now
# reads a rate-limit pattern -- step 8's first row matches one against the review
# subprocess's stdout -- so the key has a consumer there and is accepted below. A
# clean phrase has none: that loop's clean signal is that NO FINDING WAS PARSED,
# so there is nothing for a phrase to match, and a key nothing reads is the defect
# the kind split exists to prevent. It is also the one pattern in this file that
# could turn a failure into a convergence, where a rate-limit pattern can only
# ever abort.
rreject "local-command with cleanPatterns" '{"kind":"local-command","invoke":"skill","command":"x","cleanPatterns":["^ok"]}'
rreject "local-command with markerTolerated" '{"kind":"local-command","invoke":"skill","command":"x","markerTolerated":"verified"}'
rreject "unknown invoke" '{"kind":"local-command","invoke":"exec","command":"x"}'
rreject "unknown kind" '{"kind":"webhook","botLogin":"a[bot]"}'
rreject "a skill name with a space" '{"kind":"local-command","invoke":"skill","command":"ecc:review pr"}'
rreject "a skill name with a slash" '{"kind":"local-command","invoke":"skill","command":"../../evil"}'
rreject "a command with a newline" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x\nrm -rf /"}'
rreject "an empty severityLevels ladder" '{"botLogin":"a[bot]","severityLevels":[]}'
# The map is present here so that uniqueItems is what rejects this rather than
# the ladder-needs-a-map pairing below -- without it the case passes for a
# reason it was not written to test, and uniqueItems goes unexercised.
rreject "a ladder with a repeated rung" '{"botLogin":"a[bot]","severityLevels":["P1","P1"],"severityMap":{"P1":"critical"}}'

# severityMap carries the reviewer's ladder onto revloop's canonical one, which
# is the ladder every --rigor level's floor is expressed on. A value outside that
# ladder names a rung no floor can ever be measured against; a map with no ladder
# to map FROM is a key with no consumer; and A LADDER WITH NO MAP IS THE SAME
# DEFECT SEEN FROM THE OTHER SIDE -- a vocabulary that can never reach a floor.
# dependentRequired states the pair in both directions, and the second direction
# is what replaced a runtime abort (reason=no-severity-map): a structural rule
# belongs where the structure is validated, and a runtime check for a shape the
# schema can express only fires on the runs that reach it. None of the map's totality,
# its ordering, or whether it collapses the whole ladder onto one canonical rung
# is checkable here — the schema cannot read the other key's contents, and it
# cannot compare values across keys it does not know the names of — so step 1
# aborts on all three with reason=bad-severity-map, and these cases are all the
# schema half can carry.
rreject "a map onto a rung off the ladder" '{"botLogin":"a[bot]","severityLevels":["P1"],"severityMap":{"P1":"blocker"}}'
rreject "a map with no severityLevels" '{"botLogin":"a[bot]","severityMap":{"P1":"critical"}}'
rreject "a ladder with no severityMap" '{"botLogin":"a[bot]","severityLevels":["P1","P2"]}'
rreject "an empty severityMap" '{"botLogin":"a[bot]","severityLevels":["P1"],"severityMap":{}}'

# The other direction: a github-comment reviewer may not carry the local keys.
# Without this the two kinds would share every key and `kind` would be a label
# rather than a discriminator — a local reviewer could be given a botLogin the
# local loop never reads, and a GitHub reviewer a command nothing ever runs.
rreject "github-comment with a command" '{"botLogin":"a[bot]","command":"x"}'
rreject "github-comment with invoke" '{"botLogin":"a[bot]","invoke":"skill"}'
rreject "github-comment with requiresPr" '{"botLogin":"a[bot]","requiresPr":true}'
# An empty command validates as a string and runs as nothing, and "the reviewer
# returned no findings" is what running nothing looks like.
rreject "an empty subprocess command" '{"kind":"local-command","invoke":"subprocess","command":""}'
rreject "an empty skill name" '{"kind":"local-command","invoke":"skill","command":""}'
# minLength alone counted a space as a character. A command of spaces runs
# nothing, and running nothing produces the empty output that reads as clean.
rreject "a whitespace-only command" '{"kind":"local-command","invoke":"subprocess","command":"   "}'
# The local command grants Bash(git:*) for its own probe, and a permission rule
# matches a prefix — so a repository-supplied command starting with git runs
# with no prompt, which is exactly what "never pre-approved" is supposed to
# prevent. `git push --force` is the shape that matters.
rreject "a subprocess command that is git" '{"kind":"local-command","invoke":"subprocess","command":"git push --force"}'
rreject "  with leading whitespace" '{"kind":"local-command","invoke":"subprocess","command":"  git push"}'
rreject "  with a leading tab" '{"kind":"local-command","invoke":"subprocess","command":"\tgit push"}'
rreject "  bare, with no argument at all" '{"kind":"local-command","invoke":"subprocess","command":"git"}'
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
rreject "git ended by a semicolon" '{"kind":"local-command","invoke":"subprocess","command":"git;rm -rf /"}'
rreject "git ended by &&" '{"kind":"local-command","invoke":"subprocess","command":"git&&rm -rf /"}'
rreject "git ended by a background &" '{"kind":"local-command","invoke":"subprocess","command":"git&"}'
rreject "git ended by a pipe" '{"kind":"local-command","invoke":"subprocess","command":"git|tee out"}'
rreject "git ended by a redirect out" '{"kind":"local-command","invoke":"subprocess","command":"git>out"}'
rreject "git ended by a redirect in" '{"kind":"local-command","invoke":"subprocess","command":"git<in"}'
rreject "git ended by a subshell paren" '{"kind":"local-command","invoke":"subprocess","command":"git(x)"}'
# `git""` is the word git as surely as `git ` is, and the empty pair is what
# makes it look unlike the banned shape while running exactly it.
rreject "git ended by an empty quote pair" '{"kind":"local-command","invoke":"subprocess","command":"git\"\" push --force"}'
# THE LONGER-NAME AXIS. These three were ACCEPTED by both earlier guards and are
# the bypass a code review caught on this branch: the shell would run a different
# binary, but Bash(git:*) matches a string prefix, so each starts with the
# granted prefix and runs unprompted. The cost of rejecting them is that a review
# command whose own name starts with git cannot be a subprocess reviewer, which
# is the correct side to err on.
rreject "a git-prefixed longer name" '{"kind":"local-command","invoke":"subprocess","command":"gitlint --diff"}'
rreject "a hyphenated git-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"git-review -c"}'
rreject "a dotted git-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"git.exe --version"}'

# THE SAME RULE, APPLIED TO THE SECOND GRANT. The local command pushes and opens
# a pull request by default, so it holds four gh prefixes — `gh pr create`,
# `gh pr list`, `gh repo view` and `gh api -X PATCH repos/{owner}/{repo}/` — and
# each is a pre-approved slot exactly as Bash(git:*) is. The ban is on bare `gh`, DELIBERATELY WIDER THAN THE
# GRANTS: four spellings would have to track a grant list that every future step
# can extend, and a ban lagging its grants by one release is the hole itself. So
# the axes pinned for git are pinned again here, including the longer-name one
# that both earlier git guards leaked on.
rreject "a subprocess command that is gh" '{"kind":"local-command","invoke":"subprocess","command":"gh pr merge 1"}'
rreject "  gh with leading whitespace" '{"kind":"local-command","invoke":"subprocess","command":"  gh pr create"}'
rreject "  gh with a leading tab" '{"kind":"local-command","invoke":"subprocess","command":"\tgh repo view"}'
rreject "  gh bare" '{"kind":"local-command","invoke":"subprocess","command":"gh"}'
rreject "gh ended by a semicolon" '{"kind":"local-command","invoke":"subprocess","command":"gh;rm -rf /"}'
rreject "a gh-prefixed longer name" '{"kind":"local-command","invoke":"subprocess","command":"ghreview --diff"}'
rreject "a hyphenated gh-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"gh-review -c"}'
rreject "a dotted gh-prefixed name" '{"kind":"local-command","invoke":"subprocess","command":"gh.exe --version"}'

# THE SAME HOLE, REACHED THROUGH EXPANSION. {reviewModel} is substituted before
# the command runs, so a placeholder at position 0 lets the VALUE decide the
# leading token — and the value is an operator-typed flag. `--review-model git`
# against the first command below expands to `git push --force`, which matches
# the granted prefix and runs with no prompt: the two bans above, defeated by
# something that arrives after they were checked. The procedure also re-checks
# the expanded string, because a static rule about a template is not a rule
# about what ran; this makes the shape unwritable in the first place.
rreject "a leading {reviewModel}" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel} push --force"}'
rreject "  a leading placeholder, spaced" '{"kind":"local-command","invoke":"subprocess","command":"  {reviewModel} -p x"}'
# THE SAME AXES THE TWO BANS ABOVE PIN, because this is the same kind of rule —
# a literal string prefix — and an enumeration thinner than its siblings' is a
# claim that this prefix has fewer ways to be written, which is not true of any
# of the three. What ends the placeholder is not whitespace: every form below
# begins with it, so every one is banned, and the shell would run each of them.
rreject "placeholder ended by a semicolon" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel};rm -rf /"}'
rreject "placeholder ended by an &&" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}&&rm -rf /"}'
rreject "placeholder ended by a pipe" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}|tee out"}'
rreject "placeholder ended by a redirect" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}>out"}'
# The longer-name axis, which is the one both earlier git guards leaked on. A
# joined suffix does not stop the string from beginning with the placeholder.
rreject "a placeholder-prefixed longer name" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}lint --diff"}'
rreject "  a bare placeholder" '{"kind":"local-command","invoke":"subprocess","command":"{reviewModel}"}'

# --review-model has no config key, for a sharper reason than --merge and
# --auto: its value is expanded INTO A COMMAND LINE, so a key here would be the
# first thing this project interpolates into a shell command out of a
# repository-supplied file. There is likewise no per-reviewer model key.
reject "reviewModel defaulted from config" '{"version":1,"defaults":{"reviewModel":"sonnet"}}'
reject "localReviewModel from config"     '{"version":1,"defaults":{"localReviewModel":"sonnet"}}'
rreject "a model key on a reviewer" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x","model":"sonnet"}'

# The local loop PUBLISHES BY DEFAULT, and --no-publish turns that off. So the
# usual argument for keeping a flag out of config does not reach it: a key here
# could only remove an action, and removing one grants nothing. These cases pin
# a NOT YET rather than a NEVER — the schema is closed by additionalProperties,
# so adding the key is a deliberate act with a test to delete, not a drift.
reject "publish defaulted from config"    '{"version":1,"defaults":{"publish":true}}'
reject "noPublish defaulted from config"  '{"version":1,"defaults":{"noPublish":true}}'
reject "localPublish defaulted from config" '{"version":1,"defaults":{"localPublish":false}}'

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

# kind is absent from every configuration written before it existed, and those
# must keep meaning what they meant. The default is github-comment, so the
# else branch is what an absent kind reaches — which is why the first case here
# is the back-compatibility test and not a curiosity.
raccept "a reviewer with no kind at all" '{"botLogin":"a[bot]","trigger":"@a review"}'
raccept "an explicit github-comment kind" '{"kind":"github-comment","botLogin":"a[bot]","trigger":"@a review"}'
# Only the exact literal 'revloop:trigger' is banned, not the word "trigger" on
# its own -- this pins that the fix above is not overbroad.
raccept "a trigger that just mentions the word trigger" '{"botLogin":"a[bot]","trigger":"@a review triggers a run"}'
raccept "a skill-invoked local reviewer" '{"kind":"local-command","invoke":"skill","command":"ecc:review-pr","severityLevels":["CRITICAL","HIGH","MEDIUM","LOW"],"severityMap":{"CRITICAL":"critical","HIGH":"high","MEDIUM":"medium","LOW":"low"},"requiresPr":true}'
raccept "a subprocess local reviewer" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review medium\""}'
raccept "a local reviewer with no ladder" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x"}'
# WHICH REVIEWER RUNS IS NOT A KEY AND CANNOT BECOME ONE. It is decided by which
# command was typed, so there is nothing to default -- and a repository that
# could choose your reviewer would choose which bot login the wait fence filters
# on and which rungs your acceptance floor is measured against. These two were an
# accept case until the commands split; they are the migration, pinned.
reject "a default reviewer"       '{"version":1,"defaults":{"reviewer":"codex"}}'
reject "a default local reviewer" '{"version":1,"defaults":{"localReviewer":"code-review"}}'
reject "a reviewers map"          '{"version":1,"reviewers":{"a":{"botLogin":"a[bot]"}}}'
accept "a per-loop round cap pair"        '{"version":1,"defaults":{"maxRounds":20,"localMaxRounds":5}}'
raccept "a command with an inner space" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x"}'
# The rule is the leading token, not the word. A reviewer that merely mentions
# git in an argument is not the bypass.
raccept "a command mentioning git later" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review git-history\""}'
raccept "a skill named after git" '{"kind":"local-command","invoke":"skill","command":"git-review"}'
# The gh ban is the leading token too. A command that merely names gh in an
# argument is not the bypass, and a skill name is not a shell command at all —
# no Bash rule ever sees one, which is the documented way out of both bans.
raccept "a command mentioning gh later" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review gh-actions\""}'
raccept "a skill named after gh" '{"kind":"local-command","invoke":"skill","command":"gh-review"}'

# The two shipped presets, in the form they ship. Both carry {reviewModel}, so
# both are pinned to the builtin sonnet unless --review-model says otherwise,
# and neither begins with the placeholder.
raccept "the shipped code-review preset" '{"kind":"local-command","invoke":"subprocess","command":"claude --model {reviewModel} -p \"/code-review medium\""}'
# No ladder, because the shipped definition has none: five measured rounds
# disproved the one its card used to claim. A fixture carrying a ladder the
# shipped file does not is a fixture pinning a preset that was never shipped.
raccept "the shipped ecc-review-pr preset" '{"kind":"local-command","invoke":"subprocess","command":"claude --model {reviewModel} -p \"/ecc:review-pr\"","requiresPr":true,"rateLimitPatterns":["You'"'"'ve hit your session limit"]}'
# A command with no placeholder stays valid: it is simply not pinned by the
# loop, and the step-1 table says so rather than pretending it is.
raccept "a subprocess command, unpinned" '{"kind":"local-command","invoke":"subprocess","command":"claude -p \"/code-review medium\""}'

# The map belongs to both kinds, exactly as the ladder does, and the canonical
# rungs are the only values it may name. The identity case is not a curiosity:
# a reviewer emitting the canonical words already still needs a map, because the
# pairing is structural rather than a shortcut the schema could see through.
raccept "a github reviewer with a map" '{"botLogin":"a[bot]","trigger":"@a review","severityLevels":["P1","P2","P3"],"severityMap":{"P1":"critical","P2":"high","P3":"low"}}'
raccept "a local reviewer with a map" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x","severityLevels":["CRITICAL","HIGH","MEDIUM","LOW"],"severityMap":{"CRITICAL":"critical","HIGH":"high","MEDIUM":"medium","LOW":"low"}}'

# The key that crossed. Both shipped local presets now carry one, so this pins the
# kind branch that used to reject it -- and the rejection above pins that its
# sibling did not cross with it. Without both, "the kinds are separate" and "the
# kinds share everything" look identical from the test suite.
raccept "a local reviewer with a rate limit" '{"kind":"local-command","invoke":"subprocess","command":"claude -p x","rateLimitPatterns":["out of quota"]}'
raccept "a github reviewer with one too" '{"botLogin":"a[bot]","trigger":"@a review","rateLimitPatterns":["quota exceeded"]}'

# A five-rung ladder cannot reach four canonical rungs without two rungs sharing
# one, so MERGING is not the defect step 1 rejects -- collapsing every rung onto
# ONE is. The schema can tell neither apart, which is why the check is in step 1;
# this case pins that the schema does not pre-empt the legal half of it either.
# Nothing else here pins a ladder longer than the canonical one at all.
raccept "a five-rung ladder sharing a rung" '{"botLogin":"a[bot]","trigger":"@a review","severityLevels":["S0","S1","S2","S3","S4"],"severityMap":{"S0":"critical","S1":"high","S2":"high","S3":"medium","S4":"low"}}'

summary "schema"
