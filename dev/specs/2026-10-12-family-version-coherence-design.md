# Family version coherence: design

**Date:** 2026-10-12
**Status:** proposed. Not implemented.
**Effect on prior records:** none. It extends the catalog-versions job and the
one-call `pak` rule; it reverses nothing.

## The problem

Each member's CI proves that member against whatever its siblings' `main` held
at the moment the run installed them. Nothing proves the family as a whole, and
nothing checks the version floors members declare on one another.

Three facts, all measured on 2026-10-12:

1. **Floors between members are checked nowhere.** `dependency_floors()` in
   `R/status.R` drops every package named in `Remotes:`, which is every family
   member, so `explain_install_failure()` and `status()` only ever look at floors
   on packages outside the family. That exclusion is right for what those
   functions do (a family floor is not the repositories' to meet), but it means a
   floor such as `hvtiRtemplates`'s `hvtiRutilities (>= 1.5.1)` is read by no tool.
2. **The floors are real, and they bind.** Three members import or suggest other
   members with a floor: `hvtiRdatabuild` imports `hvtiRutilities (>= 1.5.1)`,
   `hvtiRlifetables` imports `TemporalHazard (>= 1.2.0)`, and `hvtiRtemplates`
   imports `hvtiRutilities (>= 1.5.1)` and suggests all ten other members, each
   with a floor. `install()` sends every spec to `pak` in one call and members
   resolve from GitHub `main`, so a floor raised past what a sibling's `main`
   carries fails every install: "required version does not exist". That is the
   class of bug the one-call rule was written for.
3. **A sibling's merge re-tests nothing downstream.** When `hvtiRutilities`
   merges, `hvtiRtemplates`'s last green run still stands, though it ran against
   the old `hvtiRutilities`. The next templates push finds out. On a release day
   that can be after `hvtiR` has shipped with both versions in its catalog.

The release order that keeps this safe was worked out by hand on 2026-10-12
(tiers: leaves, then `hvtiRdatabuild` and `hvtiRlifetables`, then
`hvtiRtemplates`, then `hvtiR`). It is correct and it lives in one session
transcript. The same day showed what an unwatched gate costs: ggRandomForests'
release check had failed on every release since at least 2026-09-11 and nobody
had looked.

## Goals

- A floor a member declares on another member is recorded, and one that points
  past the sibling's `main` is reported before anyone installs.
- After a sibling merges, its dependents are re-tested against it, by rule now
  and by machine later.
- Before `hvtiR` is bumped, the whole family is installed together, the way
  `install()` does it, and the members that consume siblings are tested on it.

## Non-goals

- Pinning. `renv` owns that (see the rejected snapshot/restore design).
- Making any of this a required check on a member's pull request. A member PR
  must not wait on thirteen repositories.
- CRAN. Members on CRAN keep their own release gates.

## Design

Three pieces, each useful on its own, in the order they should land.

### 1. A floor table in the catalog-versions job

`tools/refresh_catalog_versions.py` already reads every member's `DESCRIPTION`
from `main`. It gains a second output, `inst/extdata/family-floors.csv`, one row
per dependency one member declares on another:

| column | meaning |
|---|---|
| `package` | the member that declares the floor |
| `field` | `Depends`, `Imports`, `LinkingTo` or `Suggests` |
| `dependency` | the member it names |
| `floor` | the version in `(>= x.y.z)`, empty when none is given |
| `dependency_dev` | that member's `Version:` on `main`, from the catalog |
| `satisfied` | `TRUE`, `FALSE`, or empty when there is no floor |

The pull request the job already opens carries this file's diff, so a raised
floor shows up as a reviewed change, the way a moved version does now.

An **unsatisfied floor in `Depends`, `Imports` or `LinkingTo` fails the job**,
with an `::error::` naming both packages and both versions. That departs from
the job's rule never to fail, on purpose: that rule exists because version
*drift* is normal and a weekly red check would be trained away. An unsatisfiable
hard floor is not drift. It breaks `install()` for every user until it is fixed,
and it should be loud. An unsatisfied `Suggests` floor is a `::warning::` and
does not fail: it degrades a template, it does not stop an install.

Shipping the table in `inst/extdata` costs a few kilobytes and lets `doctor()`
later explain a broken install offline. That use is out of scope here; the file
is shipped now so the later change needs no data migration.

### 2. The release rule: re-run dependents after a sibling merges

Added to `AGENTS.md`, under releases, and to the family release checklist:

> When a member that others depend on merges to `main`, re-run the latest `main`
> push run of each dependent before tagging either. Dependents are the rows of
> `family-floors.csv` whose `dependency` is the member that moved.

Re-run, not dispatch. `gh run rerun <id>` repeats the push matrix (Linux release,
oldrel and macOS) and installs siblings fresh from `main`. A `workflow_dispatch`
would start the full weekly sweep, Windows and devel included, for a question
those legs do not answer.

Automating this with `repository_dispatch` from each member to its dependents
was considered and deferred: it needs a token with write access in every
dependent, thirteen secrets to rotate, and piece 3 covers the same ground from
one place.

### 3. An integration run in hvtiR

A new workflow, `family-integration.yml`, in this repository:

1. Installs the whole family from `main` in one `pak` call, through the same
   spec list `install()` builds. This alone proves co-resolution and every hard
   floor together.
2. Checks out each member that consumes a sibling (today `hvtiRdatabuild`,
   `hvtiRlifetables` and `hvtiRtemplates`, read from `family-floors.csv` rather
   than listed) and runs its `testthat` suite against the installed family, with
   `NOT_CRAN=true`.
3. Reports per member. It is not a required check anywhere.

Triggers: `workflow_dispatch`, weekly after the catalog refresh, and as a step of
the `hvtiR` release: run it, and bump only on green. Leaves are not tested here:
they consume no sibling, so their own CI already covers them.

Linux release only. The question is "does this combination work", and the
members' own matrices answer the platform question.

## The release sequence this supports

1. Tag the leaves (members with no family dependencies), in any order.
2. Re-run the dependents' `main` push runs (piece 2); merge and tag them.
3. `hvtiRtemplates` last among members, raising only floors whose versions are
   on `main` (piece 1 reports any that are not).
4. Run the catalog refresh. Its floor table must be all `TRUE`.
5. Run `family-integration.yml` (piece 3). Bump `hvtiR` on green.

## Alternatives considered

- **A required cross-repository check on every member PR.** Rejected: one red
  sibling would block unrelated work in twelve repositories, and the check would
  be bypassed within a week.
- **A monorepo.** Out of proportion to the problem, and it would end
  independent versioning, which the catalog and `status()` depend on.
- **Hand-maintained tiers in `AGENTS.md`.** That is the status quo, and it
  drifts. The table derives the tiers from the `DESCRIPTION` files that already
  state them.

## Open questions

1. **Time budget for piece 3.** `hvtiRtemplates`' suite renders Quarto jobs and
   is the slowest in the family. Measure the first run before choosing weekly
   or per-release.
2. **Should a `Suggests` floor ever fail?** `hvtiRtemplates` suggests ten
   members, and a template that needs a newer member fails at render time,
   not install time. Starting as a warning; revisit if one reaches an analyst.
3. **Members on CRAN.** `ggRandomForests` and `TemporalHazard` also publish to
   CRAN, where a floor must be met by CRAN's version. The table checks `main`
   only; CRAN floors stay with those packages' release gates.

## Implementation outline

Piece 1 first; it is the smallest and the other two read its table.

1. `refresh_catalog_versions.py` writes `family-floors.csv`, tested on fixture
   `DESCRIPTION` files the same way the version columns are.
2. `catalog-versions.yml` fails on an unsatisfied hard floor and warns on a
   `Suggests` floor; its PR body gains a floor section.
3. The release rule in `AGENTS.md` and the family release checklist.
4. `family-integration.yml`, measured once by hand before it gets a schedule.
