# Contributing

## Run the checks

```console
mise install
npm ci
npm run check:all   # prettier + markdownlint + shellcheck + fence, schema and version tests
npm run audit       # the one CI job check:all does not cover — see below
```

[`mise.toml`](mise.toml) pins node, `jq`, and `shellcheck`, and CI installs from the same file — so the
comment above describes what runs on your machine and what runs in CI alike. The last two pins matter
more than they look: `tests/lint-shell.sh` and `tests/jq-program.test.sh` **skip themselves** when
their binary is missing, announcing it but exiting zero. Without `mise install` the line above is a
lie — `check:all` goes green having never run shellcheck and never exercised the fence's jq program.

`npm audit` is deliberately outside `check:all`: it needs the network, and `check:all` has to stay
runnable offline. That makes it the one CI job the umbrella command does not reproduce, which is
exactly the gap [`.revloop.json`](.revloop.json)'s `verifyNotes` exists to record — this repository
runs into its own feature.

**`.agents/**`, `.claude/**` and `.github/**` ARE linted**, and this paragraph has now said both. From
0.7.0 it said they were not, because no `dot` option appeared in the configuration and the linter
reported nothing from those directories. Neither showed it: `markdownlint-cli2` 0.23.3 sets `dot: true`
in its own source, and a clean file reports nothing whether or not it is read. A custom rule that
reports every file it is handed listed [`.agents/skills/revloop/SKILL.md`](.agents/skills/revloop/SKILL.md)
and `.github/pull_request_template.md` among the rest. The linter is now `markdownlint-cli`, where the
same reach is the `--dot` in the `lint:md` script, and without it both files drop out. So the Codex
router is linted, and what [`.markdownlintignore`](.markdownlintignore) names is all that is skipped.

## The procedure is the product

[`procedures/remote-loop.md`](procedures/remote-loop.md) and
[`procedures/local-loop.md`](procedures/local-loop.md) are the single source of truth, and
[`procedures/rigor-levels.md`](procedures/rigor-levels.md) and
[`procedures/severity-grading.md`](procedures/severity-grading.md) are two more that both cite. A
procedure is read **in full** by an agent before it touches git, so:

- **English only.** A second language guarantees drift, and drift in this file is a safety defect.
- **Every rule states the failure that motivated it.** "Do X" is not useful; "do X, because Y silently
  produced Z" is. If you cannot name the failure, the rule probably is not one.
- **Separate what was measured from what was assumed.** The `## Unexercised paths` section exists to
  be honest about the second category. Shrinking it with real observations is one of the most
  valuable contributions possible; quietly deleting entries is the opposite.
- **Do not copy it.** The Codex side is a router that reads this file, and each of the seven files in
  [`commands/`](commands/) is a flag table and a pointer. **A command states what differs; a procedure
  states what happens.** If you find yourself restating a step in a command, stop —
  `tests/commands.test.sh` refuses a bash fence, a trigger marker or the canonical ladder in one, but
  it cannot refuse a paraphrase.
- **Cite a step by its number, never by a line number.** A line number is correct on the day it is
  written and wrong after the next insertion above it, silently. `tests/procedure-refs.test.sh` is a
  tripwire for this, **not a proof of it**: it catches the citation forms it enumerates, and its
  comment lists them with the axis each one closed. The rule is absolute and the guard is
  best-effort; the difference is written into the test rather than left implied.

## Editing or adding a shell fence

The fences carry a cost no other change has: **their bytes are what users grant standing permission
to**, so any edit forces every user to re-approve. That is intentional — the prompt is how they learn
the bytes changed — but it means an edit must be deliberate.

1. Make the change.
2. Re-run the affected branches **against real data**, not only against fixtures. Add a fixture for
   whatever you learned.
3. Add a `CHANGELOG.md` entry saying which fence changed **or was added**, and that it costs one
   re-approval **or one first approval** — the two are different events and only the first invalidates
   something a user already granted.
4. `tests/update-fence-hashes.sh`
5. `npm test`

CI fails if a fence changes without step 4, which is the point.

## Adding a reviewer preset

Drive it end to end on a real PR first. A card whose `status` is `verified` means someone watched it
work; a card written from vendor documentation is worse than no card, because it looks measured.
See [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

**A preset is two files, and a built-in is three.** `reviewers/<name>.json` is the definition the loop
loads, validated against [`schema/reviewer.schema.json`](schema/reviewer.schema.json);
`reviewers/<name>.md` is the card beside it. `tests/schema.test.sh` asserts the pairing in both
directions, so neither ships alone. A reviewer that should be built in also needs a command in
[`commands/`](commands/) naming its definition — `tests/commands.test.sh` asserts that every definition
has exactly one driver, so adding the definition without the command fails the suite.

## Commits

Conventional Commits, English subjects. State what was true, not what you did.
