# Dated parquet and `update_manifest()`: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Registering a study dataset converts it once to a dated parquet that R jobs read; `update_manifest()` with no arguments registers a rebuilt file as a new dated version and keeps the old one; a rebuilt but unregistered file no longer stops a job.

**Architecture:** One new file in hvtiRutilities, `R/registered_versions.R`, owns everything about a registered version: naming, converting, recording, detecting a changed source, and moving a version into history. `register_data()`, `read_built()`, `verify_manifest()`, `update_manifest()`, `study_status()`, `provenance_data()` and the release-aware integrity check each gain a small branch that calls into it when a manifest entry carries a `parquet:` field. Entries without that field keep their current code path untouched, so unregistered and release-aware studies behave exactly as before. Two downstream repositories then follow: hvtiRdatabuild identifies an analysis set's parent by its registered version, and hvtiRtemplates shows the "rebuilt since registration" note in each job's data table.

**Tech Stack:** R (>= 4.4.0), testthat edition 3, roxygen2 with **Rd markup**, arrow (in `Suggests`, required at the call), digest, yaml, haven.

**Spec:** `hvtiR/dev/specs/2026-10-07-dated-parquet-manifest-design.md`.

## Global Constraints

- Three repositories, in this order: `ehrlinger/hvtiRutilities` (Phase A, Tasks 1 to 8), then `ehrlinger/hvtiRdatabuild` (Phase B, Task 9), then `ehrlinger/hvtiRtemplates` (Phase C, Task 10). Each phase is its own branch and pull request. Never push to `main`.
- Phase B and C raise their `hvtiRutilities (>= ...)` minimum to the version that ships Phase A. That version is named when hvtiRutilities is bumped after Phase A merges ("bump when you name a version"), so Phases B and C start after that bump.
- hvtiRutilities and hvtiRtemplates roxygen is **Rd markup** (`\code{}`, `\strong{}`, `\link{}`); hvtiRdatabuild roxygen is **markdown**. Check each `DESCRIPTION` before writing a block.
- Line length: 135 in hvtiRutilities and hvtiRtemplates, 100 in hvtiRdatabuild. `lintr::lint_package()` clean in each.
- `arrow` stays in `Suggests`. Registration and update call `.require_arrow()`, which stops with an install hint before writing anything.
- Test fixtures are synthetic. No real data, no patient value, in any fixture or test message.
- Every error or message added names the call that fixes it.
- `NEWS.md` entries go under each package's `# <pkg> (unreleased)` heading, added if absent. Do not touch `Version:`.
- Manifest field names are exactly: `file`, `role`, `parquet`, `sha256`, `source_sha256`, `extract_date`, `n_rows`, `n_cols`, `schema_sha256`, `reader`, `source_size`, `source_mtime`, `history`, plus any other field the entry already carried (`source`, `sort_key`), which is preserved.
- The source-changed condition has class `c("hvtiRutilities_source_changed", "hvtiRutilities_out_of_date", "message", "condition")` (design 6 relies on the second class).
- Dated names are `<stem>_YYYYMMDD.parquet`, then `<stem>_YYYYMMDD_r2.parquet`, `_r3`, and so on; the schema file is the same name with `.schema.csv`.
- `history:` is newest first.
- Definition of done, per repository: `devtools::test()` passes; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` run with `man/` and `NAMESPACE` committed.
- The planning container had no R. Run every command on a machine with R, `devtools`, `arrow` and the Quarto CLI.

## Amendments to the design, made while planning

Recorded in the design file as well.

1. **Where a job shows the note.** The design said "a visible note at the top of the report". Every job's first table is "The data this job read", produced by `read_job_data()`. The note goes in that table as a row (Task 10), so no template file changes. A top-of-report banner would need an edit to every template, which designs 3 to 5 are already doing; it can move there later.
2. **hvtiRdatabuild is affected.** `.built_state()` identifies an analysis set's parent by the manifest checksum plus a stat of `built.sas7bdat`. After this change a rebuilt but unregistered SAS file would make every analysis set stale although R reads nothing new. Task 9 makes the parent the registered parquet.
3. **Legacy-path tests need a legacy fixture.** Many existing tests register a dataset to exercise the old read cache. After Task 2 registration writes the new form, so those tests get a helper that writes the old form directly (Task 2, Step 1).

## File structure

**hvtiRutilities**

| file | change | responsibility |
|---|---|---|
| `R/registered_versions.R` | create | version naming, conversion, records, source-change detection, history, migration, the out-of-date condition |
| `R/register_data.R` | modify | non-release registration writes a version |
| `R/study_data.R` | modify | `read_built()` reads a registered version; `.normalise_built()` extracted |
| `R/provenance.R` | modify | `provenance_data()` records the authoritative file via `.authoritative_path()` |
| `R/data_updates.R` | modify | the promoted-path line uses `.authoritative_path()` |
| `R/manifest.R` | modify | `update_manifest()` with no `file`; `verify_manifest()` checks versions, reports `PENDING`, defaults to the study manifest; legacy mismatch names the fix |
| `R/study_status.R` | modify | `.status_manifest()` reports `PENDING` |
| `tests/testthat/helper-study.R` | modify | `make_legacy_registered_study()`; arrow skips in registering helpers |
| `tests/testthat/helper-release.R` | modify | arrow skip where the helper registers a non-release dataset |
| `tests/testthat/test-registered_versions.R` | create | all new behaviour |
| existing test files | modify | re-baseline (Tasks 2 and 3) |
| `vignettes/dataset-versioning.qmd` | modify | lead with the study workflow |
| `NEWS.md` | modify | entry |

**hvtiRdatabuild:** `R/analysis_set.R`, `tests/testthat/test-analysis_set.R`, `DESCRIPTION`, `NEWS.md`.

**hvtiRtemplates:** `R/job-data.R`, `tests/testthat/test-job-data.R`, `DESCRIPTION`, `NEWS.md`.

---

## Phase A: hvtiRutilities

### Task 1: The registered-version core

**Files:**
- Create: `R/registered_versions.R`
- Test: `tests/testthat/test-registered_versions.R` (create)

**Interfaces:**
- Consumes (existing, unchanged): `read_clinical_data(path, convert_types)`, `dataset_schema(data)`, `.assert_no_lowercase_collision(d, path)`, `.write_parquet_atomic(data, target)`, `.verify_parquet_roundtrip(original, target)`, `.atomic_write(target, write_fn)`, `.reader_provenance(path)`, `.derived_paths(path)`.
- Produces:
  - `.arrow_available()` returns `TRUE`/`FALSE`.
  - `.require_arrow(caller)` stops if arrow is absent.
  - `.version_fields` is a character vector of the version record's field names.
  - `.is_versioned(entry)` returns `TRUE` when `entry$parquet` is a non-empty string.
  - `.authoritative_path(entry, source_path)` returns the path jobs read.
  - `.version_schema_name(parquet)` returns the schema file name.
  - `.version_filename(stem, extract_date, dir, taken = character())` returns the first free dated name.
  - `.source_stamp(path)` returns `list(source_size, source_mtime)`.
  - `.write_version(source, dir, extract_date, taken = character(), caller = "register_data")` returns the version record: `parquet`, `sha256`, `source_sha256`, `extract_date`, `n_rows`, `n_cols`, `schema_sha256`, `source_size`, `source_mtime`, and `reader` when known.
  - `.versioned_entry(file, version, extra = list(), history = list())` returns a manifest entry.
  - `.history_record(entry)` returns `entry` cut to `.version_fields`.
  - `.source_changed(source_path, entry)` returns `TRUE`/`FALSE`.
  - `.source_changed_condition(entry)` returns the condition object.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-registered_versions.R`:

```r
write_source_csv <- function(dir, data = data.frame(id = 1:3, x = c(1.5, 2.5, 3.5)), file = "built.csv") {
  path <- file.path(dir, file)
  utils::write.csv(data, path, row.names = FALSE)
  path
}

test_that("version names are dated and take the next free revision", {
  dir <- withr::local_tempdir()
  expect_identical(.version_filename("built", "2026-10-07", dir), "built_20261007.parquet")
  expect_identical(.version_filename("built", "2026-10-07", dir, taken = "built_20261007.parquet"),
                   "built_20261007_r2.parquet")
  file.create(file.path(dir, c("built_20261007.parquet", "built_20261007_r2.schema.csv")))
  expect_identical(.version_filename("built", "2026-10-07", dir), "built_20261007_r3.parquet")
  expect_identical(.version_schema_name("built_20261007_r3.parquet"), "built_20261007_r3.schema.csv")
})

test_that(".write_version converts once and records the version", {
  skip_if_not_installed("arrow")
  dir <- withr::local_tempdir()
  src <- write_source_csv(dir)

  v <- .write_version(src, dir, "2026-10-07")

  expect_identical(v$parquet, "built_20261007.parquet")
  expect_true(file.exists(file.path(dir, "built_20261007.parquet")))
  expect_true(file.exists(file.path(dir, "built_20261007.schema.csv")))
  expect_identical(v$extract_date, "2026-10-07")
  expect_identical(v$n_rows, 3L)
  expect_identical(v$n_cols, 2L)
  expect_identical(v$sha256, digest::digest(file.path(dir, v$parquet), algo = "sha256", file = TRUE))
  expect_identical(v$source_sha256, digest::digest(src, algo = "sha256", file = TRUE))
  expect_identical(v$schema_sha256,
                   digest::digest(file.path(dir, "built_20261007.schema.csv"), algo = "sha256", file = TRUE))
  expect_true(all(c("source_size", "source_mtime") %in% names(v)))

  v2 <- .write_version(src, dir, "2026-10-07", taken = v$parquet)
  expect_identical(v2$parquet, "built_20261007_r2.parquet")
})

test_that(".write_version stops before writing anything when arrow is absent", {
  dir <- withr::local_tempdir()
  src <- write_source_csv(dir)
  local_mocked_bindings(.arrow_available = function() FALSE)

  expect_error(.write_version(src, dir, "2026-10-07"), "install.packages(\"arrow\")", fixed = TRUE)
  expect_identical(list.files(dir), "built.csv")
})

test_that("the authoritative path follows the entry", {
  src <- file.path("study", "datasets", "built.sas7bdat")
  expect_identical(.authoritative_path(list(parquet = "built_20261007.parquet"), src),
                   file.path("study", "datasets", "built_20261007.parquet"))
  expect_identical(.authoritative_path(list(role = "primary"), src), file.path("study", "datasets", "built.parquet"))
  expect_identical(.authoritative_path(list(role = "source"), src), src)
})

test_that("a changed source is detected and an untouched one is not", {
  skip_if_not_installed("arrow")
  dir <- withr::local_tempdir()
  src <- write_source_csv(dir)
  entry <- .versioned_entry("built.csv", .write_version(src, dir, "2026-10-07"))

  expect_false(.source_changed(src, entry))
  write_source_csv(dir, data.frame(id = 1:4, x = c(1.5, 2.5, 3.5, 4.5)))
  expect_true(.source_changed(src, entry))
  unlink(src)
  expect_false(.source_changed(src, entry))
})

test_that("the source-changed condition names the fix and carries both classes", {
  cond <- .source_changed_condition(list(file = "built.sas7bdat", extract_date = "2026-10-07",
                                         parquet = "built_20261007.parquet"))
  expect_s3_class(cond, "hvtiRutilities_source_changed")
  expect_s3_class(cond, "hvtiRutilities_out_of_date")
  expect_match(conditionMessage(cond), "update_manifest()", fixed = TRUE)
  expect_match(conditionMessage(cond), "built_20261007.parquet", fixed = TRUE)
})

test_that("a versioned entry keeps extra fields and history, and history drops the stamp", {
  v <- list(parquet = "b_20261007.parquet", sha256 = "a", source_sha256 = "b", extract_date = "2026-10-07",
            n_rows = 1L, n_cols = 1L, schema_sha256 = "c", source_size = 1, source_mtime = "x")
  e <- .versioned_entry("b.csv", v, extra = list(sort_key = "id"), history = list(list(parquet = "b_20260915.parquet")))
  expect_identical(e$file, "b.csv")
  expect_identical(e$role, "primary")
  expect_identical(e$sort_key, "id")
  expect_length(e$history, 1L)
  expect_false(any(c("source_size", "source_mtime") %in% names(.history_record(e))))
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: FAIL, `could not find function ".version_filename"` and the like.

- [ ] **Step 3: Write the implementation**

Create `R/registered_versions.R`:

```r
# Registered versions. A study dataset's accepted states, each converted once
# to a dated parquet that R jobs read, while the source (built.sas7bdat) stays
# free to be rebuilt. Design and reasoning: hvtiR
# dev/specs/2026-10-07-dated-parquet-manifest-design.md.
#
# An entry is "versioned" when it carries a `parquet:` field. Everything here
# keys on that field, so entries without it (unregistered studies, release-aware
# contracts, studies registered before 2026-10) keep their existing code paths.

.arrow_available <- function() requireNamespace("arrow", quietly = TRUE)

.require_arrow <- function(caller) {
  if (!.arrow_available()) {
    stop(caller, "(): registering a dataset converts it to parquet, which needs the arrow package. ",
         "Install it with install.packages(\"arrow\") and run this again. Nothing was written.",
         call. = FALSE)
  }
  invisible(TRUE)
}

.version_fields <- c("parquet", "sha256", "source_sha256", "extract_date", "n_rows", "n_cols",
                     "schema_sha256", "reader", "recovered_from")

.is_versioned <- function(entry) {
  is.list(entry) && is.character(entry$parquet) && length(entry$parquet) == 1L &&
    !is.na(entry$parquet) && nzchar(entry$parquet)
}

# The file jobs read for this entry, beside its source.
.authoritative_path <- function(entry, source_path) {
  if (.is_versioned(entry)) return(file.path(dirname(source_path), entry$parquet))
  if (identical(entry$role, "primary")) return(.derived_paths(source_path)$parquet)
  source_path
}

.version_schema_name <- function(parquet) sub("[.]parquet$", ".schema.csv", parquet)

# <stem>_YYYYMMDD.parquet, then _r2, _r3 for further versions on the same date.
# A name is taken when the manifest records it or either of its files exists.
.version_filename <- function(stem, extract_date, dir, taken = character()) {
  base <- paste0(stem, "_", format(as.Date(extract_date), "%Y%m%d"))
  rev <- 1L
  repeat {
    name <- paste0(base, if (rev > 1L) paste0("_r", rev) else "", ".parquet")
    free <- !name %in% taken &&
      !file.exists(file.path(dir, name)) &&
      !file.exists(file.path(dir, .version_schema_name(name)))
    if (free) return(name)
    rev <- rev + 1L
  }
}

.source_stamp <- function(path) {
  info <- file.info(path)
  list(source_size = as.numeric(info$size),
       source_mtime = format(info$mtime, "%Y-%m-%d %H:%M:%OS6", tz = "UTC"))
}

# Convert `source` once. Writes <name>.parquet and <name>.schema.csv in `dir`
# and returns the version record. On any error neither file is left behind.
# The frame is stored as read, before read_built()'s normalisation, as the read
# cache stores it, so a version reads back exactly as a cached source did.
.write_version <- function(source, dir, extract_date, taken = character(), caller = "register_data") {
  .require_arrow(caller)
  before <- file.info(source)
  d <- as.data.frame(read_clinical_data(source, convert_types = FALSE))
  .assert_no_lowercase_collision(d, source)
  after <- file.info(source)
  if (!identical(as.numeric(before$size), as.numeric(after$size)) ||
        !identical(as.numeric(before$mtime), as.numeric(after$mtime))) {
    stop(caller, "(): ", basename(source), " changed while it was being read. Nothing was written; ",
         "wait for the build that writes it to finish, then run this again.", call. = FALSE)
  }

  name <- .version_filename(tools::file_path_sans_ext(basename(source)), extract_date, dir, taken)
  parquet <- file.path(dir, name)
  schema <- file.path(dir, .version_schema_name(name))
  done <- FALSE
  on.exit(if (!done) unlink(c(parquet, schema)), add = TRUE)

  .write_parquet_atomic(d, parquet)
  .verify_parquet_roundtrip(d, parquet)
  .atomic_write(schema, function(tmp) utils::write.csv(dataset_schema(d), tmp, row.names = FALSE))

  record <- c(
    list(
      parquet = name,
      sha256 = digest::digest(parquet, algo = "sha256", file = TRUE),
      source_sha256 = digest::digest(source, algo = "sha256", file = TRUE),
      extract_date = format(as.Date(extract_date), "%Y-%m-%d"),
      n_rows = as.integer(nrow(d)),
      n_cols = as.integer(ncol(d)),
      schema_sha256 = digest::digest(schema, algo = "sha256", file = TRUE)
    ),
    .source_stamp(source)
  )
  reader <- .reader_provenance(source)
  if (!is.null(reader)) record$reader <- reader
  done <- TRUE
  record
}

# `extra` carries fields the entry had besides the version (source, sort_key),
# so an update never drops what registration recorded.
.versioned_entry <- function(file, version, extra = list(), history = list()) {
  entry <- c(list(file = file, role = "primary"), version)
  for (nm in setdiff(names(extra), names(entry))) entry[[nm]] <- extra[[nm]]
  if (length(history)) entry$history <- history
  entry
}

.history_record <- function(entry) entry[intersect(.version_fields, names(entry))]

# The fields an entry carries besides its version, its identity and its history.
.entry_extra <- function(entry) {
  entry[setdiff(names(entry), c("file", "role", "history", "source_size", "source_mtime", .version_fields))]
}

# Has the source changed since this version was registered? A stat settles it
# when the filesystem resolves sub-second mtimes, as .cache_valid() reasons;
# otherwise, or when the stat differs, the hash decides, so a touch without a
# change is not reported. A missing source is not a change: jobs keep reading
# the registered version.
.source_changed <- function(source_path, entry) {
  if (!.is_versioned(entry) || !file.exists(source_path)) return(FALSE)
  if (!is.null(entry$source_size) && !is.null(entry$source_mtime)) {
    info <- file.info(source_path)
    mtime <- as.numeric(info$mtime)
    same_size <- identical(as.numeric(entry$source_size), as.numeric(info$size))
    same_mtime <- abs(mtime - as.numeric(as.POSIXct(entry$source_mtime, tz = "UTC"))) < 1e-4
    if (same_size && same_mtime && mtime != floor(mtime)) return(FALSE)
  }
  !identical(entry$source_sha256, digest::digest(source_path, algo = "sha256", file = TRUE))
}

.source_changed_condition <- function(entry) {
  structure(
    class = c("hvtiRutilities_source_changed", "hvtiRutilities_out_of_date", "message", "condition"),
    list(
      message = paste0(
        entry$file, " has changed since it was registered on ", entry$extract_date,
        ". This job used the registered version, ", entry$parquet,
        ". Run hvtiRutilities::update_manifest() to register the new one.\n"
      ),
      call = NULL
    )
  )
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/registered_versions.R tests/testthat/test-registered_versions.R
git commit -m "Add the registered-version core: dated parquet, records, source-change detection"
```

---

### Task 2: Registration converts, and the tests that relied on the old form are re-baselined

**Files:**
- Modify: `R/register_data.R` (two edits in `register_data()`)
- Modify: `tests/testthat/helper-study.R`, `tests/testthat/helper-release.R`, `tests/testthat/test-register_data.R`
- Test: `tests/testthat/test-registered_versions.R` (append)

**Interfaces:**
- Consumes: `.write_version()`, `.versioned_entry()`, `.version_schema_name()` from Task 1.
- Produces: a non-release `register_data()` writes a versioned entry. Test helper `make_legacy_registered_study(dir, file = "built.csv", data = ...)` returns a study root whose manifest entry has the pre-2026-10 form (`role: source`, no `parquet`).

- [ ] **Step 1: Add the legacy fixture and the arrow skips**

Append to `tests/testthat/helper-study.R`:

```r
# A study registered before 2026-10: role "source" and no parquet field. Written
# directly, because register_data() now writes the versioned form. Used by the
# tests of the legacy read cache and of migration.
make_legacy_registered_study <- function(dir, file = "built.csv",
                                         data = data.frame(id = 1:3, dead = c(1L, 0L, 0L), iv_dead = 1:3)) {
  root <- file.path(dir, "study")
  suppressMessages(study_setup(root, "Legacy fixture", 42L))
  path <- file.path(study_dir("datasets", root), file)
  utils::write.csv(data, path, row.names = FALSE)
  raw <- yaml::read_yaml(file.path(root, "_study.yml"))
  raw$built <- file
  yaml::write_yaml(raw, file.path(root, "_study.yml"))
  entry <- .registration_manifest_entry(path, data, "2026-09-15", NULL)
  yaml::write_yaml(list(datasets = list(entry)), file.path(root, "manifest.yaml"))
  root
}
```

In the same file, make the first statement of `make_registered_study()` `skip_if_not_installed("arrow")`. In `tests/testthat/helper-release.R`, make the first statement inside `if (named) {` in `make_release_aware_study()` `skip_if_not_installed("arrow")` (that branch registers a non-release `default.csv`). In `tests/testthat/test-register_data.R`, make the first statement of `registration_study()` `skip_if_not_installed("arrow")`.

- [ ] **Step 2: Write the failing tests**

Append to `tests/testthat/test-registered_versions.R`:

```r
# A registered study whose source was last modified on 2026-09-15.
versioned_study <- function(env = parent.frame(), data = data.frame(id = 1:3, DEAD = c(1L, 0L, 0L))) {
  skip_if_not_installed("arrow")
  root <- file.path(withr::local_tempdir(.local_envir = env), "study")
  suppressMessages(study_setup(root, "Versioned fixture", 42L))
  path <- file.path(study_dir("datasets", root), "built.csv")
  utils::write.csv(data, path, row.names = FALSE)
  Sys.setFileTime(path, as.POSIXct("2026-09-15 12:00:00", tz = "UTC"))
  suppressMessages(register_data(root, "built.csv"))
  root
}

manifest_entry_for <- function(root, file = "built.csv") {
  m <- yaml::read_yaml(file.path(root, "manifest.yaml"))
  Filter(function(e) identical(e$file, file), m$datasets)[[1L]]
}

test_that("register_data converts the dataset to a dated parquet", {
  root <- versioned_study()
  data_dir <- study_dir("datasets", root)
  e <- manifest_entry_for(root)

  expect_identical(e$role, "primary")
  expect_identical(e$parquet, "built_20260915.parquet")
  expect_identical(e$extract_date, "2026-09-15")
  expect_true(file.exists(file.path(data_dir, "built_20260915.parquet")))
  expect_true(file.exists(file.path(data_dir, "built_20260915.schema.csv")))
  expect_identical(e$sha256, digest::digest(file.path(data_dir, e$parquet), algo = "sha256", file = TRUE))
  expect_identical(e$source_sha256, digest::digest(file.path(data_dir, "built.csv"), algo = "sha256", file = TRUE))
  expect_identical(e$n_rows, 3L)
  expect_null(e$history)
})

test_that("register_data without arrow stops and writes nothing", {
  root <- file.path(withr::local_tempdir(), "study")
  suppressMessages(study_setup(root, "No arrow", 42L))
  path <- file.path(study_dir("datasets", root), "built.csv")
  utils::write.csv(data.frame(id = 1:2), path, row.names = FALSE)
  before <- yaml::read_yaml(file.path(root, "_study.yml"))
  local_mocked_bindings(.arrow_available = function() FALSE)

  expect_error(register_data(root, "built.csv"), "install.packages(\"arrow\")", fixed = TRUE)
  expect_identical(yaml::read_yaml(file.path(root, "_study.yml")), before)
  expect_identical(list.files(study_dir("datasets", root)), "built.csv")
})

test_that("a registration refused after conversion leaves no parquet behind", {
  root <- versioned_study()
  # Registering the same file again under another name passes the early checks,
  # converts it (to built_20260915_r2.parquet), then is refused because the file
  # is already listed in manifest.yaml. The conversion must be cleaned up.
  expect_error(register_data(root, "built.csv", dataset = "again", role = "named"), "already listed")
  expect_identical(list.files(study_dir("datasets", root), pattern = "[.]parquet$"), "built_20260915.parquet")
})
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: the three new tests FAIL (the entry still has `role: source` and no `parquet`).

- [ ] **Step 4: Write the implementation**

In `R/register_data.R`, inside `register_data()`:

Replace the line

```r
  data <- .read_registration_data(path)
```

with

```r
  # A release-aware contract records the catalog's file as it is; every other
  # registration converts the file to a dated parquet below, which reads it.
  data <- if (!is.null(release)) .read_registration_data(path)
```

Replace

```r
  entry <- .registration_manifest_entry(
    path,
    data,
    extract_date,
    source
  )
```

with

```r
  version_files <- character()
  entry <- if (is.null(release)) {
    version <- .write_version(path, dirname(path), extract_date)
    version_files <- file.path(dirname(path), c(version$parquet, .version_schema_name(version$parquet)))
    .versioned_entry(built, version, extra = if (is.null(source)) list() else list(source = source))
  } else {
    .registration_manifest_entry(path, data, extract_date, source)
  }
  registered <- FALSE
  on.exit(if (!registered) unlink(version_files), add = TRUE)
```

and replace

```r
  .replace_study_pair(prepared, targets)
```

with

```r
  .replace_study_pair(prepared, targets)
  registered <- TRUE
```

Update the roxygen `@description` of `register_data()` by adding, after its first paragraph:

```r
#' Registration converts the file once to a dated parquet in the same folder,
#' \code{<name>_YYYYMMDD.parquet}, with its column record beside it as
#' \code{<name>_YYYYMMDD.schema.csv}. That parquet is what \code{\link{read_built}}
#' and the job templates read, so the source file may be rebuilt freely; run
#' \code{\link{update_manifest}()} to register a rebuilt file as a new version.
#' The date is the file's modification date unless \code{extract_date} is given.
#' Conversion needs the \pkg{arrow} package. A release-aware registration
#' (\code{catalog_dataset} and \code{release_id}) records the catalog's file as
#' it is and converts nothing.
#'
```

- [ ] **Step 5: Run the new tests**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: PASS.

- [ ] **Step 6: Re-baseline the existing suite**

Run: `Rscript -e 'devtools::test()'` and list every failure. Fix each by exactly one of these rules, and nothing else:

1. **The test exercises the legacy read cache** (stamps, `refresh = TRUE`, `role: source`, `built.parquet` beside the source, cache invalidation) **through a registered study.** Switch its fixture to `make_legacy_registered_study()`. Behaviour under test is unchanged; only how the study was made.
2. **The test asserts what `register_data()` wrote** (`role`, `sha256`, the manifest entry's fields). Update the expectation to the versioned form: `role` is `"primary"`, `sha256` is the parquet's hash, the source hash is `source_sha256`, and `parquet` names `<stem>_YYYYMMDD.parquet`.
3. **The test asserts a provenance path or file** for a registered dataset (`"datasets/built.csv"`). Expect the dated parquet instead, with a pattern such as `"^datasets/built_[0-9]{8}[.]parquet$"`.

A failure that fits none of the three is a defect in Steps 4 or later; fix the code, not the test. Re-run until `FAIL 0`, and confirm the `SKIP` count rose only by tests that now skip without arrow.

- [ ] **Step 7: Commit**

```bash
git add R/register_data.R tests/testthat
git commit -m "Register a dataset by converting it to a dated parquet

Tests that exercised the legacy read cache through a registered study now
build that study with make_legacy_registered_study(); tests of what
registration writes expect the versioned entry."
```

---

### Task 3: `read_built()` reads the registered version; provenance records it

**Files:**
- Modify: `R/study_data.R` (`read_built()`; new `.normalise_built()` and `.read_registered_version()` above its roxygen block)
- Modify: `R/provenance.R` (`provenance_data()`), `R/data_updates.R` (one line)
- Test: `tests/testthat/test-registered_versions.R` (append); re-baseline as in Task 2, Step 6

**Interfaces:**
- Consumes: `.is_versioned()`, `.authoritative_path()`, `.source_changed()`, `.source_changed_condition()`, `.require_arrow()`.
- Produces: `read_built()` on a versioned entry returns the registered data, normalised as before, and signals `hvtiRutilities_source_changed` when the source moved on. `provenance_data()` records the dated parquet.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-registered_versions.R`:

```r
test_that("read_built reads the registered version and says when the source moved on", {
  root <- versioned_study()
  cfg <- study_config(root)

  expect_no_message(d <- read_built(cfg))
  expect_identical(names(d), c("id", "dead"))
  expect_identical(nrow(d), 3L)

  utils::write.csv(data.frame(id = 1:4, DEAD = c(1L, 1L, 0L, 0L)), built_path(cfg), row.names = FALSE)
  expect_message(d <- read_built(cfg), class = "hvtiRutilities_source_changed")
  expect_identical(nrow(d), 3L)
})

test_that("read_built stops on an edited or missing registered version", {
  root <- versioned_study()
  cfg <- study_config(root)
  parquet <- file.path(study_dir("datasets", root), "built_20260915.parquet")

  cat("tamper", file = parquet, append = TRUE)
  expect_error(read_built(cfg), "does not match its recorded checksum")
  unlink(parquet)
  expect_error(read_built(cfg), "Restore it from backup")
})

test_that("refresh does not apply to a registered version and names update_manifest()", {
  root <- versioned_study()
  expect_error(read_built(study_config(root), refresh = TRUE), "update_manifest()", fixed = TRUE)
})

test_that("provenance records the registered parquet, not the source", {
  root <- versioned_study()
  rec <- provenance_data(cfg = study_config(root))
  expect_match(rec$path, "built_20260915[.]parquet$")
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: the four new tests FAIL.

- [ ] **Step 3: Write the implementation**

In `R/study_data.R`, directly above the comment block that introduces `.assert_no_lowercase_collision` (so nothing sits between a roxygen block and its function), add:

```r
# read_built()'s normalisation, shared by the cached-source and
# registered-version paths so both deliver the same frame.
.normalise_built <- function(d) {
  names(d) <- tolower(names(d))
  logi <- vapply(d, is.logical, logical(1))
  d[logi] <- lapply(d[logi], as.integer)
  lab <- vapply(d, function(x) inherits(x, "haven_labelled"), logical(1))
  d[lab] <- lapply(d[lab], function(x) {
    a   <- attributes(x)
    out <- as.vector(x)
    if (!is.null(a$label)) attr(out, "label") <- a$label
    out
  })
  d
}

# A registered version is the data: checked against its recorded hash on every
# read, and never rebuilt from the source, which may have moved on.
.read_registered_version <- function(source_path, entry) {
  .require_arrow("read_built")
  parquet <- .authoritative_path(entry, source_path)
  if (!file.exists(parquet)) {
    stop("read_built(): the registered version of ", entry$file, ", ", entry$parquet, ", is missing from ",
         dirname(parquet), ". It is the data jobs read and cannot be rebuilt from ", entry$file,
         ". Restore it from backup and tell the study's data manager.", call. = FALSE)
  }
  if (!identical(digest::digest(parquet, algo = "sha256", file = TRUE), entry$sha256)) {
    stop("read_built(): ", entry$parquet, " does not match its recorded checksum. It is the registered data ",
         "and must not be edited. Restore it from backup and tell the study's data manager.", call. = FALSE)
  }
  if (.source_changed(source_path, entry)) message(.source_changed_condition(entry))
  as.data.frame(arrow::read_parquet(parquet))
}
```

In `read_built()`, directly after the two lines

```r
  p <- built_path(cfg, dataset)
  manifest_path <- file.path(cfg$root, "manifest.yaml")
```

insert

```r
  entry <- .manifest_entry(manifest_path, p)
  if (.is_versioned(entry)) {
    if (isTRUE(refresh)) {
      stop("read_built(): refresh = TRUE does not apply to ", basename(p), ", which is registered as ",
           entry$parquet, ". To register a rebuilt ", basename(p), ", run hvtiRutilities::update_manifest().",
           call. = FALSE)
    }
    return(.normalise_built(.read_registered_version(p, entry)))
  }
```

and replace the normalisation at the end of `read_built()`, from `names(d) <- tolower(names(d))` through the final `d`, with

```r
  .normalise_built(d)
```

keeping the comment above `names(d) <- tolower(...)` that explains the collision check, moved to sit above this call.

Add to `read_built()`'s `@description`, after its first paragraph:

```r
#' For a dataset registered with \code{\link{register_data}}, the registered
#' version (a dated parquet) is read, after its checksum is checked. If the
#' source file has been rebuilt since, the registered version is still read
#' and a message of class \code{hvtiRutilities_source_changed} says so and
#' names \code{\link{update_manifest}()}.
#'
```

In `R/provenance.R`, in `provenance_data()`, replace

```r
  authoritative <- if (identical(entry$role, "primary")) {
    .derived_paths(source)$parquet
  } else {
    source
  }
```

with

```r
  authoritative <- .authoritative_path(entry, source)
```

In `R/data_updates.R`, replace

```r
    path <- if (promoted) .derived_paths(source_path)$parquet else source_path
```

with

```r
    path <- .authoritative_path(entry, source_path)
```

- [ ] **Step 4: Run the tests, then re-baseline**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`. Expected: PASS.
Then run `Rscript -e 'devtools::test()'` and apply the three rules of Task 2, Step 6 to any new failure. Expected: `FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add R/study_data.R R/provenance.R R/data_updates.R tests/testthat
git commit -m "Read and record the registered version, and say when its source moved on"
```

---

### Task 4: `verify_manifest()` checks versions, reports PENDING, finds the study's manifest

**Files:**
- Modify: `R/manifest.R` (`verify_manifest()`, plus two helpers above it), `R/study_status.R` (`.status_manifest()`)
- Test: `tests/testthat/test-registered_versions.R` (append)

**Interfaces:**
- Consumes: `.is_versioned()`, `.version_fields`, `.version_schema_name()`, `.source_changed()`, `.source_changed_condition()`.
- Produces: `verify_manifest()` rows may have status `"PENDING"`, which never stops; its `manifest_path` defaults to the study's manifest inside a study. `.status_manifest()` returns status `"PENDING"` when the only finding is a rebuilt source.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-registered_versions.R`:

```r
test_that("verify_manifest checks the version and treats a rebuilt source as pending", {
  root <- versioned_study()
  cfg <- study_config(root)
  manifest <- file.path(root, "manifest.yaml")

  rep <- verify_manifest(manifest)
  expect_identical(rep$status, "OK")

  utils::write.csv(data.frame(id = 1:4, DEAD = c(1L, 1L, 0L, 0L)), built_path(cfg), row.names = FALSE)
  expect_no_error(rep <- verify_manifest(manifest))
  expect_identical(rep$status, c("OK", "PENDING"))
  expect_match(rep$message[[2L]], "update_manifest()", fixed = TRUE)
})

test_that("verify_manifest stops on an edited version with the restore message", {
  root <- versioned_study()
  cat("tamper", file = file.path(study_dir("datasets", root), "built_20260915.parquet"), append = TRUE)
  expect_error(verify_manifest(file.path(root, "manifest.yaml")), "restore it from backup")
})

test_that("verify_manifest finds the study's manifest from a subfolder", {
  root <- versioned_study()
  withr::local_dir(study_dir("datasets", root))
  expect_identical(verify_manifest()$status, "OK")
})

test_that("a legacy checksum mismatch names update_manifest()", {
  root <- make_legacy_registered_study(withr::local_tempdir())
  path <- file.path(study_dir("datasets", root), "built.csv")
  utils::write.csv(data.frame(id = 1:9), path, row.names = FALSE)
  expect_error(verify_manifest(file.path(root, "manifest.yaml")), "update_manifest()", fixed = TRUE)
})

test_that("study_status reports a rebuilt source as pending, not failed", {
  root <- versioned_study()
  utils::write.csv(data.frame(id = 1:4, DEAD = c(1L, 1L, 0L, 0L)), built_path(study_config(root)), row.names = FALSE)
  st <- study_status(root)
  row <- st[st$item == "manifest.yaml", ]
  expect_identical(row$status, "PENDING")
  expect_match(row$detail, "update_manifest()", fixed = TRUE)
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: the five new tests FAIL.

- [ ] **Step 3: Write the implementation**

In `R/manifest.R`, directly above the roxygen block of `verify_manifest()`, add:

```r
# Inside a study, the study's manifest; elsewhere, manifest.yaml here. A job run
# from a subfolder used to check a manifest.yaml in its own folder.
.default_manifest_path <- function() {
  cfg <- tryCatch(study_config(require_data = FALSE), error = function(e) NULL)
  if (is.null(cfg)) "manifest.yaml" else file.path(cfg$root, "manifest.yaml")
}

.verify_row <- function(file, status, message) {
  data.frame(file = file, status = status, message = message, row_count_checked = FALSE,
             stringsAsFactors = FALSE)
}

# One row per registered version (current first), plus a PENDING row when the
# source has been rebuilt since. A version is registered data, so a missing or
# edited one FAILs with the restore instruction; a rebuilt source is expected.
.verify_versioned_entry <- function(entry, resolve) {
  versions <- c(list(.history_record(entry)), if (is.list(entry$history)) entry$history else list())
  rows <- lapply(seq_along(versions), function(i) {
    v <- versions[[i]]
    label <- if (i == 1L) entry$file else paste0(entry$file, " (", v$extract_date, ")")
    target <- resolve(v$parquet)
    restore <- " It is registered data and cannot be rebuilt from its source; restore it from backup and tell the study's data manager."
    if (!file.exists(target)) return(.verify_row(label, "FAIL", paste0(v$parquet, " is missing.", restore)))
    if (!identical(digest::digest(target, algo = "sha256", file = TRUE), v$sha256)) {
      return(.verify_row(label, "FAIL", paste0(v$parquet, " does not match its recorded checksum.", restore)))
    }
    if (!is.null(v$schema_sha256)) {
      side <- resolve(.version_schema_name(v$parquet))
      if (!file.exists(side) || !identical(digest::digest(side, algo = "sha256", file = TRUE), v$schema_sha256)) {
        return(.verify_row(label, "FAIL", paste0(.version_schema_name(v$parquet),
                                                 " is missing or does not match its recorded checksum.", restore)))
      }
    }
    .verify_row(label, "OK", paste0("SHA-256 match (", v$parquet, ", n = ", v$n_rows, ")"))
  })
  if (.source_changed(resolve(entry$file), entry)) {
    rows[[length(rows) + 1L]] <- .verify_row(entry$file, "PENDING",
                                             trimws(conditionMessage(.source_changed_condition(entry))))
  }
  do.call(rbind, rows)
}
```

In `verify_manifest()`:

1. Change the signature's first argument from `manifest_path = "manifest.yaml"` to `manifest_path = .default_manifest_path()`.
2. As the first statement inside `results <- lapply(manifest$datasets, function(entry) {`, add:

   ```r
       if (.is_versioned(entry)) return(.verify_versioned_entry(entry, resolve_entry))
   ```

3. In the legacy SHA-256 mismatch row, change its `message` to:

   ```r
           message = paste0("SHA-256 mismatch\n  expected: ", entry$sha256,
                            "\n  actual:   ", sha256,
                            "\n  If this file was rebuilt on purpose, run hvtiRutilities::update_manifest() ",
                            "to register the new version."),
   ```

4. Replace the `@param manifest_path` roxygen text with:

   ```r
   #' @param manifest_path Character. Path to the manifest YAML file. Defaults to
   #'   the study's \code{manifest.yaml} when run inside a study (a
   #'   \code{_study.yml} here or above), and to \code{"manifest.yaml"} in the
   #'   working directory otherwise.
   ```

5. Add to its `@description`:

   ```r
   #' For a dataset registered with \code{\link{register_data}}, every registered
   #' version (the current dated parquet and each earlier one) is checked. A
   #' source file rebuilt since registration is reported with status
   #' \code{"PENDING"} and never stops: jobs keep reading the registered version
   #' until \code{\link{update_manifest}()} registers the new one.
   #'
   ```

In `R/study_status.R`, in `.status_manifest()`, replace from the line `drift <- rep[rep$status == "FAIL", , drop = FALSE]` to the end of the function with:

```r
  pending <- rep[rep$status == "PENDING", , drop = FALSE]
  rep <- rep[rep$status != "PENDING", , drop = FALSE]
  drift <- rep[rep$status == "FAIL", , drop = FALSE]

  if (nrow(drift)) {
    .status_row("manifest.yaml", "FAIL",
                paste0(nrow(drift), " of ", nrow(rep), " entries failed: ",
                       paste(drift$file, collapse = ", ")))
  } else {
    # Re-deriving a .sas7bdat row count needs
    # options(manifest.allow_heavy_rowcount = TRUE), so on a real study those
    # entries pass on their checksum alone. That is a check which did not run,
    # not a check which passed, and the audit says which.
    detail  <- paste0(nrow(rep), " dataset entr",
                      if (nrow(rep) == 1L) "y" else "ies",
                      " verified by checksum")
    skipped <- sum(!rep$row_count_checked)
    if (skipped) {
      detail <- paste0(detail, " (row count not re-derived for ",
                       skipped, ")")
    }
    if (nrow(pending)) {
      return(.status_row("manifest.yaml", "PENDING",
                         paste0(detail, "; rebuilt since registration: ", paste(pending$file, collapse = ", "),
                                ". Run hvtiRutilities::update_manifest() to register ",
                                if (nrow(pending) == 1L) "it." else "them.")))
    }
    .status_row("manifest.yaml", "OK", detail)
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "registered_versions|manifest|study_status")'`
Expected: PASS. If a `study_status` print or summary test fails on the new `"PENDING"` value, add `"PENDING"` wherever that code lists the known status values, beside `"UPDATE AVAILABLE"`.

- [ ] **Step 5: Commit**

```bash
git add R/manifest.R R/study_status.R tests/testthat/test-registered_versions.R
git commit -m "Verify every registered version, report a rebuilt source as pending"
```

---

### Task 5: `update_manifest()` with no arguments registers what changed

**Files:**
- Modify: `R/manifest.R` (`update_manifest()`: new trailing `dataset` argument and an early return)
- Modify: `R/registered_versions.R` (append `.next_version()`, `.update_study_manifest()`)
- Test: `tests/testthat/test-registered_versions.R` (append)

**Interfaces:**
- Consumes: Task 1 helpers; `study_config()`, `.study_dataset()`, `study_dir()`.
- Produces:
  - `update_manifest(dataset = NULL, extract_date = ...)` with `file` missing returns, invisibly, a data frame with columns `dataset`, `action` (`"registered"`, `"migrated"`, `"unchanged"` or `"skipped"`) and `detail`, and prints one line per dataset.
  - `.next_version(entry, source_path, extract_date)` returns `list(entry, written, action, detail)`.
  - Task 6 adds `.migrate_entry()` with the same return shape.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-registered_versions.R`:

```r
rebuild_source <- function(root, data = data.frame(id = 1:4, DEAD = c(1L, 1L, 0L, 0L)), when = "2026-10-07 12:00:00") {
  path <- built_path(study_config(root))
  utils::write.csv(data, path, row.names = FALSE)
  Sys.setFileTime(path, as.POSIXct(when, tz = "UTC"))
  path
}

test_that("update_manifest() outside a study says what it looked for", {
  withr::local_dir(withr::local_tempdir())
  expect_error(update_manifest(), "found none", fixed = TRUE)
  expect_error(update_manifest(), "update_manifest(\"path/to/file\")", fixed = TRUE)
})

test_that("update_manifest() with nothing changed writes nothing", {
  root <- versioned_study()
  before <- readLines(file.path(root, "manifest.yaml"))
  withr::local_dir(root)

  expect_message(out <- update_manifest(), "unchanged")
  expect_identical(out$action, "unchanged")
  expect_identical(readLines(file.path(root, "manifest.yaml")), before)
})

test_that("update_manifest() registers a rebuilt source and keeps the old version", {
  root <- versioned_study()
  rebuild_source(root)
  withr::local_dir(study_dir("datasets", root))

  expect_message(out <- update_manifest(), "previous version kept as built_20260915.parquet", fixed = TRUE)
  expect_identical(out$action, "registered")

  e <- manifest_entry_for(root)
  expect_identical(e$parquet, "built_20261007.parquet")
  expect_identical(e$history[[1L]]$parquet, "built_20260915.parquet")
  expect_true(file.exists(file.path(study_dir("datasets", root), "built_20260915.parquet")))
  expect_identical(verify_manifest()$status, c("OK", "OK"))
  expect_no_message(d <- read_built(study_config(root)))
  expect_identical(nrow(d), 4L)
})

test_that("a second update on the same date takes the next revision", {
  root <- versioned_study()
  withr::local_dir(root)
  rebuild_source(root)
  suppressMessages(update_manifest())
  rebuild_source(root, data.frame(id = 1:5, DEAD = c(1L, 1L, 0L, 0L, 0L)), when = "2026-10-07 15:00:00")
  suppressMessages(update_manifest())

  e <- manifest_entry_for(root)
  expect_identical(e$parquet, "built_20261007_r2.parquet")
  expect_identical(vapply(e$history, `[[`, "", "parquet"), c("built_20261007.parquet", "built_20260915.parquet"))
})

test_that("update_manifest() keeps fields registration recorded", {
  skip_if_not_installed("arrow")
  root <- file.path(withr::local_tempdir(), "study")
  suppressMessages(study_setup(root, "Source field", 42L))
  path <- file.path(study_dir("datasets", root), "built.csv")
  utils::write.csv(data.frame(id = 1:2), path, row.names = FALSE)
  suppressMessages(register_data(root, "built.csv", source = "Synthetic"))
  utils::write.csv(data.frame(id = 1:3), path, row.names = FALSE)
  withr::local_dir(root)
  suppressMessages(update_manifest())
  expect_identical(manifest_entry_for(root)$source, "Synthetic")
})

test_that("update_manifest() refuses a release-aware dataset by name", {
  fx <- make_release_aware_study(withr::local_tempdir())
  withr::local_dir(fx$root)
  expect_error(update_manifest(dataset = "study"), "review_data_update()", fixed = TRUE)
})

test_that("update_manifest(file, ...) keeps its single-file behaviour", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "x.csv")
  utils::write.csv(data.frame(a = 1:2), path, row.names = FALSE)
  m <- update_manifest(path, manifest_path = file.path(dir, "manifest.yaml"), extract_date = "2026-10-07")
  expect_identical(m$datasets[[1L]]$file, "x.csv")
  expect_identical(m$datasets[[1L]]$role, "source")
})
```

`write_release_fixture()` must return the study root as `fx$root`. If it does not, use `file.path(<the tempdir>, "study")` in that test instead.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: the new no-argument tests FAIL (`argument "file" is missing`); the single-file test PASSES.

- [ ] **Step 3: Write the implementation**

Append to `R/registered_versions.R`:

```r
# Register a rebuilt source as the next version; the current one moves to the
# head of history. Unchanged sources are left alone.
.next_version <- function(entry, source_path, extract_date) {
  if (!.source_changed(source_path, entry)) {
    return(list(entry = entry, written = character(), action = "unchanged",
                detail = paste0("unchanged since ", entry$extract_date, " (", entry$parquet, ")")))
  }
  dir <- dirname(source_path)
  history <- if (is.list(entry$history)) entry$history else list()
  taken <- c(entry$parquet, vapply(history, function(h) h$parquet, character(1)))
  date <- if (is.null(extract_date)) as.Date(file.info(source_path)$mtime) else extract_date
  version <- .write_version(source_path, dir, date, taken, caller = "update_manifest")
  list(
    entry = .versioned_entry(entry$file, version, extra = .entry_extra(entry),
                             history = c(list(.history_record(entry)), history)),
    written = file.path(dir, c(version$parquet, .version_schema_name(version$parquet))),
    action = "registered",
    detail = paste0("registered ", version$parquet, " (", version$n_rows, " rows, ", version$n_cols,
                    " columns); previous version kept as ", entry$parquet)
  )
}

.update_row <- function(dataset, action, detail) {
  data.frame(dataset = dataset, action = action, detail = detail, stringsAsFactors = FALSE)
}

# update_manifest() with no file: find the study from the working directory and
# register every dataset (or the one named) whose source has changed.
.update_study_manifest <- function(dataset = NULL, extract_date = NULL) {
  cfg <- tryCatch(study_config(require_data = FALSE), error = function(e) NULL)
  if (is.null(cfg)) {
    stop("update_manifest() with no file looks for a study (a _study.yml in this directory or above) ",
         "and found none. To record a single file, pass it: update_manifest(\"path/to/file\").",
         call. = FALSE)
  }
  .require_arrow("update_manifest")
  targets <- if (is.null(dataset)) {
    c(if (!is.null(cfg$built)) "study", names(cfg$additional_datasets))
  } else {
    .study_dataset(cfg, dataset)
    dataset
  }
  manifest_path <- file.path(cfg$root, "manifest.yaml")
  manifest <- yaml::read_yaml(manifest_path)
  written <- character()
  committed <- FALSE
  on.exit(if (!committed) unlink(written), add = TRUE)
  rows <- list()

  for (name in targets) {
    contract <- .study_dataset(cfg, name)
    if (!is.null(contract$release)) {
      if (!is.null(dataset)) {
        stop("update_manifest(): '", name, "' is a release-aware dataset. Review and adopt a published ",
             "release with review_data_update() and adopt_data_update().", call. = FALSE)
      }
      rows[[name]] <- .update_row(name, "skipped", "release-aware; use review_data_update() and adopt_data_update()")
      next
    }
    hit <- which(vapply(manifest$datasets, function(e) identical(e$file, contract$built), logical(1)))
    if (length(hit) != 1L) {
      stop("update_manifest(): ", contract$built, " has ", if (length(hit)) "more than one entry" else "no entry",
           " in manifest.yaml. Register it with register_data().", call. = FALSE)
    }
    entry <- manifest$datasets[[hit]]
    source_path <- file.path(study_dir("datasets", cfg$root), contract$built)
    if (!file.exists(source_path)) {
      rows[[name]] <- .update_row(name, "unchanged", paste0(contract$built, " is not on disk; jobs keep reading ",
                                                            if (.is_versioned(entry)) entry$parquet else contract$built))
      next
    }
    step <- if (.is_versioned(entry)) {
      .next_version(entry, source_path, extract_date)
    } else {
      .migrate_entry(entry, source_path, extract_date)
    }
    written <- c(written, step$written)
    manifest$datasets[[hit]] <- step$entry
    rows[[name]] <- .update_row(name, step$action, step$detail)
  }

  out <- do.call(rbind, unname(rows))
  if (any(out$action %in% c("registered", "migrated"))) {
    .atomic_write(manifest_path, function(tmp) yaml::write_yaml(manifest, tmp))
  }
  committed <- TRUE
  message(paste0(format(out$dataset), ": ", out$detail, collapse = "\n"))
  if (any(out$action %in% c("registered", "migrated"))) {
    message("Commit manifest.yaml so the record of which version is current travels with the study.")
  }
  invisible(out)
}
```

Until Task 6, add this stub at the end of the same file so a legacy entry fails clearly:

```r
.migrate_entry <- function(entry, source_path, extract_date) {
  stop("update_manifest(): ", entry$file, " was registered before 2026-10; migration arrives with Task 6.",
       call. = FALSE)
}
```

In `R/manifest.R`, change `update_manifest()`'s signature by appending `dataset = NULL` as its last argument, and make its first statement:

```r
  if (missing(file)) {
    return(.update_study_manifest(dataset = dataset,
                                  extract_date = if (missing(extract_date)) NULL else extract_date))
  }
```

Rewrite the head of `update_manifest()`'s roxygen block so the study case comes first. Replace the `@description` with:

```r
#' @description
#' \strong{In a study}, run with no arguments after rebuilding a registered
#' dataset: \code{update_manifest()}. It finds the study from the working
#' directory, converts every registered dataset whose source file has changed
#' to a new dated parquet (\code{<name>_YYYYMMDD.parquet}, or \code{_r2},
#' \code{_r3} for another version on the same date), keeps every earlier
#' version, records the change in \code{manifest.yaml}, and prints one line per
#' dataset. Jobs read the new version from then on. Unchanged datasets are left
#' alone. Name one with \code{dataset}. Release-aware datasets are skipped; use
#' \code{\link{review_data_update}} and \code{\link{adopt_data_update}}. Needs
#' the \pkg{arrow} package.
#'
#' \strong{A single file}: \code{update_manifest(file, ...)} records a SHA-256
#' checksum, row count, extract date and optional provenance fields for one
#' file in a \code{manifest.yaml}. If the manifest already contains an entry
#' for the named file it is updated in place; otherwise a new entry is
#' appended. The manifest is intended to be committed to version control while
#' the data files themselves are not.
```

Keep the existing paragraphs about row counting after it. Add:

```r
#' @param dataset Character(1) or \code{NULL}. With no \code{file}: the one
#'   registered dataset to update; \code{NULL} updates every one that changed.
#'   Ignored when \code{file} is given.
```

and, in `@param extract_date`, add: "With no \code{file}, the date of the new version; defaults to the source file's modification date."

Add a study example as the first example, inside the existing `\dontrun{}`:

```r
#' # --- In a study, after rebuilding built.sas7bdat --------------------
#' update_manifest()
#'
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "registered_versions|manifest")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/manifest.R R/registered_versions.R tests/testthat/test-registered_versions.R
git commit -m "Let update_manifest() with no arguments register every changed dataset"
```

---

### Task 6: Migrating a study registered before this change

**Files:**
- Modify: `R/registered_versions.R` (replace the `.migrate_entry()` stub; add `.recover_cached_version()`)
- Test: `tests/testthat/test-registered_versions.R` (append)

**Interfaces:**
- Consumes: `.derived_paths()`, `.write_version()`, `.version_filename()`, `.versioned_entry()`, `.entry_extra()`.
- Produces: `.migrate_entry(entry, source_path, extract_date)` returns `list(entry, written, action = "migrated", detail)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-registered_versions.R`:

```r
# A legacy study whose read cache has been populated, as any study that ran a job has.
legacy_with_cache <- function(env = parent.frame()) {
  skip_if_not_installed("arrow")
  root <- make_legacy_registered_study(withr::local_tempdir(.local_envir = env))
  read_built(study_config(root))
  root
}

test_that("migration converts an untouched source and drops the old cache", {
  root <- legacy_with_cache()
  withr::local_dir(root)

  expect_message(out <- update_manifest(), "migrated|registered")
  expect_identical(out$action, "migrated")
  e <- manifest_entry_for(root)
  expect_identical(e$parquet, "built_20260915.parquet")
  expect_null(e$history)
  expect_false(file.exists(file.path(study_dir("datasets", root), "built.parquet")))
})

test_that("migration after an overwrite recovers the old version from the cache", {
  root <- legacy_with_cache()
  rebuild_source(root, data.frame(id = 1:5, dead = c(1L, 0L, 0L, 0L, 1L), iv_dead = 1:5))
  withr::local_dir(root)

  expect_message(out <- update_manifest(), "recovered from the read cache", fixed = TRUE)
  e <- manifest_entry_for(root)
  expect_identical(e$parquet, "built_20261007.parquet")
  expect_identical(e$history[[1L]]$parquet, "built_20260915.parquet")
  expect_identical(e$history[[1L]]$recovered_from, "cache")
  expect_identical(verify_manifest()$status, c("OK", "OK"))
})

test_that("migration after an overwrite with no usable cache says the old version is gone", {
  skip_if_not_installed("arrow")
  root <- make_legacy_registered_study(withr::local_tempdir())
  rebuild_source(root, data.frame(id = 1:5, dead = c(1L, 0L, 0L, 0L, 1L), iv_dead = 1:5))
  withr::local_dir(root)

  expect_message(update_manifest(), "cannot be recovered", fixed = TRUE)
  e <- manifest_entry_for(root)
  expect_identical(e$parquet, "built_20261007.parquet")
  expect_null(e$history)
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: the three migration tests FAIL with the Task 5 stub's message.

- [ ] **Step 3: Write the implementation**

In `R/registered_versions.R`, replace the `.migrate_entry()` stub with:

```r
# The old read cache (<stem>.parquet and <stem>.schema.csv beside the source)
# still holds the version registered before the source was overwritten when
# its row count, column count and column record match the old entry. Rename it
# to a dated version rather than copy it: it is the only copy.
.recover_cached_version <- function(entry, source_path) {
  cache <- .derived_paths(source_path)
  usable <- file.exists(cache$parquet) && file.exists(cache$schema) && !is.null(entry$schema_sha256) &&
    identical(digest::digest(cache$schema, algo = "sha256", file = TRUE), entry$schema_sha256)
  if (!usable) return(NULL)
  d <- tryCatch(arrow::read_parquet(cache$parquet), error = function(e) NULL)
  if (is.null(d) || !identical(nrow(d), as.integer(entry$n_rows)) ||
        (!is.null(entry$n_cols) && !identical(ncol(d), as.integer(entry$n_cols)))) {
    return(NULL)
  }
  dir <- dirname(source_path)
  date <- if (is.null(entry$extract_date)) Sys.Date() else entry$extract_date
  name <- .version_filename(tools::file_path_sans_ext(entry$file), date, dir)
  parquet <- file.path(dir, name)
  schema <- file.path(dir, .version_schema_name(name))
  if (!file.rename(cache$parquet, parquet)) return(NULL)
  if (!file.rename(cache$schema, schema)) {
    file.rename(parquet, cache$parquet)
    return(NULL)
  }
  record <- list(parquet = name, sha256 = digest::digest(parquet, algo = "sha256", file = TRUE),
                 source_sha256 = entry$sha256, extract_date = format(as.Date(date), "%Y-%m-%d"),
                 n_rows = as.integer(nrow(d)), n_cols = as.integer(ncol(d)),
                 schema_sha256 = entry$schema_sha256, recovered_from = "cache")
  if (!is.null(entry$reader)) record$reader <- entry$reader
  record
}

# A study registered before 2026-10 has role "source" and no parquet. Its first
# update converts it. Three cases: the source still matches (convert it, as a
# fresh registration on its original date); it was overwritten and the cache
# still holds the old data (keep that as the earlier version); or neither (say
# the earlier version is gone, and register the new one anyway).
.migrate_entry <- function(entry, source_path, extract_date) {
  unchanged <- identical(entry$sha256, digest::digest(source_path, algo = "sha256", file = TRUE))
  history <- list()
  note <- NULL
  if (unchanged) {
    date <- if (is.null(entry$extract_date)) as.Date(file.info(source_path)$mtime) else entry$extract_date
  } else {
    old <- .recover_cached_version(entry, source_path)
    if (is.null(old)) {
      note <- paste0("the previous version cannot be recovered: ", entry$file,
                     " was overwritten and no matching cached copy exists")
    } else {
      history <- list(old)
      note <- paste0("previous version recovered from the read cache as ", old$parquet,
                     ", not from the original ", entry$file)
    }
    date <- if (is.null(extract_date)) as.Date(file.info(source_path)$mtime) else extract_date
  }
  taken <- vapply(history, function(h) h$parquet, character(1))
  version <- .write_version(source_path, dirname(source_path), date, taken, caller = "update_manifest")
  if (unchanged) unlink(unlist(.derived_paths(source_path)))
  list(
    entry = .versioned_entry(entry$file, version, extra = .entry_extra(entry), history = history),
    written = file.path(dirname(source_path), c(version$parquet, .version_schema_name(version$parquet))),
    action = "migrated",
    detail = paste0("registered ", version$parquet, " (", version$n_rows, " rows, ", version$n_cols, " columns)",
                    if (!is.null(note)) paste0("; ", note) else "")
  )
}
```

`.entry_extra()` drops the legacy cache stamps and `schema_sha256` with the other version fields, so they do not leak into the new entry.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "registered_versions")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/registered_versions.R tests/testthat/test-registered_versions.R
git commit -m "Migrate a study registered before dated versions on its first update"
```

---

### Task 7: Documentation and NEWS

**Files:**
- Modify: `vignettes/dataset-versioning.qmd`, `NEWS.md`
- Regenerate: `man/`

- [ ] **Step 1: Lead the vignette with the study workflow**

In `vignettes/dataset-versioning.qmd`, insert a new section directly after the "The Problem: Datasets Drift" section and before "## Setup":

````markdown
## In a Study: Rebuild, Then Update

Most of the time you do not call any of the functions below directly. A study
registers its dataset once, and from then on the cycle is two steps.

1. Rebuild `datasets/built.sas7bdat` as often as you need. Jobs are not
   affected: they read the registered version, a dated parquet such as
   `built_20260915.parquet`, and say in their data table that a newer file is
   waiting.
2. When the rebuild is right, register it:

   ```r
   hvtiRutilities::update_manifest()
   ```

   Run it from anywhere in the study. It converts the new file to
   `built_20261007.parquet`, keeps every earlier version, and prints what it
   did. Commit `manifest.yaml`.

Every registered version stays on disk, so a manuscript revision can be
reproduced from the version its paper used. The rest of this vignette explains
the checksums underneath, and how to record a file outside a study.
````

- [ ] **Step 2: Add the NEWS entry**

Under `# hvtiRutilities (unreleased)` in `NEWS.md` (add the heading at the top if absent):

```markdown
* **Registering a dataset converts it to a dated parquet, and
  `update_manifest()` with no arguments registers a rebuilt one.**
  `register_data()` now writes `<name>_YYYYMMDD.parquet` and its column record
  beside the source, and jobs read that parquet. The source file
  (`built.sas7bdat`) may be rebuilt freely: `read_built()` keeps reading the
  registered version and signals `hvtiRutilities_source_changed`, and
  `verify_manifest()` reports the dataset as `PENDING` rather than failing.
  Run `update_manifest()` from anywhere in the study to register the rebuild
  as a new version; earlier versions are kept and still verified. A study
  registered before this release is converted on its first
  `update_manifest()`; if its source was already overwritten, the previous
  version is recovered from the read cache where it still matches.
  `verify_manifest()` now defaults to the study's manifest when run inside a
  study, and a checksum mismatch names `update_manifest()`. Registration and
  update need the arrow package.
```

- [ ] **Step 3: Regenerate and read the help**

Run: `Rscript -e 'devtools::document()'`
Then: `Rscript -e 'tools::Rd2txt("man/update_manifest.Rd")' | head -40`
Expected: the "In a study" paragraph comes first, with no literal backticks or asterisks.

- [ ] **Step 4: Commit**

```bash
git add vignettes/dataset-versioning.qmd NEWS.md man
git commit -m "Document the rebuild-then-update cycle"
```

---

### Task 8: Phase A gates

- [ ] **Step 1:** `Rscript -e 'lintr::lint_package()'`. Expected: no lints.
- [ ] **Step 2:** `Rscript -e 'devtools::test()'`. Expected: `FAIL 0`. Compare `SKIP` with `main`; any rise must be an arrow skip.
- [ ] **Step 3:** `Rscript -e 'devtools::check(document = FALSE, manual = FALSE)'`. Expected: 0 errors, 0 warnings, 0 notes.
- [ ] **Step 4:** `Rscript -e 'roxygen2::roxygenise()' && git status --porcelain man NAMESPACE DESCRIPTION`. Expected: no output.
- [ ] **Step 5: End-to-end on a scratch study.** Create a study with `study_setup()`, write a synthetic `built.sas7bdat` with `haven::write_sas()`, `register_data()`, render one job, rewrite the SAS file, render again (the job runs and its data table says a newer file is waiting once Phase C lands), run `update_manifest()`, render again.
- [ ] **Step 6:** Push the branch and open the pull request, linking the design and this plan.

---

## Phase B: hvtiRdatabuild

### Task 9: An analysis set's parent is the registered version

Starts after Phase A merges and hvtiRutilities is bumped.

**Files:**
- Modify: `R/analysis_set.R` (`.built_state()`)
- Modify: `DESCRIPTION` (raise `hvtiRutilities (>= ...)`)
- Test: `tests/testthat/test-analysis_set.R` (append)
- Modify: `NEWS.md`

**Interfaces:**
- Consumes: the versioned manifest entry (`parquet`, `sha256`) written by Phase A.
- Produces: `.built_state(cfg)` returns `list(file, sha256, size, mtime)` describing the registered parquet when the entry is versioned, and the source as before otherwise.

- [ ] **Step 1: Write the failing test, and update the one it reverses**

`tests/testthat/helper-analysis-set.R` defines `local_study(sets)` (a study with `built.csv` registered through `register_data()`, so a versioned entry once Phase A ships) and `eda_set()`. Append to `tests/testthat/test-analysis_set.R`:

```r
test_that("rebuilding the source without registering it does not make a set stale", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("hvtiPlotR")
  cfg <- local_study(list(eda = eda_set()))
  write_analysis_set("eda", cfg)
  cat("21,70,5,0,3,1\n", file = hvtiRutilities::built_path(cfg), append = TRUE)  # a rebuild nobody registered

  expect_no_error(read_analysis_set("eda", cfg))
  expect_match(.built_state(cfg)$file, "[.]parquet$")
})
```

The existing test "a rewritten built dataset makes the set stale" appends the same line and expects a stop; under this change that is exactly the case that no longer stops. Change it to register the rebuild first, which is what now makes a set stale:

```r
test_that("a newly registered built dataset makes the set stale", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("hvtiPlotR")
  cfg <- local_study(list(eda = eda_set()))
  write_analysis_set("eda", cfg)
  cat("21,70,5,0,3,1\n", file = hvtiRutilities::built_path(cfg), append = TRUE)
  withr::with_dir(cfg$root, suppressMessages(hvtiRutilities::update_manifest()))
  expect_error(read_analysis_set("eda", hvtiRutilities::study_config(cfg$root)), "built dataset has changed")
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "analysis_set")'`
Expected: FAIL, "the built dataset has changed since the set was written".

- [ ] **Step 3: Write the implementation**

Replace `.built_state()` in `R/analysis_set.R` with:

```r
# The built dataset's identity: its sha256 as the manifest records it, plus a
# stat. For a dataset registered as a dated parquet (hvtiRutilities 2026-10),
# the identity is that registered version, so rebuilding the source without
# registering it does not make a set stale; jobs read nothing new. Otherwise it
# is the source, whose stat catches a rewrite no read_built() call has recorded.
.built_state <- function(cfg) {
  m <- yaml::read_yaml(file.path(cfg$root, "manifest.yaml"))
  e <- Filter(function(x) identical(x$file, cfg$built), m$datasets)
  if (!length(e) || is.null(e[[1L]]$sha256))
    stop("manifest.yaml has no sha256 for ", cfg$built, ". Run ",
         "hvtiRutilities::register_data() or read_built() first.",
         call. = FALSE)
  e <- e[[1L]]
  versioned <- is.character(e$parquet) && length(e$parquet) == 1L && nzchar(e$parquet)
  p <- if (versioned) {
    file.path(hvtiRutilities::study_dir("datasets", cfg$root), e$parquet)
  } else {
    hvtiRutilities::built_path(cfg)
  }
  info <- file.info(p)
  list(file = if (versioned) e$parquet else cfg$built, sha256 = e$sha256,
       size = if (file.exists(p)) format(info$size, scientific = FALSE) else NA_character_,
       mtime = if (file.exists(p)) {
         format(info$mtime, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
       } else {
         NA_character_
       })
}
```

Raise `hvtiRutilities (>= ...)` in `DESCRIPTION` to the version that shipped Phase A.

Add under `# hvtiRdatabuild (unreleased)` in `NEWS.md`:

```markdown
* An analysis set's parent is now the registered version of the built dataset
  when hvtiRutilities registered it as a dated parquet. Rebuilding
  `built.sas7bdat` without registering it no longer makes every set stale,
  because jobs read nothing new until `hvtiRutilities::update_manifest()`
  registers it. Sets written before this change name the SAS file as their
  parent, so each is stale once after the study's first `update_manifest()`;
  `write_analysis_set()` refreshes it. Requires the hvtiRutilities release
  that added dated versions.
```

- [ ] **Step 4: Run tests and gates**

Run: `Rscript -e 'devtools::test()'`, then `lintr::lint_package()`, then `devtools::check(document = FALSE, manual = FALSE)`.
Expected: `FAIL 0`; no lints; 0 errors, 0 warnings, 0 notes.

- [ ] **Step 5: Commit, push, open the pull request**

```bash
git add R/analysis_set.R tests/testthat/test-analysis_set.R DESCRIPTION NEWS.md
git commit -m "Identify an analysis set's parent by its registered version"
```

---

## Phase C: hvtiRtemplates

### Task 10: The job's data table says when a newer file is waiting

Starts after Phase A merges and hvtiRutilities is bumped.

**Files:**
- Modify: `R/job-data.R` (`.read_job_source()`, `read_job_data()`, `.job_record()`)
- Modify: `DESCRIPTION` (raise `hvtiRutilities (>= ...)`)
- Test: `tests/testthat/test-job-data.R` (append)
- Modify: `NEWS.md`

**Interfaces:**
- Consumes: the `hvtiRutilities_out_of_date` condition class; `hvtiRutilities::provenance_data()` already records the parquet.
- Produces: `.read_job_source()` returns `notes`, a character vector; `.job_record(source, rows_read, who, dropped, steps, counts, notes = character())` adds one "Note" row per note; the Source row names the registered version.

- [ ] **Step 1: Write the failing test**

Append to `tests/testthat/test-job-data.R`:

```r
test_that("a rebuilt but unregistered dataset is read, and the data table says so", {
  skip_if_not_installed("arrow")
  root <- file.path(withr::local_tempdir(), "study")
  suppressMessages(hvtiRutilities::study_setup(root, "Job data note", 42L))
  path <- file.path(hvtiRutilities::study_dir("datasets", root), "built.csv")
  utils::write.csv(data.frame(ccfid = 1:3, dead = c(1L, 0L, 0L)), path, row.names = FALSE)
  suppressMessages(hvtiRutilities::register_data(root, "built.csv"))
  utils::write.csv(data.frame(ccfid = 1:4, dead = c(1L, 0L, 0L, 1L)), path, row.names = FALSE)
  cfg <- hvtiRutilities::study_config(root)

  expect_no_message(out <- read_job_data(cfg))
  expect_identical(nrow(out$data), 3L)
  note <- out$record$value[out$record$step == "Note"]
  expect_length(note, 1L)
  expect_match(note, "update_manifest()", fixed = TRUE)
  expect_match(out$record$value[out$record$step == "Source"], "[.]parquet")
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "job-data")'`
Expected: FAIL (a message escapes and there is no Note row).

- [ ] **Step 3: Write the implementation**

In `R/job-data.R`, replace the `is.null(analysis_set)` branch of `.read_job_source()` with:

```r
  if (is.null(analysis_set)) {
    notes <- character()
    read <- withCallingHandlers(
      .provenance_read(dataset, cfg, function() hvtiRutilities::read_built(cfg = cfg, dataset = dataset)),
      hvtiRutilities_out_of_date = function(m) {
        notes <<- c(notes, trimws(conditionMessage(m)))
        invokeRestart("muffleMessage")
      }
    )
    read$source <- paste0("dataset `", dataset, "` (", basename(read$record$path), ")")
    read$notes <- unique(notes)
    return(read)
  }
```

`.provenance_read()` calls the reader once, so one message arrives per read. `read$record$path` is the authoritative file `provenance_data()` recorded, the dated parquet for a registered dataset. In the analysis-set branch, add `read$notes <- character()` before `read`.

Add `notes = character()` as the last argument of `.job_record()`, and directly before its final `data.frame(...)` line add:

```r
  for (note in notes) rows[[length(rows) + 1L]] <- c("Note", note)
```

In `read_job_data()`, change the `.job_record(...)` call to pass `notes = read$notes`.

Raise `hvtiRutilities (>= ...)` in `DESCRIPTION` to the version that shipped Phase A.

Add under `# hvtiRtemplates (unreleased)` in `NEWS.md`:

```markdown
* A job reading a dataset whose source file has been rebuilt but not yet
  registered now runs on the registered version and says so in its "The data
  this job read" table, with the `update_manifest()` call that registers the
  new file. The table's Source row names the registered version the job read.
  Requires the hvtiRutilities release that added dated versions.
```

- [ ] **Step 4: Run tests and gates**

Run: `Rscript -e 'devtools::test()'`, `lintr::lint_package()`, `devtools::check(document = FALSE, manual = FALSE)`.
Expected: `FAIL 0`; no lints; 0 errors, 0 warnings, 0 notes. Template tests that assert the Source row's text may need the dated-parquet name; apply Task 2, Step 6's rule 3.

- [ ] **Step 5: Commit, push, open the pull request**

```bash
git add R/job-data.R tests/testthat/test-job-data.R DESCRIPTION NEWS.md
git commit -m "Show a waiting rebuilt dataset in the job's data table"
```

---

## Self-review

- **Spec coverage.** Section 1's five problems: no named call (Task 5), silent skip without arrow (Tasks 1, 2, 5 stop with a hint), working-directory paths (Tasks 4, 5), unhelpful errors (Tasks 3, 4, 5), lost versions (Tasks 2, 5, 6). Section 3 registration: Task 2. Section 4: Task 5. Section 5 entry shape: Tasks 1, 2. Section 6 reading and verifying: Tasks 3, 4, 10. Section 7 migration: Task 6. Section 8 documentation: Tasks 2 to 5, 7. Section 11 tests: Tasks 1 to 6, 9, 10.
- **Placeholders.** One, deliberate: the hvtiRutilities minimum version in Tasks 9 and 10, named at the bump. (Task 9's fixture, a placeholder in the first draft, is `local_study()` from `helper-analysis-set.R`.)
- **Names.** `.is_versioned`, `.authoritative_path`, `.version_schema_name`, `.version_filename`, `.write_version`, `.versioned_entry`, `.history_record`, `.entry_extra`, `.source_changed`, `.source_changed_condition`, `.next_version`, `.migrate_entry`, `.update_study_manifest`, `.verify_versioned_entry`, `.default_manifest_path` are spelled the same in every task.
