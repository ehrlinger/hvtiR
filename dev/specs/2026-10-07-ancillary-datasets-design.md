# Ancillary, subset and combined datasets

**Written** 2026-10-07.
**Status** Design, approved. Not implemented.
**Repos** `hvtiRutilities` (registration and status), `hvtiRtemplates` (the job
data step and the `bd` build), `hvtiRdatabuild` (stale analysis sets). Recorded in
`hvtiR`; see [the overview](2026-10-07-team-review-overview.md).
**Depends on** design 2,
[dated parquet and `update_manifest()`](2026-10-07-dated-parquet-manifest-design.md):
parent versions are its dated parquet names, and the out-of-date note is its note.
**Order** Sixth. After design 2; independent of designs 3 to 5.

---

## 1. The problem

A study rarely lives in one file. The training named three kinds of dataset:

- **built**, one row per patient, the study dataset;
- **subsets** of it, fewer columns or rows (the 500-column `built` cut down for one
  analysis);
- **ancillary** data with many rows per patient, such as echoes, labs or other
  longitudinal measurements, which "gets joined to the built data set type".

The team joins in both places today: "we are reading everything in joined in the
build", and also per analysis. The family supports less than that:

- `_study.yml` can register any number of datasets under `additional_datasets:`,
  but records nothing about what kind each one is or which columns make its rows
  unique.
- `read_job_data()` (hvtiRtemplates) reads **one** dataset or analysis set. Its
  `key =` allows repeated measures, but every job has to restate the key, and
  nothing joins an ancillary dataset to the cohort, so each job writes its own
  merge.
- Analysis sets (hvtiRdatabuild) are the subset kind already, with a recorded
  parent. When the parent changes, `read_analysis_set()` stops.
- A dataset built by joining two others records neither of them, so nothing says
  when it is out of date.

## 2. Decisions

| question | decision |
|---|---|
| where the join happens | both: a job may join at read time, and a build may produce a combined dataset |
| which side decides the rows | the cohort decides the patients; the job chooses one row per ancillary record, or one row per patient by a named rule |
| where kind and key live | recorded at registration; a job may override the key; never inferred from the data |
| a combined dataset whose parent changed | runs, and says so with the commands that rebuild it |
| a stale analysis set | runs with a note in a draft render; stops in a final render; both messages give the commands |

## 3. Registration (hvtiRutilities)

`register_data()` gains three arguments:

```r
register_data(root, "echo.sas7bdat", role = "named", dataset = "echo",
              kind = "ancillary", key = c("ccfid", "echo_date"))

register_data(root, "built_echo.sas7bdat", role = "named", dataset = "built_echo",
              kind = "combined", key = c("ccfid", "echo_date"),
              parents = c("study", "echo"))
```

- **`kind`** is one of `"built"`, `"subset"`, `"ancillary"` or `"combined"`. The
  default dataset is `"built"`. A named dataset with no `kind` stays as it is today.
- **`key`** names the columns that make a row unique. Registration checks it and
  stops, before writing anything, if any row repeats on the key or any key column is
  missing. The message gives counts, never values.
- **`parents`** is required for `"combined"` and refused for every other kind. Each
  parent must already be registered. Registration records each parent's current
  version, its dated parquet name from design 2.
- `update_manifest()` with no arguments (design 2) re-checks `key` when it
  registers a new version, and keeps `kind`, `key` and `parents`.

`_study.yml` records them on the dataset's entry:

```yaml
additional_datasets:
  echo:
    built: echo.sas7bdat
    kind: ancillary
    key: [ccfid, echo_date]
  built_echo:
    built: built_echo.sas7bdat
    kind: combined
    key: [ccfid, echo_date]
    parents:
      study: built_20261007.parquet
      echo: echo_20261002.parquet
```

Datasets registered before this change have no `kind` or `key` and read exactly as
before.

## 4. Out of date: one note, with the fix

Three situations make data out of date. All three signal a condition of class
`hvtiRutilities_out_of_date`, whose text always ends with the exact commands that
bring it up to date. Each also carries a class for its cause:
`hvtiRutilities_source_changed` (design 2's class, now a subclass of this one),
`hvtiRutilities_parent_changed` for a combined dataset, and
`hvtiRutilities_stale_analysis_set`. A template catches the parent class once. Templates print it at the top of the report, the way design 2
prints its note.

| situation | draft render | final render |
|---|---|---|
| `built.sas7bdat` rebuilt but not registered (design 2) | runs, note | runs, note |
| a combined dataset whose parent has a newer version | runs, note | runs, note |
| an analysis set cut from an older parent, or whose declaration changed | runs, note | **stops**, same text |

The first two run even in a final render because the job read a registered,
internally consistent version, which can be deliberate (a manuscript revision stays
on the version its paper used). An analysis set is different: its exclusions were
decided against the old parent, so an accepted result is not built on it until
someone has looked at the new attrition.

`study_status()` lists every out-of-date dataset and analysis set.
`update_manifest()` lists them after registering, because registering a new `built`
is what makes them out of date.

Example messages:

> `built_echo` was built from `built_20260915.parquet`; `built` is now
> `built_20261007.parquet`. This job used the older combined data. To update it,
> render the build job that writes `built_echo.sas7bdat`, then run
> `hvtiRutilities::update_manifest()`.

> The analysis set `eda` was cut from `built_20260915.parquet`; `built` is now
> `built_20261007.parquet`. This draft used the older cut. To update it, run
> `hvtiRdatabuild::write_analysis_set("eda", hvtiRutilities::study_config())`,
> review the attrition it prints, then render again.

The final-render version of the second ends "A final render does not use a stale
cut." instead of "This draft used the older cut."

## 5. Analysis sets (hvtiRdatabuild)

`read_analysis_set()` changes from "stop when stale" to the rule in section 4:

- **Draft render.** It reads the set and signals `hvtiRutilities_out_of_date` with
  the commands. This covers both causes it detects today: a changed parent, and a
  changed declaration in `_study.yml`.
- **Final render.** It stops with the same text. "Final" is read from
  `HVTI_TEMPLATE_STRICT`, the variable `render_job(final = TRUE)` sets, with the
  templates' own rule: unset, `0`, `false` and `no` mean draft; anything else means
  final, so a mistyped value fails safe.
- **A set whose parquet no longer matches its manifest entry** still stops in every
  render. That is damaged data, not out-of-date data.
- The help page's reason for always stopping ("A stale set is never rebuilt
  silently: its exclusions are decisions") is rewritten to explain the draft and
  final split. Nothing is ever rebuilt silently; the change is only whether a draft
  may read the old cut.
- `NEWS.md` entry, since this reverses documented behaviour.

## 6. Joining in a job (hvtiRtemplates)

`read_job_data()` gains three arguments:

```r
read_job_data(cfg, dataset = "study", analysis_set = NULL,
              join = NULL, join_vars = NULL, reduce = NULL,
              where = NULL, id = "ccfid", key = NULL)
```

**The cohort** is whatever the job reads without the join: `dataset`, or
`analysis_set`. It decides which patients are in.

**`join = "echo"`** names one registered ancillary dataset, matched to the cohort on
`id`. It must have `kind: ancillary` or a `key` from the job.

**Long form (the default).** One row per ancillary record, for cohort patients
only. Each row carries the cohort's columns, or only those named in `join_vars`
(the `id` always). The result's key is the ancillary key. Records from patients
outside the cohort are dropped and counted.

**Reduced form.** `reduce` gives one row per cohort patient:

```r
reduce = list(rule = "first",   by = "echo_date")
reduce = list(rule = "last",    by = "echo_date")
reduce = list(rule = "nearest", by = "echo_date", to = "dos")
```

- `by` is an ancillary column that orders the records; `to` is a cohort column,
  used only with `nearest`.
- A tie on `by` stops with a count, because picking one silently is a hidden
  choice.
- Every cohort patient keeps one row. A patient with no ancillary record keeps the
  row, with the ancillary columns missing, and is counted.
- The result's key is `id`.

**Keys.** The registered `key` is the default. A job's `key =` overrides it and is
recorded; when it differs from the registered key, the report prints one line
saying so. With no key from either place, the read stops: "echo has no registered
key and this job sets none. Register it with key = ..., or set key = in this job's
study choices."

**Provenance.** The job's provenance record lists the version of every dataset it
read (cohort and ancillary), the key used, the reduction rule, and the counts:
ancillary records dropped as outside the cohort, and cohort patients with no
record. It never lists identifiers or values, following the existing rules in
`read_job_data()`.

**`where`** applies to the joined result, so a condition may name columns from
either side. Its existing identifier checks apply unchanged.

## 7. Building a combined dataset (hvtiRtemplates `bd`)

The `bd` build template gains an optional step that joins an ancillary dataset
in the build, with the same `join`, `join_vars` and `reduce` choices as section 6,
saves the result, and, when the author chooses, registers it with
`kind = "combined"`, its `key` and its `parents`. This is the "save, with an option
to register" step described in the training.

## 7a. Amendments made while planning (2026-10-07)

Recorded in [the plan](2026-10-07-ancillary-datasets-plan.md) too.

1. **Parent versions live in the manifest.** `_study.yml` lists a combined
   dataset's parent names; the versions it was built from are its manifest
   entry's `parent_versions:`, because `manifest.yaml` is the version record and
   `update_manifest()` writes only that file. Section 3's YAML example is
   superseded on this point.
2. **The cohort's key still falls back to `id`.** "No key anywhere stops"
   applies to the joined dataset. A job reading one dataset with no registered key
   and no `KEY` uses `ID`, as it does today.
3. **`join_key` overrides the joined dataset's key**; `key` keeps meaning the
   cohort's. A long join is keyed on the joined dataset's key, a reduced join on
   `id`.
4. **Section 7 is deferred.** The `bd` template builds the study dataset from a
   master snapshot and never holds the registered study dataset, so "combined from
   the study dataset and echo" does not fit it. A combined dataset is registered
   with `register_data(kind = "combined", parents = ...)` from whatever builds it;
   a build template for combined datasets is a later design.
5. **Templates offer the join** as `JOIN`, `JOIN_VARS`, `REDUCE` and `JOIN_KEY` in
   their study choices, without an `EDIT:` marker, so a finished job does not
   render as a draft. This edits every template that reads data, after designs 3
   to 5.
6. **`study_status()` lists out-of-date combined datasets**, not analysis sets,
   which hvtiRdatabuild owns.

## 8. Not in this design

- Joining more than one ancillary dataset in a single read.
- Reduction rules beyond first, last and nearest, and aggregates such as a
  patient's mean or number of echoes.
- Joining two ancillary datasets to each other.
- Rebuilding an out-of-date combined dataset or analysis set automatically. The
  message gives the commands; a person runs them.

## 9. Tests

All fixtures synthetic, no PHI.

- **Registration.** A unique key registers; a repeated key stops with a count and no values; a missing key column stops; `parents` is required for `combined` and refused otherwise; parent versions are recorded.
- **Long join.** The rows are cohort patients only, outside records are counted, `join_vars` limits the carried columns, and the result's key is the ancillary key.
- **Reduction.** Each of first, last and nearest picks the right record; a tie stops; a patient with no record keeps a row with missing ancillary columns and is counted.
- **Keys.** A job override is used and reported; no key anywhere stops with both fixes named.
- **Out of date.** A combined dataset with a newer parent reads, and signals the message with its commands, in both draft and final. A stale analysis set reads with the message in a draft, and stops with the same commands under `HVTI_TEMPLATE_STRICT=1`. A damaged analysis-set parquet stops in both.
- **Provenance.** It records both datasets' versions, the key and the counts, and no identifiers.
- **Compatibility.** Datasets registered without `kind` or `key` read exactly as before.
