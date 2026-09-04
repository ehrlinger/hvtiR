# The job catalog: routing 53 job types to the packages that owe them

**Written** 2026-09-04.
**Status** Design, approved in outline. Not implemented.
**Repo** `hvtiR`. Consumers: `hvtiRtemplates`, `hvtiPlotR`, `hvtiRtables`,
`ggRandomForests`, `ggBoostedTrees`.

---

## 1. The problem

`hvtiRtemplates` maintains a 53-row ledger at
`dev/specs/artifacts/2026-08-29-template-roadmap.json`, rendered into the
conversion roadmap by `artifacts/roadmap_render.py` and gated in CI by
`artifacts/check-roadmap-counts.py`. Every row is a job type found in the
studies corpus, carrying its SAS breadth, its count of R jobs already written,
and a status.

The ledger answers one question: *when will hvtiRtemplates ship a template for
this?* That question is wrong for a growing share of the rows, because for many
of them the answer is that no template is owed at all. The work belongs to a
function in another package, and in several cases the function already exists
and studies are already calling it.

The ledger has no way to say that. It has a `status` value `out-of-scope`,
rendered on the catalog slide as "the R side already won", used on exactly two
rows. That value conflates two different facts:

- nobody owns this, we are not doing it
- somebody else owns this, and here is what replaced it

Because it cannot distinguish them, the ledger has already drifted. `rfsrc` and
`rf` are marked `out-of-scope`. `rfs`, `rfc` and `rfr` sit on the **same**
`ggRandomForests` reporting surface and are marked `queued`, with 39, 52 and an
uncounted number of R jobs already written against no template and no
complaint. Nothing flagged that, because nothing could.

## 2. What is being built

A **job catalog**: the 53 rows, plus three fields that route each row to the
package that owes it, plus a validator that refuses a routing which does not
correspond to a real export.

The catalog is data with a checker, not a new subsystem. The renderer and the
prose in `hvtiRtemplates` continue to work off it.

## 3. Why `hvtiR`

`hvtiR` imports only `cli` and `utils`. Nothing in the family imports `hvtiR`,
because `hvtiR` is what installs the family. It already ships
`inst/extdata/catalog.csv`, a catalog of published artifacts read by an
internal `catalog()`, and `members()` already carries the family roster and the
dependency graph. Its own `2026-09-02-family-map-handoff.md` states the
principle: `hvtiR` is "the one package whose job is to know about the others".

`hvtiRutilities` was the other candidate, and it is where `hvti_taxonomy()`
lives, so the precedent points there. It is nonetheless wrong, and the reason
is validation rather than vocabulary:

> A routing table that only **records** a destination is a table of strings, and
> strings create no dependency. `hvtiRutilities` could hold it. A routing table
> that **validates** a destination must load that package to read its exports.
> `hvtiRtemplates` and `hvtiRdatabuild` both Import `hvtiRutilities`, so a
> validator living there would have to suggest its own dependents, which the
> installer then has to break by hand.

The decision to validate, rather than merely record, is what chooses the repo.
Had the catalog stayed record-only, `hvtiRutilities` would have been correct.

⚠️ **This splits two related things across two packages, on purpose.**
`hvti_taxonomy()` in `hvtiRutilities` says what a prefix *means*. The job
catalog in `hvtiR` says who *owes* it. A reader looking for one will
reasonably look in the other place first. The catalog's documentation must
name the taxonomy and say why they are apart.

## 4. Storage

`inst/extdata/jobs.json`, read by an internal accessor alongside `catalog()`.

JSON rather than CSV, breaking with `catalog.csv`'s precedent, because the
existing ledger rows carry `upstream`, `downstream` and `workflows` as arrays
and a CSV cannot hold those without a second encoding. The cost of the break is
one file format inconsistency inside `inst/extdata/`; the cost of avoiding it
is inventing a delimiter convention inside CSV cells, which is worse.

The existing 18 fields are carried over unchanged. The catalog is seeded from
`hvtiRtemplates`' ledger, which then stops being the source of truth.

## 5. The three new fields

| field | type | meaning |
|---|---|---|
| `disposition` | enum | what kind of work this row is |
| `destination` | package name or `null` | who owes it |
| `replaced_by` | array of `package::function` | what a reader should call instead |

`disposition` takes four values:

- **`scaffold`** the row is genuinely repeated work: read a built dataset,
  derive variables, fit, report. A template is the deliverable. Destination is
  `hvtiRtemplates`.
- **`thin`** a template is still the deliverable, but its body is mostly calls
  into another package. The value is the `EDIT:` markers and the edit guard,
  not the code between them. Destination is `hvtiRtemplates`; `replaced_by`
  records the functions it leans on, which live elsewhere.
- **`retire`** the work is a function that exists. No template is owed.
  Destination is the owning package; `replaced_by` is required and non-empty.
- **`build`** the work is a function that does **not** exist yet. Destination
  is the package that should write it; `replaced_by` is empty and `blocked_on`
  carries the issue.

`status` and `batch` keep their existing meaning, which is about scheduling:
they answer when `hvtiRtemplates` will ship a template for a row, not whether
the row is done. `out-of-scope` is deprecated, and here is what replaces it,
decided by the maintainer.

`status` and `batch` are `hvtiRtemplates` scheduling fields, so they are null
for a row whose `destination` is neither `hvtiRtemplates` nor `null`: that
repository has nothing of its own to schedule for such a row, so a scheduling
value on it can only drift, the way `rfc` sitting at `queued` on the same
`ggRandomForests` surface that had already justified `out-of-scope` for `rf`
and `rfsrc` did. Concretely, every row whose `destination` is neither
`hvtiRtemplates` nor `null` gets `batch: null`; of those, every row whose
`status` is not `intake` also gets `status: null`.

A `null` destination is exempt from this nulling, meaning "nobody owns this
yet" per rule 1 below. `hvtiRtemplates` itself filters its catalog scan with
destination in (`null`, `hvtiRtemplates`), so a null-destination row is
already in that repository's scope, the same as one destined there, and must
keep its status and batch for that repository's own schema to accept it.

`intake` is exempt from this because it is not a schedule value at all. It
means the prefix has been proposed but is not yet in
`hvtiRutilities::hvti_taxonomy()`, which is a taxonomy fact independent of
which package eventually owes the work, so it survives regardless of
`destination` and keeps its `status` while still losing `batch`.

`out-of-scope` itself is retired rather than repurposed: the two rows that
carried it (`rf`, `rfsrc`) become `disposition: retire` with `status: null`,
and the value is removed from the catalog and from any enum or documentation
that lists it once no row uses it.

## 6. Validation rules

These run as `hvtiR` tests. This is option B from the design conversation;
option C is deferred, see §9.

1. `destination` must be a package named by `members()`, or `null`. A
   destination outside the family is a typo or a package nobody installs.
2. `disposition == "retire"` requires `destination` non-null and `replaced_by`
   non-empty. Retiring a row against nothing is the failure this catalog
   exists to prevent.
3. Every entry in `replaced_by` is written `package::function`, its package
   must be named by `members()`, and its function must appear in that package's
   `getNamespaceExports()`. A function that is not exported is not a
   replacement a study author can call.

   ⚠️ **`replaced_by` is qualified because it is not always in `destination`.**
   A `thin` row is destined for `hvtiRtemplates` and leans on `hvtiPlotR`
   functions; validating it against its own destination would fail every time.
   `destination` says who owes the remaining work, `replaced_by` says what
   already exists, and they are frequently different packages.
4. `disposition %in% c("scaffold", "thin")` requires
   `destination == "hvtiRtemplates"`, since those dispositions are statements
   about a template.
5. `disposition == "build"` requires `destination` non-null, `replaced_by`
   empty, and `blocked_on` non-null.
6. Every row has a `disposition`. There is no default, because the whole point
   is that the question gets asked once per row.
7. `status` and `batch` are null for a row whose `destination` is neither
   `hvtiRtemplates` nor `null`, except that `status == "intake"` survives
   regardless of `destination`. A row whose `destination` is `hvtiRtemplates`
   or `null` must still have a `status`.

### ⚠️ Skips must be loud

Rule 3 needs the destination package installed. The obvious implementation is
`skip_if_not_installed(destination)`, and the obvious implementation is a trap:
`R CMD check` reports a skip as success, so the family could drift for months
under a green check.

`hvtiRtemplates`' `AGENTS.md` records the cost of exactly this, from
`hvtiRlifetables`, where a regression guard read `SKIP 5 | PASS 474` on two
platforms and had never once run on Windows across ten green runs.

So:

- The test suite must report which destinations went unvalidated, by name, in
  the test output, not merely skip them.
- CI must install every destination package, so that in CI the skip count is
  zero. A non-zero skip count in CI is a failure, not a note.
- The local developer experience may skip; CI may not.

## 7. The consumer coupling

`hvtiRtemplates`' `check-roadmap-counts.py` currently reads the ledger as a
sibling file. After the move it must read the catalog from `hvtiR`, and it
**cannot** do so by depending on `hvtiR`, which would invert the family.

The checker reads a JSON file and needs no R. So `hvtiRtemplates`' workflow
gains a second `actions/checkout` of `ehrlinger/hvtiR` at a pinned ref, and the
checker takes a path argument. No new dependency in either `DESCRIPTION`.

`hvtiRtemplates`' checker then filters to `destination == "hvtiRtemplates"`
before its existing two-way count against `inst/templates/`. Rows routed
elsewhere stop being its business, which is the point: a `retire` row no longer
reads as a template hvtiRtemplates failed to ship.

## 8. Evidence behind the seed values

Two coverage audits were run on 2026-09-04 against installed sources. They are
recorded here because the seed values are only as good as they are, and a later
reader should be able to tell a measured verdict from a guessed one.

### graphs rows against `hvtiPlotR` 2.7.12, 125 man pages

| row | SAS / R jobs | coverage | disposition |
|---|---|---|---|
| `dp-trends` | not counted | `hv_trends`, `plot.hv_trends` | thin |
| `dp-spaghetti` | not counted | `hv_spaghetti` | thin |
| `dp-gfup` | not counted | `hv_followup` | thin |
| `np` | 248 / 201 | `hv_nonparametric`, `hv_ordinal` | thin |
| `hp` | 557 / 24 | `hv_hazard`, `hazard_plot`, `hv_survival`, `hv_atrisk_compose` | thin |
| `rp` | 76 / 8 | `hv_balance`, `calc_smd`; regression half absent | thin |
| `mp` | 82 / 5 | `hv_spaghetti`; no population overlay | thin |
| `lp` | 636 / 606 | `hv_mirror_hist` only | thin |
| `dp-procs` | not counted | `hv_longitudinal`, `hv_stacked`, partial | thin |
| `cp` | 5 / 1 | none (`km_build_cumhaz_plot` is cumulative hazard) | build |
| `ce` | 131 / 1 | dataset `parametric` only, no function | build |
| `gp` | 50 / 2 | none | build |
| `fp` | 19 / 20 | none | build |
| `hs` | 144 / 11 | not a plot; TemporalHazard predictions | scaffold |

⚠️ **No graphs row is `retire`.** The hypothesis that opened this work was that
the graphs folder was wholly absorbed by `hvtiPlotR`. It is not. Four rows have
no function at all, and the nine that do still need a job to read the built
dataset, derive variables, choose a theme and save at the right dimensions.
`hvtiPlotR`'s contract is `hv_*()` prepare then `plot.hv_*()` render, which
leaves the fitting and reshaping to the caller.

⚠️ **`fp` is the sharpest finding.** Every `forest` match in `hvtiPlotR` is the
colour literal `"forestgreen"`. There is no forest plot function, and `fp` has
20 R jobs against 19 SAS templates, the only graphs row where R exceeds SAS.
Studies are writing forest plots by hand, repeatedly, with nothing shared.

### machine-learning rows against `ggRandomForests` 4.0.0 and `ggBoostedTrees` 0.0.3

| row | SAS / R jobs | coverage | disposition |
|---|---|---|---|
| `rfsrc` | 131 / 631 | `gg_rfsrc`, `gg_survival`, `gg_error`, `gg_vimp`, `gg_partial` | retire |
| `rf` | 47 / 312 | same surface via `.randomForest` methods | retire |
| `rfs` | 25 / 39 | `gg_rfsrc.rfsrc`, `gg_survival`, `gg_error`, `gg_vimp` | retire |
| `rfc` | 19 / 52 | `gg_roc`, `gg_brier`, `gg_error`, `calc_auc` | retire |
| `rfr` | not counted | `gg_rfsrc` regression path, `gg_vimp`, `gg_shap` | retire |
| `nb` | 21 / 63 | `gg_boost_*` covers boostmtree; BoostMLR uncovered | build |
| `sid` | not counted | none | build |
| `vt` | not counted | none | build |

`ggRandomForests` 4.0.0 exports 26 `gg_*` constructors, each with `autoplot`,
`plot`, `summary` and `print` methods. This is the one family where "the R side
already won" is literally true, and it is where every `retire` row lives.

⚠️ **`sidClustering` appears zero times in `ggRandomForests`.** `vt` appears
twice, both inside `gg_partial_varpro`'s documentation describing Unlimited
Virtual Twins as machinery `varpro` uses internally. Neither is an entry point.
Both are `intake` rows blocked on a taxonomy PR, and neither has a function
waiting for it.

⚠️ **`ggBoostedTrees` is 0.0.3 with three constructors, and `BoostMLR` sits in
`Suggests` while appearing in no `R/`, `tests/` or `vignettes/` file.** Routing
`nb` there routes half a job type to declared intent. The `build` disposition
is correct, and the row should not be read as covered.

The remaining rows, in `datasets`, `descriptives`, `distributions`, `analysis`
and `documents`, have not been audited. They are seeded `scaffold` with
`destination: hvtiRtemplates`, which is their status quo, and each becomes a
question to answer rather than an assumption already made. `dc`'s five split
rows are the most likely to move, to `hvtiRtables`, whose `hv_tbl_summary` is
the Table 1 job.

## 9. Deferred: coverage consistency

Rule set B catches a row retired against a function nobody wrote. It does not
catch the `rfc` failure, which is two rows sitting on the **same** function
surface with different dispositions.

The check that would catch it needs a "shares a surface" relation, and no such
relation exists today. Defining one badly gives a gate that is wrong more often
than the humans it replaces, so it is out of scope for the first
implementation.

Two candidate definitions, for whoever picks this up:

- **By `replaced_by` overlap.** Two rows share a surface when their
  `replaced_by` sets intersect. Cheap, mechanical, and only works once rows
  are populated, so it cannot have caught `rfc`, whose `replaced_by` was
  empty.
- **By destination plus family.** Two rows share a surface when they have the
  same `destination` and the same `family`. That would have caught `rfc`:
  `rf`, `rfsrc`, `rfs`, `rfc` and `rfr` are all `machine-learning` routed to
  `ggRandomForests`, and three dispositions among them is the anomaly. It is
  also crude enough to produce false positives wherever one package legitimately
  owes both a function and a template in the same family.

The second is the one worth prototyping, as a **report** rather than a gate,
until it has been wrong or right often enough to judge.

## 10. Out of scope

- Rewriting `roadmap_render.py`. It reads the same rows plus three fields and
  needs a column, not a redesign.
- Retiring any template that currently ships. `hp` is `status: revisit` and
  `disposition: thin`; deciding its fate is separate work.
- The `dc` and `dp` re-count. Thirteen rows carry no SAS or R counts pending
  the 2026-09-03 split re-count, and the catalog carries the gap rather than
  filling it.
- Moving the taxonomy. `hvti_taxonomy()` stays in `hvtiRutilities`.
