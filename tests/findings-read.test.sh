#!/usr/bin/env bash
# Exercises the jq programs of the three reads steps 9, 10 and 11 of
# procedures/remote-loop.md use to take a review's findings off a pull request:
# the review header, the findings, and the replies under them. They are prose
# reads rather than fences -- prefix-granted `gh api` calls with placeholders --
# so no fence test reaches them, and until this file nothing ran them at all.
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

HEADER=$(printf '%s\n' "$REVIEW_PROGS" | sed -n 1p)
FINDINGS=$(printf '%s\n' "$REVIEW_PROGS" | sed -n 2p)
REPLIES=$(printf '%s\n' "$REPLY_PROGS" | sed -n 1p)

# An extraction that found nothing would make every assertion below fail for the
# wrong reason -- or, on a later edit, pass over a block that no longer holds a
# read. Stop here instead, naming what is missing.
if [ -z "$HEADER" ] || [ -z "$FINDINGS" ] || [ -z "$REPLIES" ] || [ -z "$COMMIT_PROGS" ]; then
  echo "  FAIL could not lift the read programs out of the procedure"
  echo "       review-commit: ${COMMIT_PROGS:-<none>}"
  echo "       per-review:    ${REVIEW_PROGS:-<none>}"
  echo "       replies:       ${REPLY_PROGS:-<none>}"
  exit 1
fi

same "step 9's block holds one read"      "$(printf '%s\n' "$COMMIT_PROGS" | grep -c .)" "1"
same "the per-review block holds two"     "$(printf '%s\n' "$REVIEW_PROGS" | grep -c .)" "2"
same "step 11's block holds one"          "$(printf '%s\n' "$REPLY_PROGS" | grep -c .)" "1"

# The header is one read invoked from two steps. Two spellings of it would be
# two reads, and "reading one half on one path and the other half on the other"
# is how step 10 says it has already failed twice.
same "step 9 and step 10 spell the header read alike" "$COMMIT_PROGS" "$HEADER"

# A single quote inside a program would end the shell word the procedure wraps
# it in. The extraction above is greedy, so it would lift such a program whole
# and hide the break.
for p in "$HEADER" "$FINDINGS" "$REPLIES"; do
  refute "a program holds no single quote" "$p" "'"
done

placeholders() { printf '%s\n' "$1" | grep -oE '<[A-Za-z_]+>' | sort -u | tr '\n' ' '; }
same "the header read takes no placeholder"        "$(placeholders "$HEADER")"   ""
same "the findings read takes the review ids only" "$(placeholders "$FINDINGS")" "<ids> "
same "the replies read takes the finding ids only" "$(placeholders "$REPLIES")"  "<commentIds> "

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
same "  a null line is what outdated means"        "$(field "$o" 4127727186 .outdated)" "true"
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
expect "  each row opens with the finding it answers" "$o" "4127727186 4127755765 iwmaeda 1347 v=1 round="
same "  and no finding is named twice" \
  "$(printf '%s\n' "$o" | cut -d' ' -f1 | sort -u | grep -c .)" "5"

OLD_REPLIES='.[]|select(.in_reply_to_id==<commentId>)|"\(.id) \(.user.login) \(.body|length) \(if (.body|test("<!-- revloop:reply [A-Za-z0-9=._ -]*-->")) then (.body|split("<!-- revloop:reply ")[1]|split(" -->")[0]) else "no-marker" end)"'
old=""
for c in ${ALL_FINDINGS//,/ }; do
  old+=$(run "${OLD_REPLIES//<commentId>/$c}" "$REC/comments.json")$'\n'
done
same "past the leading id, a row is the row the old read printed" \
  "$(printf '%s\n' "$o" | cut -d' ' -f2-)" "$(printf '%s' "$old")"

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
same "  and no line at all reads as null"          "$(field "$o" 105 '"\(.line) \(.outdated)"')" "null true"

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
  "$(printf '%s\n' "$o" | cut -d' ' -f2 | tr '\n' ' ')" "201 202 203 204 206 "
expect "a marked reply carries its payload"            "$o" "101 201 alice $(len 201) v=1 round=3"
expect "  a hand-written one carries none"             "$o" "101 202 bob $(len 202) no-marker"
expect "  prose quoting the literal is not a marker"   "$o" "102 203 alice $(len 203) no-marker"
expect "  an adopted scope is inside the payload class" "$o" "103 204 alice $(len 204) v=1 round=adopted-5153256704"
expect "  an envelope outside the class is not a marker" "$o" "102 206 mallory $(len 206) no-marker"
refute "  a reply under another finding is not read"   "$o" " 205 "

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

summary "findings-read"
