# Install

## Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The command is then `/revloop:review-loop`. Plugin-provided commands are always namespaced as
`/<plugin>:<command>`, so there is no bare `/revloop`.

It is deliberately **not** model-invocable (`disable-model-invocation: true`), and the plugin
manifest ships no `skills` key. This loop pushes, comments on pull requests, and can merge; it should
only ever start because a person asked for it.

## Codex

Codex plugin support is in preview. The reliable path today is to place the skill directly:

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p .agents/skills
cp -r ~/.revloop/.agents/skills/revloop .agents/skills/
export REVLOOP_PROCEDURE=~/.revloop/commands/review-loop.md
```

`.agents/skills/revloop/SKILL.md` is a **router**, not a copy of the procedure: it resolves
`commands/review-loop.md` and reads it. Setting `REVLOOP_PROCEDURE` is what makes that work when the
skill has been copied away from the repository. Without it the router searches relative to itself and
then upward, and **aborts** if it finds nothing — it will not improvise a procedure.

Once `codex plugin install` is generally available, `.codex-plugin/plugin.json` is already in place.

## Requirements

| Tool  | Floor                | Note                                                               |
| ----- | -------------------- | ------------------------------------------------------------------ |
| `gh`  | **2.4.0** (verified) | Authenticated. Only stable REST and GraphQL surfaces are used      |
| `git` | any modern version   | —                                                                  |
| `jq`  | **not required**     | `gh` embeds a jq implementation; the procedure never pipes to `jq` |

A reviewer bot must be installed on the repository. revloop posts the trigger; it does not install
anything.

## Verify the install

```console
/revloop:review-loop
```

On a clean tree with no changes it should print the resolved-configuration table and stop. If it
prints a permission prompt for every step, work through [`permissions.md`](permissions.md).
