#!/usr/bin/env bash
# Exercises the jq programs of the three reads steps 9, 10 and 11 of
# procedures/remote-loop.md use to take a review's findings off a pull request:
# the review header, the findings, and the replies under them. They are prose
# reads rather than fences -- prefix-granted `gh api` calls with placeholders --
# so no fence test reaches them, and until this file nothing ran them at all.
#
# Two more reads are lifted the same way, and for the same reason: step 7's
# read of the round's trigger markers, and step 10's read of the review list.
# Both used to print what GitHub returned and leave the comparisons -- a
# marker's keys, forty characters against HEAD, a timestamp against a bound --
# to whoever read the rows. They print the answers now, so the answers are
# what is pinned below.
#
# The programs are lifted OUT of the procedure rather than restated here, so
# what is measured is what the procedure tells a run to type, and an edit there
# is measured here on the next run. The blocks are found by a marker,
# `<!-- revloop:read id=... -->`, the same way revloop-dir.test.sh finds its
# `revloop:file` block; it is not a fence marker, so nothing hashes these blocks
# and nothing requires them to be placeholder-free.
#
# Needs a jq binary -- pinned in mise.toml; `mise install` puts it on PATH.
# gh embeds gojq rather than jq. Two differences are known and neither is
# allowed to matter below: gh prints an object's keys sorted where jq keeps
# construction order, so every assertion reads a key BY NAME and none compares
# a whole row; and the constructs used (select, IN, split, a slice, map, test,
# length, the alternative operator) are the ones run against real payloads at
# the documented gh floor before this file was written. What that run covered
# is in the procedure's `## Unexercised paths`.
#
# `gh api --paginate` applies `--jq` to each page separately at that floor, so
# `run` below feeds one file per jq process and concatenates the output. A
# program that needed a second page to decide a row on the first would pass a
# single-file test and lose rows on a long pull request.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "findings-read:"

if ! command -v jq >/dev/null 2>&1; then
  echo "  note jq not installed; the read programs are not exercised here."
  echo "       (run 'mise install'.)"
  exit 0
fi

same() { # same <label> <actual> <expected> -- exact, unlike lib.sh's expect
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$3" "$2"
  fi
}

SRC="$ROOT/procedures/remote-loop.md"
FX="$ROOT/tests/fixtures/read"

# The bash block after a read marker, with the list indent of its opening fence
# removed -- the same shape extract-fences.sh reads for a shell fence.
block() { # block <id>
  awk -v marker="<!-- revloop:read id=$1 -->" '
    index($0, marker) { armed = 1; next }
    armed && !opened {
      line = $0
      sub(/^[ \t]*/, "", line)
      if (line == "```bash") {
        match($0, /^[ \t]*/)
        indent = RLENGTH
        opened = 1
      }
      next
    }
    opened {
      line = $0
      sub(/^[ \t]*/, "", line)
      if (line == "```") { exit }
      print substr($0, indent + 1)
    }
  ' "$SRC"
}

# Every `--jq '...'` program in a block, one per line, in block order. A
# trailing shell comment after the closing quote is allowed and dropped.
progs() { # progs <id>
  block "$1" | sed -n "s/.*--jq '\(.*\)'[[:space:]]*\(#.*\)\{0,1\}\$/\1/p"
}

# One jq process per file, as gh runs `--jq` once per page.
run() { # run <program> <file>...
  local p=$1 f
  shift
  for f in "$@"; do
    jq -rc "$p" < "$f" || return 1
  done
}

field() { # field <rows> <id> <jq-expression-on-the-row>
  printf '%s\n' "$1" | jq -rc "select(.id == $2) | $3"
}

COMMIT_PROGS=$(progs review-commit)
REVIEW_PROGS=$(progs per-review)
REPLY_PROGS=$(progs replies)
MARKER_PROGS=$(progs round-markers)
LIST_PROGS=$(progs review-list)

HEADER=$(printf '%s\n' "$REVIEW_PROGS" | sed -n 1p)
FINDINGS=$(printf '%s\n' "$REVIEW_PROGS" | sed -n 2p)
REPLIES=$(printf '%s\n' "$REPLY_PROGS" | sed -n 1p)
MARKERS=$(printf '%s\n' "$MARKER_PROGS" | sed -n 1p)
LIST=$(printf '%s\n' "$LIST_PROGS" | sed -n 1p)

# An extraction that found nothing would make every assertion below fail for the
# wrong reason -- or, on a later edit, pass over a block that no longer holds a
# read. Stop here instead, naming what is missing.
if [ -z "$HEADER" ] || [ -z "$FINDINGS" ] || [ -z "$REPLIES" ] || [ -z "$COMMIT_PROGS" ] \
  || [ -z "$MARKERS" ] || [ -z "$LIST" ]; then
  echo "  FAIL could not lift the read programs out of the procedure"
  echo "       review-commit: ${COMMIT_PROGS:-<none>}"
  echo "       per-review:    ${REVIEW_PROGS:-<none>}"
  echo "       replies:       ${REPLY_PROGS:-<none>}"
  echo "       round-markers: ${MARKER_PROGS:-<none>}"
  echo "       review-list:   ${LIST_PROGS:-<none>}"
  exit 1
fi

same "step 9's block holds one read"      "$(printf '%s\n' "$COMMIT_PROGS" | grep -c .)" "1"
same "the per-review block holds two"     "$(printf '%s\n' "$REVIEW_PROGS" | grep -c .)" "2"
same "step 11's block holds one"          "$(printf '%s\n' "$REPLY_PROGS" | grep -c .)" "1"
same "step 7's marker block holds one"    "$(printf '%s\n' "$MARKER_PROGS" | grep -c .)" "1"
same "the review-list block holds one"    "$(printf '%s\n' "$LIST_PROGS" | grep -c .)" "1"

# The header is one read invoked from two steps. Two spellings of it would be
# two reads, and "reading one half on one path and the other half on the other"
# is how step 10 says it has already failed twice.
same "step 9 and step 10 spell the header read alike" "$COMMIT_PROGS" "$HEADER"

# A single quote inside a program would end the shell word the procedure wraps
# it in. The extraction above is greedy, so it would lift such a program whole
# and hide the break.
for p in "$HEADER" "$FINDINGS" "$REPLIES" "$MARKERS" "$LIST"; do
  refute "a program holds no single quote" "$p" "'"
done

placeholders() { printf '%s\n' "$1" | grep -oE '<[A-Za-z_]+>' | sort -u | tr '\n' ' '; }
same "the header read takes no placeholder"        "$(placeholders "$HEADER")"   ""
same "the findings read takes the review ids only" "$(placeholders "$FINDINGS")" "<ids> "
same "the replies read takes the finding ids only" "$(placeholders "$REPLIES")"  "<commentIds> "
same "the marker read takes HEAD's oid only"       "$(placeholders "$MARKERS")"  "<oid> "
same "the list read takes HEAD's oid and a bound"  "$(placeholders "$LIST")"     "<oid> <since> "

# The marker block opens with the git call whose output <oid> is copied from.
# A read that named a value and no command to get it by would put the forty
# characters back in somebody's hands.
expect "the marker block prints HEAD the way the marker spells it" \
  "$(block round-markers)" "git log -1 --abbrev=8 --format='head=%h oid=%H'"

findings() { # findings <review-ids> <file>...
  local ids=$1
  shift
  run "${FINDINGS//<ids>/$ids}" "$@"
}
replies() { # replies <finding-ids> <file>...
  local ids=$1
  shift
  run "${REPLIES//<commentIds>/$ids}" "$@"
}

# --- recorded: iwmaeda/revloop#35, REST, 2026-10 ---------------------------
#
# MEASURED HERE: the programs against the bytes GitHub returned -- five findings
# by the reviewer, one per review, and the five replies this loop posted under
# them. Pretty-printed with jq on the way in and otherwise untouched.
REC="$FX/recorded"

o=$(run "$HEADER" "$REC/review.json")
same "the header carries the state"            "$(printf '%s\n' "$o" | jq -r .state)" "COMMENTED"
same "  and the commit, all forty characters"  "$(printf '%s\n' "$o" | jq -r .commit)" "05ce0b0c31e4813afc6fae07e0cf311d14687e8b"
same "  and the body, unshortened"             "$(printf '%s\n' "$o" | jq -r .body)" "$(jq -r .body "$REC/review.json")"
same "  on one line"                           "$(printf '%s\n' "$o" | grep -c .)" "1"

o=$(findings 5345478873 "$REC/comments.json")
same "one review id yields that review's finding"  "$(printf '%s\n' "$o" | jq -r .id)" "4127727186"
same "  bound to the review it came from"          "$(field "$o" 4127727186 .review)" "5345478873"
same "  with its path"                             "$(field "$o" 4127727186 .path)" ".agents/skills/revloop/SKILL.md"
same "  a null line falls back to original_line"   "$(field "$o" 4127727186 .line)" "23"
same "  and the range opens where it did"          "$(field "$o" 4127727186 .start)" "22"
same "  on a line comment, a null line is outdated" "$(field "$o" 4127727186 .outdated)" "true"
same "  the context is the hunk's tail"            "$(field "$o" 4127727186 '.context | length')" "6"
same "  ending on the hunk's last row"             "$(field "$o" 4127727186 '.context | last')" \
  "$(jq -r '.[] | select(.id == 4127727186) | .diff_hunk | split("\n") | last' "$REC/comments.json")"
same "  the body is carried whole"                 "$(field "$o" 4127727186 .body)" \
  "$(jq -r '.[] | select(.id == 4127727186) | .body' "$REC/comments.json")"

ALL_REVIEWS=5345317056,5345361481,5345400503,5345438000,5345478873
ALL_FINDINGS=4127584871,4127624328,4127659767,4127692750,4127727186
o=$(findings "$ALL_REVIEWS" "$REC/comments.json")
same "a list of review ids yields every finding in it" \
  "$(printf '%s\n' "$o" | jq -r .id | tr '\n' ',')" "$ALL_FINDINGS,"
same "  a finding still on the diff is not outdated" "$(field "$o" 4127584871 .outdated)" "false"
same "  and keeps its own line"                      "$(field "$o" 4127584871 .line)" "32"

same "an id nothing carries yields no row" "$(findings 1 "$REC/comments.json" | grep -c .)" "0"

# The read this one replaced took one review id and four keys. Run it beside
# the new one: on every key the old read printed, the two must agree, or this
# was a change rather than a generalisation.
OLD_FINDINGS='.[]|select(.pull_request_review_id==<id>)|{id,path,line:(.line // .original_line),body}'
old=""
for r in ${ALL_REVIEWS//,/ }; do
  old+=$(run "${OLD_FINDINGS//<id>/$r}" "$REC/comments.json" | jq -Sc .)$'\n'
done
same "the four keys the old read printed are unchanged" \
  "$(printf '%s\n' "$o" | jq -Sc '{id, path, line, body}')" "$(printf '%s' "$old")"

o=$(replies "$ALL_FINDINGS" "$REC/comments.json")
same "a list of finding ids yields every reply under them" "$(printf '%s\n' "$o" | grep -c .)" "5"
expect "  each row opens with the finding it answers" "$o" "4127727186 4127755765 iwmaeda 1347 round=5 v=1 round=5"
same "  and no finding is named twice" \
  "$(printf '%s\n' "$o" | cut -d' ' -f1 | sort -u | grep -c .)" "5"
same "  the scope is a field of its own, one per round" \
  "$(printf '%s\n' "$o" | cut -d' ' -f5 | tr '\n' ' ')" "round=1 round=2 round=3 round=4 round=5 "

# The scope field is the one thing this row gained. Take it out and what is left
# is what the read printed before -- which is what makes the field an addition
# and the rest of the row a thing nothing downstream has to re-learn.
OLD_REPLIES='.[]|select(.in_reply_to_id==<commentId>)|"\(.id) \(.user.login) \(.body|length) \(if (.body|test("<!-- revloop:reply [A-Za-z0-9=._ -]*-->")) then (.body|split("<!-- revloop:reply ")[1]|split(" -->")[0]) else "no-marker" end)"'
old=""
for c in ${ALL_FINDINGS//,/ }; do
  old+=$(run "${OLD_REPLIES//<commentId>/$c}" "$REC/comments.json")$'\n'
done
same "past the leading id and the scope, a row is the row the old read printed" \
  "$(printf '%s\n' "$o" | cut -d' ' -f2-4,6-)" "$(printf '%s' "$old")"

# --- forms: hand-written, because the corpus cannot witness them -----------
#
# NOT MEASURED ANYWHERE: every recorded finding is a RIGHT-side line comment.
# What follows pins what the programs DO with the other forms, on payloads
# written by hand to the shape the REST schema documents. It does not show that
# GitHub returns those shapes -- the file-level one least of all.
FORMS="$FX/forms/comments.json"

o=$(findings 9001,9002 "$FORMS")
same "only the selected reviews' findings are read" \
  "$(printf '%s\n' "$o" | jq -r .id | tr '\n' ' ')" "101 102 103 105 "

same "a range keeps both ends"                   "$(field "$o" 101 '"\(.start)-\(.line)"')" "10-12"
same "  a long hunk is cut to its last six rows" "$(field "$o" 101 '.context | length')" "6"
# shellcheck disable=SC2016  # the fixture's row is shell text: compared, never expanded
same "  which start after the cut"               "$(field "$o" 101 '.context[0]')" '+  key=${input%%=*}'
same "  and end on the commented line"           "$(field "$o" 101 '.context | last')" "+  esac"
expect "  a body's = survives, as data inside a string" "$(field "$o" 101 .body)" "review_id=42"
expect "  and so does a suggestion block"               "$(field "$o" 101 .body)" '```suggestion'
same "  a body with newlines is still one row"   "$(printf '%s\n' "$o" | grep -c .)" "4"

same "a single-line finding has no start"        "$(field "$o" 102 .start)" "null"
same "  outdated, located by original_line"      "$(field "$o" 102 '"\(.outdated) \(.line)"')" "true 40"
same "  a short hunk is given whole"             "$(field "$o" 102 '.context | length')" "3"
same "  header included"                         "$(field "$o" 102 '.context[0]')" "@@ -39,1 +39,2 @@"

same "the side is carried, so a deletion reads as one" "$(field "$o" 103 .side)" "LEFT"
same "  a long row is cut"                       "$(field "$o" 103 '.context[2] | length')" "160"
same "  and a short one is not"                  "$(field "$o" 103 '.context | last')" "-removed and still wanted"

# A null hunk must not fail the read: `null | split` is an error, and an error
# on one comment would lose every finding on its page for a field nothing
# decides on.
#
# THE TWO JQ IMPLEMENTATIONS DISAGREE HERE, which is why the assertion joins the
# rows instead of comparing them: splitting the empty string gives `[]` under
# jq 1.7.1 and `[""]` under the gojq inside gh 2.4.0 -- measured on both. Either
# is a context with no text in it, and that is all the row is asked for.
same "a comment with no hunk still yields its row" "$(field "$o" 105 .id)" "105"
same "  with a context holding no text"            "$(field "$o" 105 '.context | join("")')" ""
same "  a file-level comment's line is null"       "$(field "$o" 105 .line)" "null"
same "  but outdated is unknown, not true"         "$(field "$o" 105 .outdated)" "null"

same "one id of the two yields its review alone" \
  "$(findings 9002 "$FORMS" | jq -r .id | tr '\n' ' ')" "103 "

# A placeholder left in is a jq compile error, so the read exits non-zero and
# the round treats it as the failed read it is, rather than as zero findings.
findings '<ids>' "$FORMS" >/dev/null 2>&1
same "a forgotten <ids> fails the read" "$?" "1"
replies '<commentIds>' "$FORMS" >/dev/null 2>&1
same "a forgotten <commentIds> fails the read" "$?" "1"

len() { jq -r ".[] | select(.id == $1) | .body | length" "$FORMS"; }
o=$(replies 101,102,103 "$FORMS")
same "the replies under the listed findings, and no other" \
  "$(printf '%s\n' "$o" | cut -d' ' -f2 | tr '\n' ' ')" "201 202 203 204 206 207 208 "
expect "a marked reply carries its scope and its payload" "$o" "101 201 alice $(len 201) round=3 v=1 round=3"
expect "  a hand-written one carries neither"          "$o" "101 202 bob $(len 202) round=- no-marker"
expect "  prose quoting the literal is not a marker"   "$o" "102 203 alice $(len 203) round=- no-marker"
expect "  an adopted scope is inside the payload class" "$o" \
  "103 204 alice $(len 204) round=adopted-5153256704 v=1 round=adopted-5153256704"
expect "  an envelope outside the class is not a marker" "$o" "102 206 mallory $(len 206) round=- no-marker"
refute "  a reply under another finding is not read"   "$o" " 205 "

# The guard is "a token equal to round=<scope>", and a marker can hold the token
# twice. Either value has to stay findable, or moving the cut into the read
# would have narrowed the rule it was moved for.
expect "a scope given twice prints both values"        "$o" "103 207 alice $(len 207) round=3,4 v=1 round=3 round=4"
# `around=3` ends like the token and is not it: the read compares a token's
# start, which is what "whole key=value token" has always meant here.
expect "  a marker with no scope token says so"        "$o" "103 208 alice $(len 208) round=- v=1 around=3"

# --- pages: the unit gh applies --jq to ------------------------------------
#
# MEASURED HERE: a finding on one page and its reply on the other, in both
# orders, each page run through its own jq process. Neither program holds
# anything from one page to the next, so the rows are the rows of the whole
# list -- which the last two assertions state by running the whole list.
P1="$FX/pages/page-1.json"
P2="$FX/pages/page-2.json"
WHOLE=$(mktemp)
trap 'rm -f "$WHOLE"' EXIT
jq -s add "$P1" "$P2" > "$WHOLE"

o=$(findings 9001 "$P1" "$P2")
same "findings on two pages are both read"  "$(printf '%s\n' "$o" | jq -r .id | tr '\n' ' ')" "301 302 "
same "  as they are from the whole list"    "$o" "$(findings 9001 "$WHOLE")"

o=$(replies 301,302 "$P1" "$P2")
same "a reply paged before its finding is still read" \
  "$(printf '%s\n' "$o" | cut -d' ' -f1-2 | tr '\n' ',')" "302 401,301 402,"
same "  as it is from the whole list"       "$o" "$(replies 301,302 "$WHOLE")"

# === step 7: the round's trigger markers ====================================

markers() { # markers <oid> <file>...
  local oid=$1
  shift
  run "${MARKERS//<oid>/$oid}" "$@"
}

# What an old row and a new one both say about a comment: when, which, whose,
# and the three keys the old read left inside its payload for a reader to find.
# The new row's own columns -- opens, attempt, at_head, by -- have no old
# counterpart and are pinned by value further down.
proj() {
  awk '{
    if ($4 == "no-marker" && NF == 4) { print $1, $2, $3, "no-marker"; next }
    r = "-"; o = "-"; h = "-"
    for (i = 4; i <= NF; i++) {
      if ($i ~ /^round=/) r = substr($i, 7)
      else if ($i ~ /^oid=/) o = substr($i, 5)
      else if ($i ~ /^head=/) h = substr($i, 6)
    }
    print $1, $2, $3, "round=" r, "oid=" o, "head=" h
  }'
}

# The read this one replaced, kept here to be run beside it.
OLD_MARKERS='.[]|select(.user.type!="Bot")|"\(.created_at) \(.id) \(.user.login) \(if (.body|contains("revloop:trigger ")) then (.body|split("revloop:trigger ")[1]|split(" -->")[0]) else "no-marker" end)"'

# --- recorded: iwmaeda/revloop#45, REST, 2026-10 ---------------------------
#
# MEASURED HERE: three triggers this loop posted, each carrying oid=, and the
# reviewer's clean comment after the third. The oid handed in is the third
# trigger's, which was HEAD when that round ran.
OID45=3a6a9b63899ccfaedc2957e686824a780994579c
o=$(markers "$OID45" "$REC/issue-comments-45.json")
same "a bot's comment is not a row"            "$(printf '%s\n' "$o" | grep -c .)" "3"
same "the newest marker is the last row, and it names HEAD" "$(printf '%s\n' "$o" | tail -1)" \
  "2026-10-03T10:11:32Z 5968132783 iwmaeda marker round=3 opens=1 attempt=- at_head=true by=oid oid=$OID45 head=3a6a9b63"
same "  and only that one does"                "$(printf '%s\n' "$o" | grep -c ' at_head=true ')" "1"
same "  every one of the three opened a round" "$(printf '%s\n' "$o" | grep -c ' opens=1 ')" "3"
same "on every key the old read printed, the two agree" \
  "$(printf '%s\n' "$o" | proj)" "$(run "$OLD_MARKERS" "$REC/issue-comments-45.json" | proj)"

# --- recorded: iwmaeda/revloop#13, REST, 2026-08 ---------------------------
#
# MEASURED HERE: twenty-one rounds whose markers predate oid=, with three
# hand-typed comments among them -- so this is the head= fallback on the bytes
# it was written for, and a count long enough to be worth getting wrong.
OID13=65d73ddde8cb3310242b82fe3f249b45ac02453c
o=$(markers "$OID13" "$REC/issue-comments-13.json")
same "every non-bot comment is a row"          "$(printf '%s\n' "$o" | grep -c .)" "24"
same "  twenty-one of them opened a round"     "$(printf '%s\n' "$o" | grep -c ' opens=1 ')" "21"
same "  and three carry no marker"             "$(printf '%s\n' "$o" | grep -c ' no-marker$')" "3"
same "a marker with no oid= is compared on head=, and says so" \
  "$(printf '%s\n' "$o" | grep ' marker ' | tail -1 | cut -d' ' -f4-)" \
  "marker round=21 opens=1 attempt=- at_head=true by=head oid=- head=65d73ddd"
same "  no row claims an oid it does not have" "$(printf '%s\n' "$o" | grep -c ' by=oid ')" "0"
same "  and one marker names HEAD, not twenty-one" "$(printf '%s\n' "$o" | grep -c ' at_head=true ')" "1"
same "on every key the old read printed, the two agree" \
  "$(printf '%s\n' "$o" | proj)" "$(run "$OLD_MARKERS" "$REC/issue-comments-13.json" | proj)"

# gh applies --jq to one page at a time, so five to a page is five processes.
# A row that needed its neighbours would come out differently here.
PAGES=$(mktemp -d)
trap 'rm -f "$WHOLE"; rm -rf "$PAGES"' EXIT
i=0
while IFS= read -r page; do
  i=$((i + 1))
  printf '%s\n' "$page" > "$PAGES/$(printf '%02d' "$i").json"
done < <(jq -c 'range(0; length; 5) as $i | .[$i:$i + 5]' "$REC/issue-comments-13.json")
same "five to a page is five pages"            "$i" "5"
same "  and the rows are the rows of the whole list" "$(markers "$OID13" "$PAGES"/*.json)" "$o"

# --- forms: hand-written, because the corpus cannot witness them -----------
#
# NOT MEASURED ANYWHERE: no recorded pull request carries a re-post, a marker
# somebody garbled, or a focus quoting the literal. These pin what the program
# does with each, which is what step 7 used to ask a reader to work out.
MFORMS="$FX/forms/issue-comments.json"
HEAD_OID=1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b
o=$(markers "$HEAD_OID" "$MFORMS")
mrow() { printf '%s\n' "$o" | awk -v id="$1" '$2 == id' | cut -d' ' -f4-; }

same "a bot quoting a marker is dropped, as the fence drops it" "$(mrow 505)" ""
same "an ordinary marker at another commit" "$(mrow 501)" \
  "marker round=1 opens=1 attempt=- at_head=false by=oid oid=9f8e7d6c5b4a39281706f5e4d3c2b1a09f8e7d6c head=9f8e7d6c"
same "a re-post keeps its round and does not open one" "$(mrow 502)" \
  "marker round=1 opens=0 attempt=2 at_head=false by=oid oid=9f8e7d6c5b4a39281706f5e4d3c2b1a09f8e7d6c head=9f8e7d6c"
same "a marker older than oid= falls back to head=" "$(mrow 503)" \
  "marker round=2 opens=1 attempt=- at_head=true by=head oid=- head=1a2b3c4d"
same "a hand-typed trigger is a row with no marker" "$(mrow 504)" "no-marker"
same "  sharing its second with the marker before it, both ids printed" \
  "$(printf '%s\n' "$o" | awk '$1 == "2026-01-01T01:00:00Z" { print $2 }' | tr '\n' ' ')" "503 504 "

# The fence reads the marker as the text after the FIRST literal, so a focus
# quoting it hides every key. The read has to lose them too, or it would report
# a round the fence cannot see.
same "a focus quoting the literal hides the marker's keys" "$(mrow 506)" \
  "marker round=- opens=1 attempt=- at_head=false by=none oid=- head=-"

same "notattempt=2 is not attempt"           "$(mrow 507)" \
  "marker round=10 opens=1 attempt=- at_head=true by=oid oid=$HEAD_OID head=1a2b3c4d"
same "  and round=10 is not round=1"         "$(printf '%s\n' "$o" | grep -c ' round=1 ')" "2"

# A value that is not the shape its key takes is printed as ?, and a quoted
# "attempt=2" is a token whose key is not attempt. Step 7 counts a row whose
# round= is not a number as a match for its retry budget.
same "a garbled marker says which of its keys it could not read" "$(mrow 508)" \
  "marker round=? opens=1 attempt=- at_head=false by=oid oid=? head=?"

same "a tab and a newline separate keys as a blank does" "$(mrow 509)" \
  "marker round=4 opens=0 attempt=2 at_head=true by=head oid=- head=1a2b3c4d"
same "a nine-character head= is still a prefix of HEAD" "$(mrow 510)" \
  "marker round=5 opens=1 attempt=- at_head=true by=head oid=- head=1a2b3c4d5"
same "  and one cut below eight never names it" "$(mrow 511)" \
  "marker round=6 opens=1 attempt=- at_head=false by=head oid=- head=?"

# The round number is the count of opens=1 rows plus one. It is counted by
# reading, because no page sees another; what the read owes that count is that
# every row which opened a round says so and no other row does.
same "the rows that opened a round" \
  "$(printf '%s\n' "$o" | awk '$6 == "opens=1" { print $2 }' | tr '\n' ' ')" "501 503 506 507 508 510 511 "

# A value that is not forty hexadecimal characters would print at_head=false on
# every row -- "HEAD has moved", the answer that permits a trigger. So the read
# refuses it instead.
markers '<oid>' "$MFORMS" >/dev/null 2>&1
same "a forgotten <oid> fails the read"      "$?" "1"
markers 1a2b3c4d "$MFORMS" >/dev/null 2>&1
same "  and so does the short head= in its place" "$?" "1"
markers "${HEAD_OID%b}" "$MFORMS" >/dev/null 2>&1
same "  and a hash one character short"      "$?" "1"
markers "${HEAD_OID%b}B" "$MFORMS" >/dev/null 2>&1
same "  and one in capitals"                 "$?" "1"

# === step 10: the review list ===============================================

reviews() { # reviews <oid> <since> <file>...
  local p=${LIST//<oid>/$1}
  p=${p//<since>/$2}
  shift 2
  run "$p" "$@"
}

OLD_LIST='.[]|{id,submitted_at,state,commit:.commit_id,login:(.user.login|rtrimstr("[bot]"))}'

# --- recorded: iwmaeda/revloop#45, REST, 2026-10 ---------------------------
#
# MEASURED HERE: two reviews by the reviewer and the two review containers
# GitHub made for this loop's own replies. The oid and the bound are round 2's:
# its commit, and the second its trigger was posted in.
o=$(reviews 6f8c3956c73055ded74790785264a5ba030a2d4e 2026-10-03T10:04:39Z "$REC/reviews-45.json")
same "every review is a row, selected or not"  "$(printf '%s\n' "$o" | grep -c .)" "4"
same "the five keys the old read printed are unchanged" \
  "$(printf '%s\n' "$o" | jq -Sc '{id, submitted_at, state, commit, login}')" \
  "$(run "$OLD_LIST" "$REC/reviews-45.json" | jq -Sc .)"
same "the reviewer's login loses its [bot]"    "$(field "$o" 5400187711 .login)" "chatgpt-codex-connector"
same "round 2's review is at HEAD and after the bound" \
  "$(field "$o" 5400187711 '"\(.at_head) \(.after) \(.at_or_after) \(.draft)"')" "true true true false"
same "  round 1's is neither"                  \
  "$(field "$o" 5400147466 '"\(.at_head) \(.after) \(.at_or_after)"')" "false false false"
same "  this loop's own reply container is printed, not filtered" \
  "$(field "$o" 5400205617 '"\(.login) \(.at_head)"')" "iwmaeda true"

# --- forms: hand-written ----------------------------------------------------
#
# NOT MEASURED ANYWHERE: a draft, a dismissed review and a review sharing its
# second with the bound. The last is the whole difference between the two
# columns, and the two steps that read this list take one each.
RFORMS="$FX/forms/reviews.json"
o=$(reviews "$HEAD_OID" 2026-01-01T01:00:00Z "$RFORMS")
same "every review is printed"                 "$(printf '%s\n' "$o" | jq -r .id | tr '\n' ' ')" \
  "601 602 603 604 605 606 607 608 "
same "a review in the bound's own second is at-or-after and not after" \
  "$(field "$o" 601 '"\(.after) \(.at_or_after)"')" "false true"
same "  one a second later is both"            "$(field "$o" 602 '"\(.after) \(.at_or_after)"')" "true true"
same "  one a second earlier is neither"       "$(field "$o" 608 '"\(.after) \(.at_or_after)"')" "false false"
same "another commit sharing eight characters is not HEAD" "$(field "$o" 603 .at_head)" "false"
same "a draft says it is one"                  "$(field "$o" 604 .draft)" "true"
same "  and fails both bounds, which is why draft is read first" \
  "$(field "$o" 604 '"\(.after) \(.at_or_after) \(.submitted_at)"')" "false false null"
same "a dismissed review keeps its state for the reader" "$(field "$o" 605 .state)" "DISMISSED"
same "[bot] is stripped as a suffix only"      "$(field "$o" 606 .login)" "a[bot]b"
same "a person's review is a row like any other" "$(field "$o" 607 '"\(.login) \(.at_head)"')" "alice true"

# With <since> left in, every comparison reads false: `<` sorts after every
# digit. On the sweep that is an empty selection and a clean finish past unread
# findings, so the read refuses to run rather than answer.
reviews "$HEAD_OID" '<since>' "$RFORMS" >/dev/null 2>&1
same "a forgotten <since> fails the read"      "$?" "1"
reviews '<oid>' 2026-01-01T01:00:00Z "$RFORMS" >/dev/null 2>&1
same "  and so does a forgotten <oid>"         "$?" "1"
reviews "$HEAD_OID" 2026-01-01 "$RFORMS" >/dev/null 2>&1
same "  and a bound that is a date and not a timestamp" "$?" "1"

summary "findings-read"
