# Known environment quirks

Observations that were true of a specific machine or repository at a specific time. They are **not
normative** — nothing in the procedure depends on them. They are recorded because each one cost
somebody an afternoon, and because a reader hitting the same symptom deserves the shortcut.

Where a quirk contained a portable principle, the principle was promoted into the procedure's
`## Notes` and only the specifics stayed here.

## Version-manager prefixes: the polarity flips

One repository required every Node command to be prefixed with `mise exec --`, because on WSL the
PATH resolved `node` and `npm` to Windows shims. Two other repositories on the same machine required
the **opposite** — the mise-provided Linux binaries were already ahead on PATH, and prefixing made the
local invocation differ from CI's.

Promoted principle: **invoke verify commands exactly the way CI invokes them.** Whether a prefix is
needed is a property of the project, not of this procedure, which is why `verify` is a plain list of
command strings and revloop never adds anything to them.

Observed in iwmaeda/iwmaeda and two private repositories, 2026-08.

## `jq` is not where you expect it

`command -v jq` was empty on the machine this was derived on, while `gh api --jq` worked fine — `gh`
embeds a jq implementation. `mise exec -- jq` failed with `couldn't exec process`, and `/usr/bin/jq`
did not exist.

Promoted principle: **never pipe to `jq`**. This one graduated fully — a missing `jq` is common enough
that it is a design rule, not a quirk.

Observed 2026-08.

## Repository facts that used to be asserted

Earlier versions stated these as facts. They are true of one repository at one time, so the procedure
now **probes and prints them** in step 1 instead:

| Assertion that used to be in the text                          | What replaced it                                        |
| -------------------------------------------------------------- | ------------------------------------------------------- |
| "`main` has no branch protection (`.../protection` is 404)"    | A probe, with a warning when 404                        |
| "`deleteBranchOnMerge` is false, so 6 merged branches survive" | A probe. The count was 6 in one repo, 20+ in two others |
| "CI is exactly the `check` and `test` jobs"                    | The rollup rows, printed                                |
| "the `gh` here is 2.4.0"                                       | `gh --version`, printed, with a stated floor            |

The reasoning those facts supported was worth keeping; the facts were not.

## markdownlint descends into dot-directories

`markdownlint-cli2` runs with `dot: true`, so `.claude/**` and `.agents/**` are linted. This is about
maintaining a repository that contains agent configuration, not about running the loop, so it lives in
[`../CONTRIBUTING.md`](../CONTRIBUTING.md).

## CI concurrency cancels superseded runs

A workflow with `concurrency: cancel-in-progress: true` turns a push made during a CI wait into a
`CANCELLED` conclusion, which reads as `CHECKS_FAILED`. That is fail-closed, and the "never push
while a wait is armed" rule prevents it entirely — so this is a footnote rather than a hazard. Not
every repository sets `concurrency`; two of three did.
