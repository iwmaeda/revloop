# Contributing

## Run the checks

```console
mise install
npm ci
npm run check:all   # prettier, markdownlint, shellcheck, tests
npm run audit       # needs the network; CI runs it as a separate job
```

Run `mise install` first. The shellcheck and jq tests skip themselves and exit 0 when their binary is
missing, so `check:all` can pass without having run them.

## Writing procedures and docs

[`procedures/`](procedures/) is the source of truth. An agent reads a procedure in full before it
touches git, so every line costs context on every run.

- English only.
- State each rule once, in the imperative: condition, action, `reason=`. Keep a reason only when it
  changes what the reader does in an edge case, and keep it to one clause.
- No history, citations, dates or measurements. Those belong in the commit message. The one exception
  is a reviewer card's `## Measured` bullets, which cite their provenance in the form
  [`reviewers/README.md`](reviewers/README.md) gives.
- `## Unexercised paths` lists each path that has never run against live data, one line per path.
  Remove an entry when the path has been observed.
- Do not restate a procedure step in a command, a card or a doc. A command states what differs for
  its reviewer; the procedure states what happens.
- Cite a step by its number, never by a line number or by position ("the two rows below").
- Keep table cells short. Prettier pads every row to the widest cell.

User-facing docs follow the same rules: what a user needs to operate the tool, and nothing else.
`CHANGELOG.md` entries are short bullets under Added, Changed, Fixed and Removed, plus one `Fences:`
line.

## Editing or adding a shell fence

Users grant permission to a fence's exact text, so any edit makes every user approve it again.

1. Make the change.
2. Re-run the affected branches against real data, and add a fixture for what you learned.
3. Add a `CHANGELOG.md` entry naming the fence and saying whether it changed (one re-approval) or
   was added (one first approval).
4. Run `tests/update-fence-hashes.sh`.
5. Run `npm test`.

CI fails if a fence changes without step 4.

## Adding a reviewer preset

Drive a comment-triggered reviewer end to end on a real pull request first, or a local command through
the loop to convergence; see
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md). A preset is two files:
`reviewers/<name>.json`, the definition, validated against
[`schema/reviewer.schema.json`](schema/reviewer.schema.json), and `reviewers/<name>.md`, the card. A
built-in also needs a command in [`commands/`](commands/) that names the definition. The tests check
all three.

## Commits

Conventional Commits, English subjects.
