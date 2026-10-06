# Reviewer presets

Each reviewer is two files.

| File                    | What it is                                                                     |
| ----------------------- | ------------------------------------------------------------------------------ |
| `reviewers/<name>.json` | The definition the loop loads, validated against `schema/reviewer.schema.json` |
| `reviewers/<name>.md`   | The card: how the reviewer behaves                                             |

The file name is the reviewer's name and must match `^[a-z0-9][a-z0-9-]*$`. A definition passed
with `--config` uses the same format.

## Kinds

| `kind`                     | Driven by               | How it is reached                                      |
| -------------------------- | ----------------------- | ------------------------------------------------------ |
| `github-comment` (default) | the `remote-*` commands | A trigger comment on a pull request, answered by a bot |
| `local-command`            | the `local-*` commands  | A review command run on this machine                   |

The fields are listed in
[`docs/configuration.md`](../docs/configuration.md#reviewer-definitions).

`severityLevels` is the list of severity words the reviewer emits, most severe first. `severityMap`
carries them onto revloop's ladder, `critical > high > medium > low`, and is required with it. A
reviewer that emits no severity has neither key, and its findings are graded instead.

## Status

| `status`      | Meaning                                                                                   |
| ------------- | ----------------------------------------------------------------------------------------- |
| `verified`    | Driven end to end by the maintainers: on a real pull request, or locally to a convergence |
| `reported`    | Reported working; not reproduced here                                                     |
| `unverified`  | Shipped as a starting point                                                               |
| `unsupported` | Found not to work the way the loop needs                                                  |

## Card format

- A field table.
- `## Measured`: what was observed, one fact per bullet.
- `## Not measured`: one line per gap.
- For a `local-command` reviewer, `## Output shape`: what the local procedure parses.

A card states facts and carries no citations, dates or history.

## Adding one

See [`docs/adding-a-reviewer.md`](../docs/adding-a-reviewer.md).
