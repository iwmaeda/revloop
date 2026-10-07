#!/usr/bin/env bash
# Pins the one-runner rule's sentences to the places that cite them: the
# preamble and step 10 of procedures/remote-loop.md, the citations in
# procedures/local-loop.md, and each file's `## Unexercised paths` entry.
# Only the presence and position of the text are checked.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "one-runner:"

R="$ROOT/procedures/remote-loop.md"
L="$ROOT/procedures/local-loop.md"

# Each region is cut out and flattened to one line: the prose wraps at 100
# columns and `expect` matches within a line.
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

# The cuts themselves, on a synthetic file.
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

# The entry's opening is refuted because step 10's prose names the heading itself.
refute "remote step 10 was cut before the Unexercised entry" "$RFIX" \
  "- **The preamble's one-runner rule, and step 10's hand-off.**"
refute "local step 9 was cut before the Unexercised entry" "$LFIX" \
  '- **The one-runner rule, on this procedure.**'

# --- remote preamble ---
expect "remote preamble names the one runner" "$RPRE" \
  '**One session runs this procedure: the one the command was invoked in.**'
expect "and says a started session holding the file is not it" "$RPRE" \
  'not even one that holds this whole file in its context'
expect "and lists what that session does not do" "$RPRE" \
  'it does not stage, commit, push, post, trigger, wait, merge or sweep unless the brief says so in those words'
expect "and sends the reader to step 10" "$RPRE" \
  '**Step 10 says what handing off an edit owes**'

# --- remote step 10, the step the preamble and the local procedure cite ---
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

# --- local procedure: the rule by citation only ---
# shellcheck disable=SC2016
expect "local preamble cites the remote rule" "$LPRE" \
  '[`remote-loop.md`](remote-loop.md) states the rule once for both.**'
expect "and names the step the hand-off is in" "$LPRE" \
  'its step 10 says what handing off an edit owes'
expect "and says what may leave the session here" "$LPRE" \
  "**Step 9's edit is the one thing that may leave this session**"
expect "local step 9 cites the hand-off rule" "$LFIX" \
  "**That step's hand-off rule is this step's too, and it is not restated either**"

# --- the Unexercised paths entries ---
expect "remote Unexercised paths carries the entry" "$RUNX" \
  "- **The preamble's one-runner rule, and step 10's hand-off.**"
expect "and says it does not fail closed" "$RUNX" \
  '**None of this fails closed.**'
expect "local Unexercised paths carries its own" "$LUNX" \
  '- **The one-runner rule, on this procedure.**'

summary "one-runner"
