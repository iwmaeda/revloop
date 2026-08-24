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

`.claude/**` and `.agents/**` are linted too — `markdownlint-cli2` runs with `dot: true` and descends
into dot-directories.

## The procedure is the product

[`commands/review-loop.md`](commands/review-loop.md) is the single source of truth. It is read **in
full** by an agent before it touches git, so:

- **English only.** A second language guarantees drift, and drift in this file is a safety defect.
- **Every rule states the failure that motivated it.** "Do X" is not useful; "do X, because Y silently
  produced Z" is. If you cannot name the failure, the rule probably is not one.
- **Separate what was measured from what was assumed.** The `## Unexercised paths` section exists to
  be honest about the second category. Shrinking it with real observations is one of the most
  valuable contributions possible; quietly deleting entries is the opposite.
- **Do not copy it.** The Codex side is a router that reads this file. If you find yourself restating
  a step, stop.
- **Cite a step by its number, never by a line number.** A line number is correct on the day it is
  written and wrong after the next insertion above it, silently. `tests/procedure-refs.test.sh` is a
  tripwire for this, **not a proof of it**: it catches the citation forms it enumerates, and its
  comment lists them with the axis each one closed. The rule is absolute and the guard is
  best-effort; the difference is written into the test rather than left implied.

## Editing a shell fence

The fences carry a cost no other change has: **their bytes are what users grant standing permission
to**, so any edit forces every user to re-approve. That is intentional — the prompt is how they learn
the bytes changed — but it means an edit must be deliberate.

1. Make the change.
2. Re-run the affected branches **against real data**, not only against fixtures. Add a fixture for
   whatever you learned.
3. Add a `CHANGELOG.md` entry saying the fence changed and that it costs one re-approval.
4. `tests/update-fence-hashes.sh`
5. `npm test`

CI fails if a fence changes without step 4, which is the point.

## Adding a reviewer preset

Drive it end to end on a real PR first. A card whose `status` is `verified` means someone watched it
work; a card written from vendor documentation is worse than no card, because it looks measured.
See [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md).

## Commits

Conventional Commits, English subjects. State what was true, not what you did.
