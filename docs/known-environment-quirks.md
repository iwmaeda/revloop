# Known environment quirks

Observations that were true of a specific machine or repository at a specific time. They are not
normative — nothing in the procedure depends on them. They are recorded because each one cost
somebody an afternoon, and a reader hitting the same symptom deserves the shortcut.

Where a quirk contained a portable principle, the principle was promoted into the procedure's
`## Notes` and only the specifics stayed here.

## Version-manager prefixes: the polarity flips

**Observed:** One repository required every Node command to be prefixed with `mise exec --`, because
on WSL the PATH resolved `node` and `npm` to Windows shims. Two other repositories on the same
machine required the opposite — the mise-provided Linux binaries were already ahead on PATH, and
prefixing made the local invocation differ from CI's.

**Promoted principle:** Invoke verify commands exactly the way CI invokes them. Whether a prefix is
needed is a property of the project, not of this procedure, which is why `verify` is a plain list of
command strings and revloop never adds anything to them.

**Attribution:** iwmaeda/iwmaeda and two private repositories, 2026-08.

## `jq` is not where you expect it

**Observed:** `command -v jq` was empty on the machine this was derived on, while `gh api --jq` worked
fine — `gh` embeds a jq implementation. `mise exec -- jq` failed with `couldn't exec process` and
`/usr/bin/jq` did not exist, for the dull reason that `jq` was not in that repository's `mise.toml`.
Declaring it and running `mise install` makes the same command return `jq-1.7.1`.

**Promoted principle:** Never pipe to `jq`. A missing `jq` is common enough to be a design rule, not a
quirk. This repository does declare `jq` in [`../mise.toml`](../mise.toml), but only for its test
harness; [`install.md`](install.md) still lists `jq` as not required for running revloop, and both are
true because they address different audiences.

**Attribution:** 2026-08; the mise resolution re-checked 2026-08-19.

## `gh pr edit` is broken at the verified floor

**Observed:** On `gh 2.4.0` (2022-03), `gh pr edit <n> --body-file …` exits 1 with
`GraphQL: Projects (classic) is being deprecated … (repository.pullRequest.projectCards)` and leaves
the body unchanged. It failed twice in one session, and
`gh api -X PATCH "repos/{owner}/{repo}/pulls/<n>" -F body=@file` succeeded six times in its place.
The subcommand requests that field to populate the pull request's current metadata; GitHub has
retired Projects (classic), so the query the client sends is now rejected outright. Nothing about the
edit itself is unsupported — only the metadata the client asks for alongside it.

**Promoted principle:** Prefer the stable REST surface to a subcommand whose extra queries can be
deprecated out from under the floor. This is not a new rule — it is why the merge already goes
through REST `PUT` rather than `gh pr merge`, and why CI status comes from
`gh pr view --json statusCheckRollup` rather than `gh pr checks`. Step 6 now updates the body the
same way. **Existing at the floor and working at the floor are different claims**, and the
procedure's floor note used to conflate them.

**Not measured:** whether `gh pr create --body-file` is affected. It has no existing pull request to
query, so it should not reach the same field, but nobody has run it at the floor since the sunset.

**Attribution:** `iwmaeda/revloop#8`, 2026-08, on `gh version 2.4.0+dfsg1`.

## CI concurrency cancels superseded runs

**Observed:** A workflow with `concurrency: cancel-in-progress: true` turns a push made during a CI
wait into a `CANCELLED` conclusion, which reads as `CHECKS_FAILED`. Two of three repositories set
`concurrency`.

**Promoted principle:** Never push while a wait is armed. That rule prevents this entirely, and the
misreading is fail-closed, so this is a footnote rather than a hazard.

**Attribution:** three repositories, 2026-08.

## Repository facts that used to be asserted

Earlier versions stated these as facts. They are true of one repository at one time, so the procedure
now probes and prints them in step 1 instead:

| Assertion that used to be in the text                          | What replaced it                                        |
| -------------------------------------------------------------- | ------------------------------------------------------- |
| "`main` has no branch protection (`.../protection` is 404)"    | A probe, with a warning when 404                        |
| "`deleteBranchOnMerge` is false, so 6 merged branches survive" | A probe. The count was 6 in one repo, 20+ in two others |
| "CI is exactly the `check` and `test` jobs"                    | The rollup rows, printed                                |
| "the `gh` here is 2.4.0"                                       | `gh --version`, printed, with a stated floor            |

The reasoning those facts supported was worth keeping; the facts were not.

## Related docs

- [Install](install.md) — the version floors, and what is actually required
- [Configuration](configuration.md) — `verify`, and why revloop never rewrites your commands
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — quirks of maintaining this repository, rather than of
  running the loop
