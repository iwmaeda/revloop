<!--
Delete any section that does not apply. The checklist below is short on purpose:
each item exists because skipping it has silently broken something.
-->

## What was wrong, and what is true now

<!-- State what was actually true, not what you did. If you measured something, say what. -->

## Checks

- [ ] `npm run check:all` passes
- [ ] `mise install` was run first — otherwise shellcheck and the fence's jq program **skip
      themselves** and `check:all` goes green having run neither
- [ ] `npm run audit` passes (CI runs it as its own job; `check:all` does not)

## Did you edit a shell fence?

A fence's bytes are what users grant standing permission to, so editing one costs **every user one
re-approval**. That cost is the point — the prompt is how they learn the bytes changed.

- [ ] No fence changed — skip the rest
- [ ] The changed branches were re-run **against real data**, not only fixtures
- [ ] A fixture was added for whatever that measured
- [ ] `CHANGELOG.md` says the fence changed and that it costs one re-approval
- [ ] `tests/update-fence-hashes.sh` was run

## Measured or assumed?

- [ ] Every new claim says which it is, and dated observations cite where
- [ ] If this shrinks `## Unexercised paths`, the entry was removed because something was
      **observed** — not because it looked unlikely
