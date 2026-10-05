#!/usr/bin/env bash
# One session runs a procedure, and the procedure says so in four places. This
# pins the four.
#
# `procedures/remote-loop.md` states the rule twice: its preamble says who "you"
# is, and its step 10 says what handing an edit to another agent owes.
# `procedures/local-loop.md` states it nowhere. It points at those two places and
# says both apply unchanged, which is what CONTRIBUTING asks of it -- and it is
# also the whole risk: reword the remote opening, or move the hand-off out of
# step 10, and the local procedure is left citing a rule that is no longer there,
# with every other suite still green.
#
# THIS IS A TRIPWIRE FOR THE CITATION, NOT A TEST OF THE BEHAVIOUR. The rule is
# prose addressed to an agent, and the failure it answers was an agent that did
# not do what its brief said. No grep shows that the next one will. What can be
# shown is that the sentences exist, sit in the step the other file names, and
# are still followed by the entry in `## Unexercised paths` that says none of it
# has been measured -- so the rule cannot quietly lose the admission beside it.
#
# REGIONS ARE CUT BEFORE THEY ARE READ, because the same words appear in more
# than one place on purpose. "One session runs this procedure" in the preamble
# and an echo of it further down are different facts, and a whole-file grep
# reads them as one. Each region is flattened to a single line first: the
# sentences are wrapped at 100 columns and `expect` matches within a line, so an
# unflattened region fails on every anchor that happens to cross a wrap, and
# passes again after a reflow that changed nothing.
#
# WHAT THIS DOES NOT CATCH is a paraphrase that keeps the anchors and loses the
# meaning, and anything outside the two procedures: the commands and the Codex
# router carry no copy of the rule, deliberately, so there is nothing of theirs
# to pin.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "one-runner:"

R="$ROOT/procedures/remote-loop.md"
L="$ROOT/procedures/local-loop.md"

flat() { tr '\n' ' ' | tr -s ' '; }
before() { # before <file> <end-regex> -> every line above the first match
  awk -v e="$2" '$0 ~ e { exit } { print }' "$1" | flat
}
between() { # between <file> <start-regex> <end-regex> -> start line up to, not including, end
  awk -v s="$2" -v e="$3" 'on && $0 ~ e { exit } $0 ~ s { on = 1 } on { print }' "$1" | flat
}
from() { # from <file> <start-regex> -> start line to the end of the file
  awk -v s="$2" '$0 ~ s { on = 1 } on { print }' "$1" | flat
}

# The cuts are predicates, and a cut that runs past its end marker makes every
# assertion below it vacuous: step 10 would then contain the Unexercised entry,
# which repeats half of these anchors.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'top\n## When to run it\n9. nine\nbody\n10. ten\n11. eleven\n## Unexercised paths\ntail\n' > "$TMP/p.md"
expect "before stops at its marker"    "$(before "$TMP/p.md" '^## When to run it')|" 'top |'
expect "between starts on its marker"  "$(between "$TMP/p.md" '^10[.] ' '^11[.] ')|" '10. ten |'
refute "and stops before the next one" "$(between "$TMP/p.md" '^10[.] ' '^11[.] ')" 'eleven'
refute "and does not start early"      "$(between "$TMP/p.md" '^10[.] ' '^11[.] ')" 'nine'
expect "from runs to the end"          "$(from "$TMP/p.md" '^## Unexercised paths')" 'tail'

RPRE=$(before "$R" '^## When to run it')
RFIX=$(between "$R" '^10[.] ' '^11[.] ')
RUNX=$(from "$R" '^## Unexercised paths')
LPRE=$(before "$L" '^## When to run it')
LFIX=$(between "$L" '^9[.] ' '^10[.] ')
LUNX=$(from "$L" '^## Unexercised paths')

# Asked of the entry's own opening and not of the heading: step 10 names
# `## Unexercised paths` in its prose, so the heading is in the region whether or
# not the cut held, and a refute on it failed against a correct file.
refute "remote step 10 was cut before the Unexercised entry" "$RFIX" \
  "- **The preamble's one-runner rule, and step 10's hand-off.**"
refute "local step 9 was cut before the Unexercised entry" "$LFIX" \
  '- **The one-runner rule, on this procedure.**'

# The preamble: who "you" is, what a started session never does, and where the
# rest of the rule is.
expect "remote preamble names the one runner" "$RPRE" \
  '**One session runs this procedure: the one the command was invoked in.**'
expect "and says a started session holding the file is not it" "$RPRE" \
  'not even one that holds this whole file in its context'
expect "and lists what that session does not do" "$RPRE" \
  'it does not stage, commit, push, post, trigger, wait, merge or sweep unless the brief says so in those words'
expect "and sends the reader to step 10" "$RPRE" \
  '**Step 10 says what handing off an edit owes**'

# Step 10: the number the preamble and the local procedure both cite. If the
# hand-off moves to another step these fail, which is the point -- the citations
# would then be wrong and nothing else would say so.
expect "remote step 10 allows the edit and nothing else" "$RFIX" \
  '**The edit may be handed to another agent. Nothing else in a round may, and the agent must start without this conversation.**'
expect "and forbids an agent that inherits the context" "$RFIX" \
  "**Never hand any of it to an agent that inherits this session's context**"
expect "and says what the brief names" "$RFIX" \
  '**Write the brief for a reader who has never seen this file**'
expect "and checks HEAD on return" "$RFIX" \
  '**When it returns, and before step 3, check that it only edited.**'
expect "and says what two runners owe" "$RFIX" \
  '**If HEAD moved, there are two runners. Stop the one you started before anything else**'

# The local procedure holds the rule by citation only. The backticks are the
# link's own markup and must reach grep unevaluated.
# shellcheck disable=SC2016
expect "local preamble cites the remote rule" "$LPRE" \
  '[`remote-loop.md`](remote-loop.md) states the rule once for both.**'
expect "and names the step the hand-off is in" "$LPRE" \
  'its step 10 says what handing off an edit owes'
expect "and says what may leave the session here" "$LPRE" \
  "**Step 9's edit is the one thing that may leave this session**"
expect "local step 9 cites the hand-off rule" "$LFIX" \
  "**That step's hand-off rule is this step's too, and it is not restated either**"

# The admission travels with the rule.
expect "remote Unexercised paths carries the entry" "$RUNX" \
  "- **The preamble's one-runner rule, and step 10's hand-off.**"
expect "and says it does not fail closed" "$RUNX" \
  '**None of this fails closed.**'
expect "local Unexercised paths carries its own" "$LUNX" \
  '- **The one-runner rule, on this procedure.**'

summary "one-runner"
