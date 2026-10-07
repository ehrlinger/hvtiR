# Registering converts to a dated parquet, and `update_manifest()` runs with no arguments

**Written** 2026-10-07.
**Status** Design, approved. Not implemented.
**Repo** `hvtiRutilities`. Templates in `hvtiRtemplates` pick up the report note
(section 6). Recorded in `hvtiR`; see
[the overview](2026-10-07-team-review-overview.md).
**Builds on** the Promotion section of
`hvtiRutilities:dev/specs/2026-08-25-read-layer-manifest-parquet-design.md`,
which this design brings forward to registration and dates. A design that departs
from that one says where (section 9).
**Order** Second of five.

---

## 1. The problem

The team names the current study dataset `built.sas7bdat` and rebuilds it in place,
often many times before it is right. The training settled that convention for now:
the current file is always `built`, and only archived copies carry a date.

Today that convention breaks the templates every time `built` is rebuilt. A
template begins with `verify_manifest()`, the recorded SHA-256 no longer matches,
and the render stops. Getting it running again took one user five attempts in a
single session, because:

1. **No call is named for the job.** `register_data()` refuses a dataset that is
   already registered. `update_manifest(file, ...)` works but replaces the whole
   entry and drops fields. `read_built(refresh = TRUE)` is the working route, and
   nothing about its name says "accept the new data".
2. **The working route can do nothing, silently.** Without `arrow`, or with
   `options(hvtiRutilities.disable_parquet_cache = TRUE)`, `read_built()` skips
   the cache and never rewrites the manifest entry (`.cache_enabled()`,
   `R/parquet_cache.R:15`).
3. **Paths depend on the working directory.** `update_manifest()` and
   `verify_manifest()` default to `"manifest.yaml"` in `getwd()`. Run from a job
   folder, they write or check the wrong file.
4. **The error does not name a fix.** `verify_manifest()` reports
   `SHA-256 mismatch` with two hashes. In the training a statistician said, of the
   explanation, "I don't even understand the language".
5. **Overwriting `built` destroys the previous version.** Nothing kept it, so a
   paper's data cannot be reproduced once `built` moves on. This was the
   presenter's main argument for dated names in the training.

## 2. The idea

Keep `built.sas7bdat` as the SAS-side working file, free to change. When a
version is accepted, convert it once to a dated parquet, and have R jobs read only
that parquet.

```
datasets/
├── built.sas7bdat               SAS working file, rebuilt at will
├── built_20261007.parquet       registered version (current)
├── built_20261007.schema.csv    its SAS column record
├── built_20260915.parquet       an earlier registered version
└── built_20260915.schema.csv
```

This answers all five problems at once. A rebuild no longer touches anything a job
reads (1, 4). Conversion happens in one place, with `arrow` required, so nothing is
skipped silently (2). Every accepted version survives as its own dated file (5).
Section 4 fixes (3).

## 3. Registration

`register_data(built = "built.sas7bdat", ...)` for a legacy (not release-aware)
contract now:

1. Reads the SAS file once with `read_clinical_data(convert_types = FALSE)`.
2. Writes `<stem>_YYYYMMDD.parquet` and `<stem>_YYYYMMDD.schema.csv` in the
   study's datasets folder, through the existing atomic writer, and verifies the
   parquet by reading it back (`.verify_parquet_roundtrip()`).
3. Writes the manifest entry (section 5).

**The date** is the SAS file's modification date, because that is when it was
built. `extract_date =` overrides it. A second version on the same date gets
`_r2`, `_r3` and so on.

**`arrow` is required.** Without it, registration stops before writing anything,
with an install hint. It stays in `Suggests`; the requirement is enforced at the
call, as `pak` is in `hvtiR`.

Release-aware contracts (`catalog_dataset`, `release_id`) are unchanged.

## 4. `update_manifest()` with no arguments

The team's word for "accept the new data" is "update the manifest", so that is the
call.

```r
update_manifest()                      # every registered dataset that changed
update_manifest(dataset = "study")     # just one ("built" too, once design 3 lands)
```

With `file` missing, it:

1. **Finds the study** with `study_config()`, walking up from `getwd()`, and uses
   `<root>/manifest.yaml`. Outside a study it stops: "update_manifest() with no
   file looks for a study (a `_study.yml` here or above) and found none. To
   record a single file, pass it: `update_manifest("path/to/file")`."
2. **Finds changed datasets.** For each registered dataset whose SAS file no
   longer matches the entry's `source_sha256`, it converts the file to a new dated
   parquet as in section 3. The previous current version moves to `history:`.
3. **Leaves unchanged datasets alone** and says so.
4. **Refuses release-aware datasets**, naming `review_data_update()` and
   `adopt_data_update()`.
5. **Reports in plain language**, for example:

   ```
   built: registered built_20261007.parquet (378 rows, 879 columns)
          previous version kept as built_20260915.parquet
   cohort: unchanged since 2026-09-15
   ```

With `file` given, `update_manifest(file, ...)` keeps its current behaviour
exactly, for one-off files outside a study's contract.

The help page has two sections, **In a study** (no arguments, first) and **A single
file**, so the common case is the first thing a reader sees.

## 5. The manifest entry

```yaml
- file: built.sas7bdat           # the dataset's identity, unchanged
  role: primary                  # the parquet is the data
  parquet: built_20261007.parquet
  sha256: <parquet hash>
  source_sha256: <built.sas7bdat hash when registered>
  extract_date: '2026-10-07'
  n_rows: 378
  n_cols: 879
  schema_sha256: <hash of built_20261007.schema.csv>
  reader: haven 2.5.5
  history:
    - parquet: built_20260915.parquet
      sha256: ...
      source_sha256: ...
      extract_date: '2026-09-15'
      n_rows: 377
      n_cols: 879
      schema_sha256: ...
```

The explicit `parquet:` field replaces the stem rule (`built.sas7bdat` →
`built.parquet`, `.derived_paths()`), which cannot name a dated file. Entries
without `parquet:` keep the stem rule, so existing promoted entries still resolve.

`manifest.yaml` itself is the record of which version is current. A coherent Git
strategy is a later item (section 10), so nothing here depends on Git history.

## 6. Reading and verifying

**`read_built()`** reads the entry's current `parquet`, after checking its
SHA-256. When the SAS file has changed since registration it still reads the
parquet, and signals a message of class `hvtiRutilities_source_changed`:

> built.sas7bdat has changed since it was registered on 2026-10-07. This job used
> the registered version. Run `update_manifest()` to register the new one.

Signal it with both classes from the start,
`c("hvtiRutilities_source_changed", "hvtiRutilities_out_of_date", "message", "condition")`,
so that design 6, which adds the other out-of-date cases under the shared
`hvtiRutilities_out_of_date`, needs no change here.

**Templates** catch that class and print the same text as a visible note at the
top of the rendered report. The job is not marked draft and does not stop. Its
provenance sidecar already records the parquet it read (`R/provenance.R`, which
records the authoritative file for a `primary` entry), so the report names its own
data version.

**`verify_manifest()`**:

- checks the current parquet and every parquet in `history:`;
- treats a changed SAS file as **pending, not failed**: status `PENDING`, with the
  same message, and it does not stop;
- still **stops** on a missing or changed parquet, with a message naming what to
  do, for example "built_20261007.parquet does not match its recorded checksum.
  This file is the registered data and must not be edited. Restore it from backup
  and tell the study's data manager.";
- defaults `manifest_path` to the study's manifest when run inside a study, not to
  `getwd()`.

## 7. Migrating an existing study

The first `update_manifest()` on a study using today's layout (`role: source`,
`built.sas7bdat` with a cached `built.parquet`) converts it:

- **The SAS file still matches** the recorded `sha256`: convert it, as a fresh
  registration.
- **The SAS file was overwritten** and the cached `built.parquet` still matches the
  old entry's `n_rows`, `n_cols` and `schema_sha256`: rename that cache to
  `built_<old extract_date>.parquet` as the earlier version, and say in the report
  that it came from the cache, not from the original SAS file. Then register the
  new SAS file.
- **Neither:** say plainly that the earlier version cannot be recovered, then
  register the new SAS file. Stopping would not bring the data back and would leave
  every template blocked.

## 8. Documentation

- `update_manifest()`: the two-section help page (section 4), with a worked
  example of the rebuild-then-update cycle.
- `register_data()`: say that registration converts, where the files go, and that
  `arrow` is needed.
- `dataset-versioning` vignette: rewritten to lead with the study workflow, "rebuild
  `built.sas7bdat`, run `update_manifest()`", before the single-file material.
- Every error and message touched here names the call that fixes it.
- `NEWS.md` entry under `# hvtiRutilities (unreleased)`.

## 9. Departures from the 2026-08-25 read-layer design

- Promotion happens **at registration**, not when SAS stops rebuilding. The SAS
  file is still there, still rebuilt; it is simply no longer what R reads.
- The parquet is **dated**, with an explicit `parquet:` field, instead of a single
  `built.parquet` beside its source. "Nothing moves" no longer holds; versions
  accumulate.
- The schema sidecar is **per version**, written at registration, not captured on
  first read.

## 10. Later items

- **Git.** Tying a job revision to a manifest revision, once the team has a Git
  strategy. Until then the provenance sidecar beside each report is the record.
- **Pruning old versions.** Every accepted version is kept. A pruning rule is not
  designed; a paper revision is exactly when an old version is needed.

## 11. Tests

All fixtures synthetic, no PHI, following the package's existing fixture rules.

- Registration writes a dated parquet and schema file, and a `_r2` on a second same-day version.
- `update_manifest()` with no arguments from a subfolder updates the study's manifest, not one in `getwd()`.
- With nothing changed it writes nothing and says so.
- A changed SAS file: `read_built()` returns the registered data and signals `hvtiRutilities_source_changed`; `verify_manifest()` reports `PENDING` and does not stop.
- A changed parquet: `verify_manifest()` stops with the restore message.
- Without `arrow` (mocked): registration and update stop before writing.
- Migration: each of the three cases in section 7.
- Release-aware datasets are refused with the review and adopt pointer.
- `update_manifest(file, ...)` behaviour is unchanged (existing tests stay green).
