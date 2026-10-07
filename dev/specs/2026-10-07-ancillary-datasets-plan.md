# Ancillary, subset and combined datasets: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A study records each dataset's kind and key at registration; a job can join one ancillary dataset (echoes, labs) to its cohort, one row per record or one per patient; and out-of-date combined datasets and analysis sets run with a note that gives the commands to update them, except a stale analysis set in a final render, which stops.

**Architecture:** Three phases. **Phase A (hvtiRutilities)** adds `kind`, `key` and `parents` to the dataset contract, validates them in `study_config()`, checks the key when data is registered, records a combined dataset's parent versions in its manifest entry, and signals `hvtiRutilities_parent_changed` when a parent has moved on. **Phase B (hvtiRdatabuild)** turns a stale analysis set from a stop into a note in a draft render, keeping the stop for a final render. **Phase C (hvtiRtemplates)** adds a pure join function, wires it into `read_job_data()`, and adds the join choices to every template's study choices.

**Tech Stack:** R (>= 4.4.0), testthat edition 3, roxygen2 (Rd markup in hvtiRutilities and hvtiRtemplates, markdown in hvtiRdatabuild), yaml, digest, arrow.

**Spec:** `hvtiR/dev/specs/2026-10-07-ancillary-datasets-design.md`. **Depends on** the design 2 plan, `2026-10-07-dated-parquet-manifest-plan.md`: Phase A here starts after design 2's Phase A is merged, and Phase C after design 2's Phase C. It uses design 2's `.is_versioned()`, `.authoritative_path()`, `.update_study_manifest()`, `.next_version()`, `.entry_extra()`, `.source_changed_condition()`, and the `notes` argument of hvtiRtemplates' `.job_record()`.

## Global Constraints

- Repositories and order: `ehrlinger/hvtiRutilities` (Phase A, Tasks 1 to 4), `ehrlinger/hvtiRdatabuild` (Phase B, Task 5), `ehrlinger/hvtiRtemplates` (Phase C, Tasks 6 to 9). One branch and pull request per phase. Never push to `main`.
- Phases B and C raise `hvtiRutilities (>= ...)` to the version that ships Phase A, named when hvtiRutilities is bumped after Phase A merges.
- Roxygen is Rd markup in hvtiRutilities and hvtiRtemplates; markdown in hvtiRdatabuild.
- Line length 135 (hvtiRutilities, hvtiRtemplates), 100 (hvtiRdatabuild). `lintr::lint_package()` clean.
- Kinds are exactly `"built"`, `"subset"`, `"ancillary"`, `"combined"`. The default dataset may only be `"built"` (or have no kind); a named dataset may not be `"built"`.
- Condition classes: `hvtiRutilities_out_of_date` (parent class, from design 2), `hvtiRutilities_parent_changed`, `hvtiRutilities_stale_analysis_set`. Every out-of-date message ends with the commands that bring the data up to date.
- "Final render" means `HVTI_TEMPLATE_STRICT` is set to anything other than unset, `0`, `false` or `no` (case-insensitive), the templates' own rule.
- No message, record or test names an identifier value. Counts only.
- The template study-choices lines added in Task 8 carry **no** `EDIT:` marker. Every template's edit guard counts `EDIT:` markers as unfinished work, and an optional choice must not make a finished job render as a draft.
- `NEWS.md` bullets under each package's `(unreleased)` heading. Do not touch `Version:`.
- Definition of done, per repository: `devtools::test()` passes; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` run, `man/` and `NAMESPACE` committed.
- The planning container had no R. Run every command on a machine with R, `devtools`, `arrow` and Quarto.

## Amendments to the design, made while planning

Recorded in the design file too.

1. **Parent versions live in the manifest, not `_study.yml`.** `_study.yml` lists a combined dataset's parent *names* (`parents: [study, echo]`). The versions it was built from are recorded in its manifest entry as `parent_versions:`, because `manifest.yaml` is the version record and `update_manifest()` writes only that file.
2. **The cohort's key still falls back to the patient identifier.** "No key anywhere stops" applies to the joined dataset: a join needs a key from registration or from `JOIN_KEY`. A job reading one dataset with no registered key and no `KEY` uses `ID`, as today.
3. **A separate `join_key` argument** overrides the joined dataset's key. `key` keeps meaning the cohort's key. A long join's result is keyed on the joined dataset's key; a reduced join's result on `ID`.
4. **The `bd` build step is deferred.** The `bd` template builds the *study dataset* from a master snapshot, so it never holds the registered study dataset to join to, and "combined from the study dataset and echo" does not fit it. A combined dataset is registered with `register_data(kind = "combined", parents = ...)` from whatever builds it. A build template for combined datasets is a later design.
5. **Templates get the join choices** (`JOIN`, `JOIN_VARS`, `REDUCE`, `JOIN_KEY`) in their study choices, with no `EDIT:` marker. This edits every template that reads data, as designs 3 to 5 do, so Task 8 lands after them or is rebased onto them.
6. **`study_status()` lists out-of-date combined datasets**, not analysis sets, which hvtiRdatabuild owns.

## File structure

**hvtiRutilities**

| file | change | responsibility |
|---|---|---|
| `R/dataset_shape.R` | create | kind, key and parents: validation, the registration key check, parent versions, staleness, the parent-changed condition |
| `R/study_config.R` | modify | validate kind, key, parents |
| `R/study_data.R` | modify | `.study_dataset()` returns kind, key, parents; `read_built()` signals parent changes |
| `R/register_data.R` | modify | `kind`, `key`, `parents` arguments |
| `R/registered_versions.R` | modify | `.write_version()` checks the key; `.update_study_manifest()` orders parents first, refreshes and reports parent versions |
| `R/data_updates.R` | modify | adoption refreshes a combined dataset's parent versions |
| `R/study_status.R` | modify | out-of-date rows |
| `tests/testthat/test-dataset_shape.R` | create | all of the above |
| `NEWS.md`, `man/` | modify | |

**hvtiRdatabuild:** `R/analysis_set.R`, `tests/testthat/test-analysis_set.R`, `DESCRIPTION`, `NEWS.md`, `man/read_analysis_set.Rd`.

**hvtiRtemplates**

| file | change | responsibility |
|---|---|---|
| `R/job-join.R` | create | `.join_ancillary()`, a pure function on data frames |
| `R/job-data.R` | modify | `read_job_data()` arguments, key resolution, the join, record rows, notes from analysis sets |
| `tests/testthat/test-job-join.R` | create | the join |
| `tests/testthat/test-job-data.R` | modify | wiring |
| `tests/testthat/test-template-data-routes.R` | modify | every template passes the join choices |
| `inst/templates/**/*.qmd` | modify | study choices and the `read_job_data()` call |
| `DESCRIPTION`, `NEWS.md`, `man/read_job_data.Rd` | modify | |

---

## Phase A: hvtiRutilities

### Task 1: Kind, key and parents in the contract

**Files:**
- Create: `R/dataset_shape.R`
- Modify: `R/study_config.R` (one call in `study_config()`), `R/study_data.R` (`.study_dataset()`)
- Test: `tests/testthat/test-dataset_shape.R` (create)

**Interfaces:**
- Produces:
  - `.study_kinds`, a character vector of the four kinds.
  - `.study_validate_shapes(raw, found)` stops on an invalid kind, key or parents and returns `raw`.
  - `.study_dataset(cfg, dataset)` also returns `kind`, `key` and `parents` (all `NULL` when absent; the default dataset's `kind` is `"built"`).

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-dataset_shape.R`:

```r
shape_study <- function(study_fields = list(), additional = NULL, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(root, "datasets"))
  raw <- c(list(study = "Shape", built = "built.csv"), study_fields)
  if (!is.null(additional)) raw$additional_datasets <- additional
  yaml::write_yaml(raw, file.path(root, "_study.yml"))
  root
}

test_that("kind, key and parents are returned with the dataset", {
  root <- shape_study(
    study_fields = list(key = "ccfid"),
    additional = list(
      echo = list(built = "echo.csv", kind = "ancillary", key = c("ccfid", "echo_date")),
      built_echo = list(built = "be.csv", kind = "combined", key = c("ccfid", "echo_date"),
                        parents = c("study", "echo"))
    )
  )
  cfg <- study_config(root)
  expect_identical(.study_dataset(cfg, "study")$kind, "built")
  expect_identical(.study_dataset(cfg, "study")$key, "ccfid")
  expect_identical(.study_dataset(cfg, "echo")$key, c("ccfid", "echo_date"))
  expect_identical(.study_dataset(cfg, "built_echo")$parents, c("study", "echo"))
})

test_that("an invalid kind, key or parents stops with the dataset named", {
  bad <- function(contract) {
    root <- shape_study(additional = list(echo = c(list(built = "echo.csv"), contract)))
    expect_error(study_config(root), "'echo'")
  }
  bad(list(kind = "lab"))
  bad(list(kind = "built"))
  bad(list(key = list()))
  bad(list(key = c("ccfid", "ccfid")))
  bad(list(kind = "combined"))
  bad(list(kind = "combined", parents = "nope"))
  bad(list(kind = "combined", parents = "echo"))
  bad(list(kind = "ancillary", parents = "study"))
  expect_error(study_config(shape_study(study_fields = list(kind = "subset"))), "'study'")
})

test_that("a contract without kind or key reads as before", {
  cfg <- study_config(shape_study(additional = list(extra = list(built = "x.csv"))))
  expect_null(.study_dataset(cfg, "extra")$kind)
  expect_null(.study_dataset(cfg, "extra")$key)
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "dataset_shape")'`
Expected: FAIL; `.study_dataset()` returns no `kind`, and invalid contracts are accepted.

- [ ] **Step 3: Write the implementation**

Create `R/dataset_shape.R`:

```r
# Dataset shape: what kind of dataset a contract names, which columns make its
# rows unique, and, for a combined dataset, which registered datasets it was
# built from. Design: hvtiR dev/specs/2026-10-07-ancillary-datasets-design.md.

.study_kinds <- c("built", "subset", "ancillary", "combined")

.study_validate_shape <- function(contract, found, name, known, default) {
  bad <- function(what) {
    stop("study_config(): ", found, " ", what, " for dataset '", name, "'.", call. = FALSE)
  }
  kind <- contract$kind
  key <- contract$key
  parents <- contract$parents
  if (!is.null(kind)) {
    if (!(is.character(kind) && length(kind) == 1L && kind %in% .study_kinds)) {
      bad(paste0("has an invalid kind; expected one of ", toString(.study_kinds)))
    }
    if (default && !identical(kind, "built")) bad(paste0("has kind '", kind, "'; the study dataset is kind built"))
    if (!default && identical(kind, "built")) bad("has kind built, which only the study dataset may have")
  }
  if (!is.null(key) &&
        !(is.character(key) && length(key) >= 1L && !anyNA(key) && all(nzchar(key)) && !anyDuplicated(key))) {
    bad("has an invalid key; expected one or more distinct column names")
  }
  if (identical(kind, "combined")) {
    valid <- is.character(parents) && length(parents) >= 1L && !anyNA(parents) && !anyDuplicated(parents) &&
      all(parents %in% known) && !name %in% parents
    if (!valid) bad("needs parents naming other registered datasets")
  } else if (!is.null(parents)) {
    bad("has parents but is not kind combined")
  }
  invisible(TRUE)
}

.study_validate_shapes <- function(raw, found) {
  known <- c(if (!is.null(raw$built)) "study", names(raw$additional_datasets))
  .study_validate_shape(raw[c("kind", "key", "parents")], found, "study", known, default = TRUE)
  for (name in names(raw$additional_datasets)) {
    .study_validate_shape(raw$additional_datasets[[name]], found, name, known, default = FALSE)
  }
  raw
}
```

In `R/study_config.R`, inside `study_config()`, directly after the `raw$additional_datasets <- .study_validate_additional(...)` call, add:

```r
  raw <- .study_validate_shapes(raw, found)
```

In `R/study_data.R`, replace `.study_dataset()`'s two `return`/`list(...)` blocks so both carry the shape:

```r
  if (identical(dataset, "study")) {
    return(list(
      dataset = dataset,
      built = cfg$built,
      population = cfg$population,
      release = cfg$release,
      kind = "built",
      key = cfg$key,
      parents = NULL
    ))
  }
```

and, at the end of the function:

```r
  list(
    dataset = dataset,
    built = out$built,
    population = out$population,
    release = out$release,
    kind = out$kind,
    key = out$key,
    parents = out$parents
  )
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "dataset_shape|study_config|study_data")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/dataset_shape.R R/study_config.R R/study_data.R tests/testthat/test-dataset_shape.R
git commit -m "Record and validate each dataset's kind, key and parents"
```

---

### Task 2: Registering kind, key and parents

**Files:**
- Modify: `R/register_data.R` (`register_data()`), `R/registered_versions.R` (`.write_version()`)
- Modify: `R/dataset_shape.R` (append)
- Test: `tests/testthat/test-dataset_shape.R` (append)

**Interfaces:**
- Consumes: Task 1; design 2's `.write_version()`, `.is_versioned()`.
- Produces:
  - `register_data(..., kind = NULL, key = NULL, parents = NULL)`.
  - `.check_registration_key(d, key, file, caller)` stops on a missing or repeating key, with counts.
  - `.write_version(..., key = NULL)` checks the key after reading and before writing.
  - `.dataset_version(cfg, name, manifest)` returns a parent's version id: its parquet name (versioned), its `release_id` (release-aware), else its `sha256`.
  - `.parent_versions(cfg, parents, manifest)` returns a named list.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-dataset_shape.R`:

```r
registered_shape_study <- function(env = parent.frame()) {
  skip_if_not_installed("arrow")
  root <- file.path(withr::local_tempdir(.local_envir = env), "study")
  suppressMessages(study_setup(root, "Shape registration", 42L))
  data_dir <- study_dir("datasets", root)
  utils::write.csv(data.frame(ccfid = 1:3, dead = c(1L, 0L, 0L)), file.path(data_dir, "built.csv"), row.names = FALSE)
  utils::write.csv(data.frame(ccfid = c(1L, 1L, 2L, 9L), echo_date = c(10, 20, 10, 10), ef = c(50, 55, 60, 40)),
                   file.path(data_dir, "echo.csv"), row.names = FALSE)
  suppressMessages(register_data(root, "built.csv", key = "ccfid"))
  suppressMessages(register_data(root, "echo.csv", dataset = "echo", role = "named",
                                 kind = "ancillary", key = c("ccfid", "echo_date")))
  root
}

test_that("registration records kind and key and checks the key", {
  root <- registered_shape_study()
  cfg <- study_config(root)
  expect_identical(cfg$key, "ccfid")
  expect_identical(cfg$additional_datasets$echo$kind, "ancillary")
  expect_identical(cfg$additional_datasets$echo$key, c("ccfid", "echo_date"))
})

test_that("a repeating or missing key stops before anything is written", {
  root <- registered_shape_study()
  data_dir <- study_dir("datasets", root)
  utils::write.csv(data.frame(ccfid = c(1L, 1L), lab = 1:2), file.path(data_dir, "labs.csv"), row.names = FALSE)
  before <- list.files(data_dir)

  expect_error(register_data(root, "labs.csv", dataset = "labs", role = "named", kind = "ancillary", key = "ccfid"),
               "1 row repeats")
  expect_error(register_data(root, "labs.csv", dataset = "labs", role = "named", kind = "ancillary", key = "lab_date"),
               "lab_date")
  expect_identical(list.files(data_dir), before)
})

test_that("a combined dataset records its parents' versions in the manifest", {
  root <- registered_shape_study()
  data_dir <- study_dir("datasets", root)
  utils::write.csv(data.frame(ccfid = c(1L, 1L, 2L), echo_date = c(10, 20, 10), dead = c(1L, 1L, 0L)),
                   file.path(data_dir, "be.csv"), row.names = FALSE)
  suppressMessages(register_data(root, "be.csv", dataset = "built_echo", role = "named", kind = "combined",
                                 key = c("ccfid", "echo_date"), parents = c("study", "echo")))

  expect_identical(study_config(root)$additional_datasets$built_echo$parents, c("study", "echo"))
  m <- yaml::read_yaml(file.path(root, "manifest.yaml"))
  e <- Filter(function(x) identical(x$file, "be.csv"), m$datasets)[[1L]]
  expect_match(e$parent_versions$study, "^built_[0-9]{8}[.]parquet$")
  expect_match(e$parent_versions$echo, "^echo_[0-9]{8}[.]parquet$")
})

test_that("register_data refuses parents without kind combined", {
  root <- registered_shape_study()
  utils::write.csv(data.frame(ccfid = 1:2), file.path(study_dir("datasets", root), "x.csv"), row.names = FALSE)
  expect_error(register_data(root, "x.csv", dataset = "x", role = "named", parents = "study"), "combined")
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "dataset_shape")'`
Expected: FAIL, `unused argument (key = "ccfid")`.

- [ ] **Step 3: Write the implementation**

Append to `R/dataset_shape.R`:

```r
# Names are matched ignoring case, because read_built() lowercases them.
.check_registration_key <- function(d, key, file, caller) {
  if (is.null(key)) return(invisible(TRUE))
  hit <- match(tolower(key), tolower(names(d)))
  if (anyNA(hit)) {
    stop(caller, "(): key names a column ", file, " does not have: ", toString(key[is.na(hit)]),
         ". Nothing was written.", call. = FALSE)
  }
  repeats <- sum(duplicated(d[names(d)[hit]]))
  if (repeats) {
    stop(caller, "(): ", repeats, if (repeats == 1L) " row repeats" else " rows repeat",
         " a value of the key (", toString(key), ") in ", file,
         ". Each row must be unique on the key; add a column to it, such as a date. Nothing was written.",
         call. = FALSE)
  }
  invisible(TRUE)
}

# A registered dataset's version: its dated parquet (design 2), its pinned
# release, or, for an unconverted registration, its checksum.
.dataset_version <- function(cfg, name, manifest) {
  contract <- .study_dataset(cfg, name)
  if (!is.null(contract$release)) return(contract$release$release_id)
  hit <- Filter(function(e) identical(e$file, contract$built), manifest$datasets)
  if (!length(hit)) return(NA_character_)
  if (.is_versioned(hit[[1L]])) hit[[1L]]$parquet else hit[[1L]]$sha256
}

.parent_versions <- function(cfg, parents, manifest) {
  stats::setNames(lapply(parents, function(p) .dataset_version(cfg, p, manifest)), parents)
}
```

In `R/registered_versions.R`, give `.write_version()` a trailing `key = NULL` argument and, directly after the `.assert_no_lowercase_collision(d, source)` line, add:

```r
  .check_registration_key(d, key, basename(source), caller)
```

So that `update_manifest()` re-checks the key on every new version, give `.next_version()` and `.migrate_entry()` a trailing `key = NULL` argument, pass it to their `.write_version(...)` calls as `key = key`, and in `.update_study_manifest()` change the `step <- if (.is_versioned(entry)) ...` block to pass `key = contract$key` to both.

In `R/register_data.R`:

1. Append `kind = NULL, key = NULL, parents = NULL` to `register_data()`'s arguments.
2. After the existing validation of `dataset` and `role`, add:

   ```r
  if (!is.null(parents) && !identical(kind, "combined")) {
    stop("register_data(): parents are recorded only for kind = \"combined\".", call. = FALSE)
  }
   ```

3. Pass the key to the conversion: in the design 2 code, change `.write_version(path, dirname(path), extract_date)` to `.write_version(path, dirname(path), extract_date, key = key)`. In the release branch, after `data <- .read_registration_data(path)` runs, add `.check_registration_key(data, key, built, "register_data")`.
4. Where the role `"study"` branch sets `raw$built`, add `if (!is.null(key)) raw$key <- key`. Where the role `"named"` branch builds `contract`, add:

   ```r
    if (!is.null(kind)) contract$kind <- kind
    if (!is.null(key)) contract$key <- key
    if (!is.null(parents)) contract$parents <- parents
   ```

5. Validate the prepared contract before writing: after `raw` is complete and before `yaml::write_yaml(raw, prepared[[1L]])`, add:

   ```r
  .study_validate_shapes(raw, cfg$file)
   ```

6. Record parent versions: directly after the entry is built (after the `entry <- if (is.null(release)) ...` block), add:

   ```r
  if (!is.null(parents)) entry$parent_versions <- .parent_versions(cfg, parents, manifest_for_parents)
   ```

   where `manifest_for_parents` is read just before it: `manifest_for_parents <- if (file.exists(file.path(cfg$root, "manifest.yaml"))) yaml::read_yaml(file.path(cfg$root, "manifest.yaml")) else list()`.

Add to the roxygen block of `register_data()`:

```r
#' @param kind Character(1) or \code{NULL}. What the dataset is:
#'   \code{"built"} (the study dataset), \code{"subset"}, \code{"ancillary"}
#'   (many rows per patient, such as echoes or labs, joined to the cohort by a
#'   job) or \code{"combined"} (built by joining others).
#' @param key Character or \code{NULL}. The columns that make each row unique,
#'   such as \code{c("ccfid", "echo_date")}. Checked at registration, which
#'   stops if any row repeats on it. Jobs use it unless they set their own.
#' @param parents Character or \code{NULL}. For \code{kind = "combined"} only:
#'   the registered datasets it was built from. Their current versions are
#'   recorded, so a later update to a parent marks this dataset out of date.
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "dataset_shape|register_data|registered_versions")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/dataset_shape.R R/register_data.R R/registered_versions.R tests/testthat/test-dataset_shape.R man
git commit -m "Register a dataset's kind and key, check the key, record a combined dataset's parents"
```

---

### Task 3: An out-of-date combined dataset runs and says how to update it

**Files:**
- Modify: `R/dataset_shape.R` (append), `R/study_data.R` (`read_built()`), `R/registered_versions.R` (`.update_study_manifest()`), `R/data_updates.R` (`adopt_data_update()`), `R/study_status.R` (`study_status()`)
- Test: `tests/testthat/test-dataset_shape.R` (append)

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces:
  - `.stale_parents(cfg, name, entry, manifest)` returns a data frame (`parent`, `recorded`, `current`) with zero rows when current.
  - `.parent_changed_condition(contract, stale)` returns a condition of class `c("hvtiRutilities_parent_changed", "hvtiRutilities_out_of_date", "message", "condition")`.
  - `read_built()` signals it.
  - `update_manifest()` updates parents before combined datasets, refreshes `parent_versions` when it re-registers a combined dataset, and reports the rest.
  - `adopt_data_update()` refreshes `parent_versions` for a combined dataset.
  - `study_status()` adds an `out_of_date:<name>` row per stale combined dataset.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-dataset_shape.R`:

```r
combined_study <- function(env = parent.frame()) {
  root <- registered_shape_study(env)
  data_dir <- study_dir("datasets", root)
  utils::write.csv(data.frame(ccfid = c(1L, 1L, 2L), echo_date = c(10, 20, 10), dead = c(1L, 1L, 0L)),
                   file.path(data_dir, "be.csv"), row.names = FALSE)
  suppressMessages(register_data(root, "be.csv", dataset = "built_echo", role = "named", kind = "combined",
                                 key = c("ccfid", "echo_date"), parents = c("study", "echo")))
  root
}

rebuild <- function(root, file, data, when = "2026-10-08 12:00:00") {
  path <- file.path(study_dir("datasets", root), file)
  utils::write.csv(data, path, row.names = FALSE)
  Sys.setFileTime(path, as.POSIXct(when, tz = "UTC"))
}

test_that("a combined dataset reads current until a parent is updated", {
  root <- combined_study()
  cfg <- study_config(root)
  expect_no_message(read_built(cfg, dataset = "built_echo"))

  rebuild(root, "built.csv", data.frame(ccfid = 1:4, dead = c(1L, 0L, 0L, 1L)))
  withr::with_dir(root, suppressMessages(update_manifest(dataset = "study")))

  expect_message(d <- read_built(study_config(root), dataset = "built_echo"), class = "hvtiRutilities_parent_changed")
  expect_identical(nrow(d), 3L)
})

test_that("the parent-changed message names the parent versions and the update commands", {
  cond <- .parent_changed_condition(
    list(dataset = "built_echo", built = "be.csv"),
    data.frame(parent = "study", recorded = "built_20260915.parquet", current = "built_20261008.parquet")
  )
  expect_s3_class(cond, "hvtiRutilities_out_of_date")
  msg <- conditionMessage(cond)
  expect_match(msg, "built_20260915.parquet", fixed = TRUE)
  expect_match(msg, "built_20261008.parquet", fixed = TRUE)
  expect_match(msg, "update_manifest()", fixed = TRUE)
})

test_that("update_manifest() updates parents first and reports a combined dataset left behind", {
  root <- combined_study()
  rebuild(root, "built.csv", data.frame(ccfid = 1:4, dead = c(1L, 0L, 0L, 1L)))
  withr::local_dir(root)

  expect_message(update_manifest(), "built_echo is out of date", fixed = TRUE)
})

test_that("re-registering a combined dataset records its parents' new versions", {
  root <- combined_study()
  rebuild(root, "built.csv", data.frame(ccfid = 1:4, dead = c(1L, 0L, 0L, 1L)))
  rebuild(root, "be.csv", data.frame(ccfid = c(1L, 2L), echo_date = c(10, 10), dead = c(1L, 0L)))
  withr::local_dir(root)
  suppressMessages(update_manifest())

  expect_no_message(read_built(study_config(root), dataset = "built_echo"))
})

test_that("study_status lists an out-of-date combined dataset", {
  root <- combined_study()
  rebuild(root, "built.csv", data.frame(ccfid = 1:4, dead = c(1L, 0L, 0L, 1L)))
  withr::with_dir(root, suppressMessages(update_manifest(dataset = "study")))

  checks <- study_status(root)$checks
  row <- checks[checks$item == "out_of_date:built_echo", ]
  expect_identical(row$status, "OUT OF DATE")
  expect_match(row$detail, "update_manifest()", fixed = TRUE)
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "dataset_shape")'`
Expected: the five new tests FAIL.

- [ ] **Step 3: Write the implementation**

Append to `R/dataset_shape.R`:

```r
.stale_parents <- function(cfg, name, entry, manifest) {
  contract <- .study_dataset(cfg, name)
  empty <- data.frame(parent = character(), recorded = character(), current = character())
  if (!identical(contract$kind, "combined") || is.null(entry$parent_versions)) return(empty)
  rows <- lapply(contract$parents, function(p) {
    recorded <- entry$parent_versions[[p]]
    current <- .dataset_version(cfg, p, manifest)
    if (identical(as.character(recorded), as.character(current))) return(NULL)
    data.frame(parent = p, recorded = as.character(recorded %||% "unrecorded"), current = as.character(current))
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) empty else do.call(rbind, rows)
}

.parent_changed_condition <- function(contract, stale) {
  was <- paste0(stale$parent, " was ", stale$recorded, " and is now ", stale$current, collapse = "; ")
  structure(
    class = c("hvtiRutilities_parent_changed", "hvtiRutilities_out_of_date", "message", "condition"),
    list(
      message = paste0(
        contract$dataset, " (", contract$built, ") was built from older versions of its parents: ", was,
        ". This job used the older combined data. To update it, rebuild ", contract$built,
        " with the job or script that writes it, then run hvtiRutilities::update_manifest().\n"
      ),
      call = NULL
    )
  )
}
```

In `R/study_data.R`, in `read_built()`, directly after the design 2 line `entry <- .manifest_entry(manifest_path, p)`, add:

```r
  if (identical(contract$kind, "combined")) {
    stale <- .stale_parents(cfg, dataset, entry, yaml::read_yaml(manifest_path))
    if (nrow(stale)) message(.parent_changed_condition(contract, stale))
  }
```

(`contract` is already assigned at the top of `read_built()`.)

In `R/registered_versions.R`, in `.update_study_manifest()`:

1. After `targets` is computed, order combined datasets last:

   ```r
  kinds <- vapply(targets, function(n) .study_dataset(cfg, n)$kind %||% "", character(1))
  targets <- c(targets[kinds != "combined"], targets[kinds == "combined"])
   ```

2. Inside the loop, directly after `manifest$datasets[[hit]] <- step$entry`, add:

   ```r
    if (identical(contract$kind, "combined") && identical(step$action, "registered")) {
      manifest$datasets[[hit]]$parent_versions <- .parent_versions(cfg, contract$parents, manifest)
    }
   ```

3. After the loop and before the manifest is written, collect combined datasets still behind:

   ```r
  behind <- character()
  for (name in names(cfg$additional_datasets)) {
    contract <- .study_dataset(cfg, name)
    if (!identical(contract$kind, "combined")) next
    hit <- which(vapply(manifest$datasets, function(e) identical(e$file, contract$built), logical(1)))
    if (length(hit) != 1L) next
    stale <- .stale_parents(cfg, name, manifest$datasets[[hit]], manifest)
    if (nrow(stale)) behind <- c(behind, trimws(conditionMessage(.parent_changed_condition(contract, stale))))
  }
   ```

   and after the existing summary `message(...)`, add:

   ```r
  for (b in behind) message(sub("^(\\S+) \\(", "\\1 is out of date (", b))
   ```

   so each line begins "`built_echo is out of date (be.csv) was built from ...`".

In `R/data_updates.R`, in `adopt_data_update()`, directly after `manifest$datasets[[which(old)]] <- entry`, add:

```r
  adopted <- .study_dataset(current_cfg, dataset)
  if (identical(adopted$kind, "combined")) {
    manifest$datasets[[which(old)]]$parent_versions <- .parent_versions(current_cfg, adopted$parents, manifest)
  }
```

In `R/study_status.R`, in `study_status()`, replace the `named_rows <- lapply(...)` block's inner `rbind(...)` with:

```r
    rbind(
      .status_named_dataset(cfg, dataset),
      .status_update(cfg, dataset),
      .status_out_of_date(cfg, dataset)
    )
```

and add above `study_status()`'s roxygen block:

```r
.status_out_of_date <- function(cfg, dataset) {
  contract <- tryCatch(.study_dataset(cfg, dataset), error = function(e) NULL)
  if (is.null(contract) || !identical(contract$kind, "combined")) return(NULL)
  manifest_path <- file.path(cfg$root, "manifest.yaml")
  if (!file.exists(manifest_path)) return(NULL)
  manifest <- yaml::read_yaml(manifest_path)
  entry <- Filter(function(e) identical(e$file, contract$built), manifest$datasets)
  if (!length(entry)) return(NULL)
  stale <- .stale_parents(cfg, dataset, entry[[1L]], manifest)
  if (!nrow(stale)) return(NULL)
  .status_row(paste0("out_of_date:", dataset), "OUT OF DATE",
              trimws(conditionMessage(.parent_changed_condition(contract, stale))))
}
```

If a `study_status` print test enumerates status values, add `"OUT OF DATE"` beside `"UPDATE AVAILABLE"`.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "dataset_shape|study_status|data_updates|registered_versions")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R tests/testthat/test-dataset_shape.R
git commit -m "Say when a combined dataset's parents have moved on, and how to update it"
```

---

### Task 4: Phase A documentation and gates

- [ ] **Step 1: NEWS.** Under `# hvtiRutilities (unreleased)`:

```markdown
* **Datasets have a kind and a key.** `register_data()` gains `kind`
  (`"built"`, `"subset"`, `"ancillary"` or `"combined"`), `key` (the columns
  that make each row unique, checked at registration) and `parents` (for a
  combined dataset). `study_config()` validates them. A combined dataset
  records the versions of the datasets it was built from; when one of them is
  updated, `read_built()` still reads it and signals
  `hvtiRutilities_parent_changed`, whose message gives the commands to update
  it, and `study_status()` and `update_manifest()` list it as out of date.
  `update_manifest()` updates parents before the datasets built from them.
```

- [ ] **Step 2:** `Rscript -e 'devtools::document()'`, then `lintr::lint_package()`, `devtools::test()`, `devtools::check(document = FALSE, manual = FALSE)`. Expected: no lints; `FAIL 0`; 0 errors, 0 warnings, 0 notes.
- [ ] **Step 3:** Commit (`git add NEWS.md man && git commit -m "Document dataset kinds, keys and parents"`), push, open the pull request linking the design and this plan.

---

## Phase B: hvtiRdatabuild

### Task 5: A stale analysis set reads with a note in a draft and stops in a final render

**Files:**
- Modify: `R/analysis_set.R` (`read_analysis_set()` and its roxygen), `DESCRIPTION`, `NEWS.md`
- Test: `tests/testthat/test-analysis_set.R`

**Interfaces:**
- Produces: in a draft render, `read_analysis_set()` returns the stale set and signals a condition of class `c("hvtiRutilities_stale_analysis_set", "hvtiRutilities_out_of_date", "message", "condition")`; in a final render it stops with the same text. A parquet that does not match its manifest entry stops in both.

- [ ] **Step 1: Rewrite the two stale-set tests and add the final-render tests**

In `tests/testthat/test-analysis_set.R`, replace the tests "a rewritten built dataset makes the set stale" and "an edited rule makes the set stale" with:

```r
stale_by_new_parent <- function(env = parent.frame()) {
  cfg <- local_study(list(eda = eda_set()), env = env)
  write_analysis_set("eda", cfg)
  f <- hvtiRutilities::built_path(cfg)
  cat("21,70,5,0,3,1\n", file = f, append = TRUE)
  withr::with_dir(cfg$root, suppressMessages(hvtiRutilities::update_manifest()))
  hvtiRutilities::study_config(cfg$root)
}

test_that("a set cut from an older parent reads in a draft, with the update commands", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("hvtiPlotR")
  withr::local_envvar(HVTI_TEMPLATE_STRICT = NA)
  cfg <- stale_by_new_parent()

  expect_message(d <- read_analysis_set("eda", cfg), class = "hvtiRutilities_stale_analysis_set")
  expect_s3_class(d, "data.frame")
  msg <- tryCatch(read_analysis_set("eda", cfg), message = conditionMessage)
  expect_match(msg, 'write_analysis_set("eda", hvtiRutilities::study_config())', fixed = TRUE)
  expect_match(msg, "This draft used the older cut", fixed = TRUE)
})

test_that("a set cut from an older parent stops a final render with the same commands", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("hvtiPlotR")
  withr::local_envvar(HVTI_TEMPLATE_STRICT = "1")
  cfg <- stale_by_new_parent()

  expect_error(read_analysis_set("eda", cfg), "A final render does not use a stale cut", fixed = TRUE)
  expect_error(read_analysis_set("eda", cfg), 'write_analysis_set("eda"', fixed = TRUE)
})

test_that("an edited rule makes the set stale in the same way", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("hvtiPlotR")
  withr::local_envvar(HVTI_TEMPLATE_STRICT = NA)
  cfg <- local_study(list(eda = eda_set()))
  write_analysis_set("eda", cfg)
  y <- yaml::read_yaml(cfg$file)
  y$analysis_sets$eda$exclude[[2]]$when <- "age < 21"
  yaml::write_yaml(y, cfg$file)
  expect_message(read_analysis_set("eda", cfg), "declaration .* has changed")
})

test_that("rebuilding the source without registering it does not make a set stale", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("hvtiPlotR")
  cfg <- local_study(list(eda = eda_set()))
  write_analysis_set("eda", cfg)
  cat("21,70,5,0,3,1\n", file = hvtiRutilities::built_path(cfg), append = TRUE)
  expect_no_message(read_analysis_set("eda", cfg))
})
```

The last test is the design 2 Phase B test; if design 2's Task 9 already added it, keep one copy. Leave "a corrupted parquet fails the integrity check" as it is: it must still stop.

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "analysis_set")'`
Expected: the draft and edited-rule tests FAIL (the read stops).

- [ ] **Step 3: Write the implementation**

In `R/analysis_set.R`, add above `read_analysis_set()`'s roxygen block:

```r
# The templates' rule for a final render: HVTI_TEMPLATE_STRICT unset, 0, false
# or no is a draft; anything else is final, so a mistyped value fails safe.
.final_render <- function() {
  !tolower(Sys.getenv("HVTI_TEMPLATE_STRICT")) %in% c("", "0", "false", "no")
}

# A stale set is never rebuilt silently. A draft may read the old cut, with a
# message that says what changed and gives the commands; a final render stops
# with the same text, because an accepted result is not built on exclusions
# decided against older data.
.stale_set <- function(name, why) {
  fix <- paste0('To update it, run write_analysis_set("', name, '", hvtiRutilities::study_config()), ',
                "review the attrition it prints, then render again.")
  if (.final_render()) {
    stop("analysis set `", name, "`: ", why, " ", fix, " A final render does not use a stale cut.", call. = FALSE)
  }
  message(structure(
    class = c("hvtiRutilities_stale_analysis_set", "hvtiRutilities_out_of_date", "message", "condition"),
    list(message = paste0("analysis set `", name, "`: ", why, " This draft used the older cut. ", fix, "\n"),
         call = NULL)
  ))
}
```

In `read_analysis_set()`, replace the two staleness `stop()` calls:

```r
    stop("analysis set `", name, "`: the built dataset has changed since the set ",
         "was written. ", fix, call. = FALSE)
```

with

```r
    .stale_set(name, paste0("it was cut from ", side$parent$file, "; the built dataset is now ", now$file, "."))
```

and

```r
    stop("analysis set `", name, "`: its declaration in _study.yml has changed ",
         "since the set was written. ", fix, call. = FALSE)
```

with

```r
    .stale_set(name, "its declaration in _study.yml has changed since the set was written.")
```

Both checks must still fall through to the integrity check and the read. The parquet-mismatch `stop()` is unchanged.

When the parent's file name is unchanged (a legacy study), `side$parent$file` and `now$file` are equal; the message still reads correctly ("cut from built.csv; the built dataset is now built.csv") but is unhelpful. Use:

```r
    why <- if (identical(side$parent$file, now$file)) {
      paste0("the built dataset (", now$file, ") has changed since the set was written.")
    } else {
      paste0("it was cut from ", side$parent$file, "; the built dataset is now ", now$file, ".")
    }
    .stale_set(name, why)
```

Rewrite the roxygen `@description` of `read_analysis_set()`:

```r
#' Reads the analysis set `name` written by [write_analysis_set()], after
#' checking that it is current. A set is stale when the built dataset has a
#' newer registered version than the one it was cut from, or when its
#' declaration in `_study.yml` has changed. A stale set is never rebuilt
#' silently: its exclusions are decisions, and a changed attrition should be
#' looked at. In a draft render it is read, with a message of class
#' `hvtiRutilities_stale_analysis_set` giving the [write_analysis_set()] call
#' that updates it. In a final render (`HVTI_TEMPLATE_STRICT` set, as
#' `hvtiRtemplates::render_job(final = TRUE)` sets it) it stops with the same
#' text. A parquet that no longer matches its manifest entry always stops.
```

Raise `hvtiRutilities (>= ...)` in `DESCRIPTION` to the Phase A version. Add to `NEWS.md` under `# hvtiRdatabuild (unreleased)`:

```markdown
* **A stale analysis set no longer stops a draft.** `read_analysis_set()`
  reads a set whose parent or declaration has changed, and signals
  `hvtiRutilities_stale_analysis_set` with the `write_analysis_set()` call that
  updates it. A final render (`HVTI_TEMPLATE_STRICT` set, as
  `render_job(final = TRUE)` does) still stops, with the same commands. This
  reverses the earlier rule that every stale read stopped; a damaged set still
  stops in every render.
```

- [ ] **Step 4: Run tests and gates**

Run: `Rscript -e 'devtools::document(); devtools::test()'`, `lintr::lint_package()`, `devtools::check(document = FALSE, manual = FALSE)`.
Expected: `FAIL 0`; no lints; 0 errors, 0 warnings, 0 notes.

- [ ] **Step 5: Commit, push, open the pull request**

```bash
git add R/analysis_set.R tests/testthat/test-analysis_set.R DESCRIPTION NEWS.md man
git commit -m "Read a stale analysis set in a draft with the update commands; stop a final render"
```

---

## Phase C: hvtiRtemplates

### Task 6: The join, as a pure function

**Files:**
- Create: `R/job-join.R`
- Test: `tests/testthat/test-job-join.R` (create)

**Interfaces:**
- Consumes: `.id_text()` (in `R/id-digest.R`), `.match_columns()` (in `R/job-data.R`).
- Produces: `.join_ancillary(cohort, ancillary, id, ancillary_id, join_key, join_vars = NULL, reduce = NULL)` returns `list(data, key, outside, without, ignored, rule)`:
  - `outside` counts joined records whose patient is not in the cohort.
  - `without` counts cohort patients with no joined record.
  - `ignored` counts records dropped by `reduce` for a missing `by` value (0 without `reduce`).
  - `rule` is a one-line description, or `NULL`.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-job-join.R`:

```r
# Synthetic: identifiers are 1 to 4, echo dates are day numbers. No patient's
# records tie on distance to dt_surg, so "nearest" has one answer.
cohort <- data.frame(ccfid = 1:3, age = c(50, 60, 70), dt_surg = c(100, 100, 100))
echo <- data.frame(
  ccfid = c(1L, 1L, 1L, 2L, 4L),
  echo_date = c(95, 110, 130, 95, 100),
  ef = c(50, 55, 60, 45, 40)
)
join <- function(...) hvtiRtemplates:::.join_ancillary(cohort, echo, "ccfid", "ccfid", c("ccfid", "echo_date"), ...)

test_that("the long form keeps one row per record, for cohort patients only", {
  out <- join()
  expect_identical(nrow(out$data), 4L)
  expect_setequal(names(out$data), c("ccfid", "echo_date", "ef", "age", "dt_surg"))
  expect_identical(out$key, c("ccfid", "echo_date"))
  expect_identical(out$outside, 1L)
  expect_identical(out$without, 1L)
  expect_null(out$rule)
})

test_that("join_vars limits the cohort columns carried", {
  out <- join(join_vars = "age")
  expect_setequal(names(out$data), c("ccfid", "echo_date", "ef", "age"))
})

test_that("first, last and nearest each keep one row per cohort patient", {
  first <- join(reduce = list(rule = "first", by = "echo_date"))
  expect_identical(nrow(first$data), 3L)
  expect_identical(first$key, "ccfid")
  expect_identical(first$data$ef[first$data$ccfid == 1L], 50)
  expect_true(is.na(first$data$ef[first$data$ccfid == 3L]))
  expect_identical(first$without, 1L)

  last <- join(reduce = list(rule = "last", by = "echo_date"))
  expect_identical(last$data$ef[last$data$ccfid == 1L], 60)

  near <- join(reduce = list(rule = "nearest", by = "echo_date", to = "dt_surg"))
  expect_identical(near$data$ef[near$data$ccfid == 1L], 50)
  expect_match(near$rule, "nearest")
})

test_that("a tie on the reduction column stops with a count", {
  tied <- rbind(echo, data.frame(ccfid = 1L, echo_date = 95, ef = 99))
  expect_error(hvtiRtemplates:::.join_ancillary(cohort, tied, "ccfid", "ccfid", c("ccfid", "echo_date", "ef"),
                                                reduce = list(rule = "first", by = "echo_date")),
               "1 patient has more than one record")
})

test_that("records with no value of `by` are ignored and counted", {
  gap <- rbind(echo, data.frame(ccfid = 2L, echo_date = NA, ef = 10))
  out <- hvtiRtemplates:::.join_ancillary(cohort, gap, "ccfid", "ccfid", c("ccfid", "ef"),
                                          reduce = list(rule = "first", by = "echo_date"))
  expect_identical(out$ignored, 1L)
})

test_that("a column in both datasets stops and names JOIN_VARS", {
  both <- cbind(echo, age = 1)
  expect_error(hvtiRtemplates:::.join_ancillary(cohort, both, "ccfid", "ccfid", c("ccfid", "echo_date")), "JOIN_VARS")
})

test_that("bad reduce settings stop with the setting named", {
  expect_error(join(reduce = list(rule = "mean", by = "echo_date")), "REDUCE")
  expect_error(join(reduce = list(rule = "nearest", by = "echo_date")), "to")
  expect_error(join(reduce = list(rule = "first", by = "nope")), "nope")
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "job-join")'`
Expected: FAIL, `.join_ancillary` not found.

- [ ] **Step 3: Write the implementation**

Create `R/job-join.R`:

```r
# Joining an ancillary dataset (echoes, labs) to a job's cohort. The cohort
# decides which patients are in; the ancillary dataset decides the rows, or, with
# `reduce`, one record is chosen per patient. Identifiers are compared as text,
# as everywhere in this package, and no value is ever printed: messages carry
# counts. Design: hvtiR dev/specs/2026-10-07-ancillary-datasets-design.md.

.reduce_rules <- c("first", "last", "nearest")

.join_ancillary <- function(cohort, ancillary, id, ancillary_id, join_key, join_vars = NULL, reduce = NULL) {
  cols <- if (is.null(join_vars)) names(cohort) else unique(c(id, .match_columns(join_vars, names(cohort))))
  absent <- setdiff(cols, names(cohort))
  if (length(absent)) {
    stop("JOIN_VARS names a column the cohort does not have: ", toString(absent),
         ". Change JOIN_VARS in edit-study-choices.", call. = FALSE)
  }
  clash <- intersect(setdiff(cols, id), setdiff(names(ancillary), ancillary_id))
  if (length(clash)) {
    stop("The cohort and the joined dataset both have: ", toString(clash),
         ". List only the cohort columns this job needs in JOIN_VARS.", call. = FALSE)
  }
  cohort_ids <- .id_text(cohort[[id]])
  anc_ids <- .id_text(ancillary[[ancillary_id]])
  inside <- anc_ids %in% cohort_ids
  outside <- sum(!inside)
  ancillary <- ancillary[inside, , drop = FALSE]
  anc_ids <- anc_ids[inside]
  if (!identical(ancillary_id, id)) names(ancillary)[names(ancillary) == ancillary_id] <- id

  if (is.null(reduce)) {
    carried <- cohort[match(anc_ids, cohort_ids), setdiff(cols, id), drop = FALSE]
    out <- cbind(ancillary, carried)
    rownames(out) <- NULL
    return(list(data = out, key = replace(join_key, join_key == ancillary_id, id), outside = outside,
                without = sum(!cohort_ids %in% anc_ids), ignored = 0L, rule = NULL))
  }

  rule <- reduce$rule
  by <- reduce$by
  to <- reduce$to
  if (!is.character(rule) || length(rule) != 1L || !rule %in% .reduce_rules) {
    stop("REDUCE needs rule = \"first\", \"last\" or \"nearest\". Change REDUCE in edit-study-choices.", call. = FALSE)
  }
  if (!is.character(by) || length(by) != 1L || !by %in% names(ancillary)) {
    stop("REDUCE's by names a column the joined dataset does not have: ", toString(by), ".", call. = FALSE)
  }
  orderable <- function(x) is.numeric(x) || inherits(x, c("Date", "POSIXt"))
  if (!orderable(ancillary[[by]])) {
    stop("REDUCE's by column, ", by, ", must be a number or a date.", call. = FALSE)
  }
  if (identical(rule, "nearest")) {
    if (!is.character(to) || length(to) != 1L || !to %in% names(cohort) || !orderable(cohort[[to]])) {
      stop("REDUCE with rule = \"nearest\" needs to = a cohort column holding a number or a date.", call. = FALSE)
    }
  } else if (!is.null(to)) {
    stop("REDUCE's to is used only with rule = \"nearest\".", call. = FALSE)
  }

  score <- as.numeric(ancillary[[by]])
  if (identical(rule, "nearest")) score <- abs(score - as.numeric(cohort[[to]][match(anc_ids, cohort_ids)]))
  if (identical(rule, "last")) score <- -score
  usable <- !is.na(score)
  ignored <- sum(!usable)
  ancillary <- ancillary[usable, , drop = FALSE]
  anc_ids <- anc_ids[usable]
  score <- score[usable]

  if (length(score)) {
    best <- stats::ave(score, anc_ids, FUN = min)
    at_best <- stats::ave(as.numeric(score == best), anc_ids, FUN = sum)
    ties <- length(unique(anc_ids[at_best > 1]))
    if (ties) {
      stop(ties, if (ties == 1L) " patient has" else " patients have", " more than one record at the same ", by,
           ". REDUCE cannot choose between them; choose another rule, or reduce the joined dataset when it is built.",
           call. = FALSE)
    }
  }
  chosen <- order(anc_ids, score, method = "radix")
  chosen <- chosen[!duplicated(anc_ids[chosen])]
  picked <- ancillary[chosen, setdiff(names(ancillary), id), drop = FALSE]
  m <- match(cohort_ids, anc_ids[chosen])
  out <- cbind(cohort[cols], picked[m, , drop = FALSE])
  rownames(out) <- NULL
  list(data = out, key = id, outside = outside, without = sum(is.na(m)), ignored = ignored,
       rule = paste0(rule, " by ", by, if (identical(rule, "nearest")) paste0(" to ", to) else ""))
}
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "job-join")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/job-join.R tests/testthat/test-job-join.R
git commit -m "Add the join of an ancillary dataset to a job's cohort"
```

---

### Task 7: `read_job_data()` joins, resolves keys, and reports

**Files:**
- Modify: `R/job-data.R` (`read_job_data()`, `.check_job_settings()`, `.read_job_source()`, `.job_record()`, `.upstream_fields`)
- Test: `tests/testthat/test-job-data.R` (append)

**Interfaces:**
- Consumes: `.join_ancillary()` (Task 6); design 2 Phase C's `notes` argument of `.job_record()` and the out-of-date handler in `.read_job_source()`.
- Produces:
  - `read_job_data(cfg, dataset = "study", analysis_set = NULL, where = NULL, id = "ccfid", key = NULL, join = NULL, join_vars = NULL, reduce = NULL, join_key = NULL)` returns the list it returns today plus `provenance_join` (`NULL` without a join).
  - `.job_record(..., notes = character(), join = NULL)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-job-data.R`. `job_study()` (line 74 of this file) builds a registered study from a data frame; this test registers a second dataset beside it:

```r
join_study <- function(env = parent.frame()) {
  skip_if_not_installed("arrow")
  root <- file.path(withr::local_tempdir(.local_envir = env), "study")
  suppressMessages(hvtiRutilities::study_setup(root, "Join", 42L))
  dd <- hvtiRutilities::study_dir("datasets", root)
  utils::write.csv(data.frame(ccfid = 1:3, age = c(50, 60, 70), dt_surg = 100), file.path(dd, "built.csv"),
                   row.names = FALSE)
  utils::write.csv(data.frame(ccfid = c(1L, 1L, 2L, 4L), echo_date = c(95, 120, 95, 100), ef = c(50, 55, 45, 40)),
                   file.path(dd, "echo.csv"), row.names = FALSE)
  suppressMessages(hvtiRutilities::register_data(root, "built.csv", key = "ccfid"))
  suppressMessages(hvtiRutilities::register_data(root, "echo.csv", dataset = "echo", role = "named",
                                                 kind = "ancillary", key = c("ccfid", "echo_date")))
  hvtiRutilities::study_config(root)
}

test_that("a job joins an ancillary dataset in long form and records the counts", {
  cfg <- join_study()
  out <- read_job_data(cfg, join = "echo")
  expect_identical(nrow(out$data), 3L)
  rec <- setNames(out$record$value, out$record$step)
  expect_match(rec[["Joined"]], "echo")
  expect_identical(rec[["Joined records outside the cohort"]], "1")
  expect_identical(rec[["Cohort patients with no joined record"]], "1")
  expect_false(is.null(out$provenance_join))
  expect_identical(attr(out$record, "selection")$key, c("ccfid", "echo_date"))
})

test_that("a job reduces to one row per patient", {
  cfg <- join_study()
  out <- read_job_data(cfg, join = "echo", reduce = list(rule = "nearest", by = "echo_date", to = "dt_surg"))
  expect_identical(nrow(out$data), 3L)
  expect_match(setNames(out$record$value, out$record$step)[["Reduced to one row per patient"]], "nearest")
})

test_that("an unregistered key with no JOIN_KEY stops with both fixes", {
  cfg <- join_study()
  y <- yaml::read_yaml(cfg$file)
  y$additional_datasets$echo$key <- NULL
  y$additional_datasets$echo$kind <- NULL
  yaml::write_yaml(y, cfg$file)
  cfg <- hvtiRutilities::study_config(cfg$root)
  expect_error(read_job_data(cfg, join = "echo"), "JOIN_KEY")
  expect_error(read_job_data(cfg, join = "echo"), "register_data")
  expect_identical(nrow(read_job_data(cfg, join = "echo", join_key = c("ccfid", "echo_date"))$data), 3L)
})

test_that("a job key that differs from the registered key is noted", {
  cfg <- join_study()
  out <- read_job_data(cfg, key = c("ccfid", "age"))
  expect_match(out$record$value[out$record$step == "Note"], "differs from the registered key")
})

test_that("JOIN refuses a dataset that is not ancillary", {
  cfg <- join_study()
  y <- yaml::read_yaml(cfg$file)
  y$additional_datasets$echo$kind <- "subset"
  yaml::write_yaml(y, cfg$file)
  expect_error(read_job_data(hvtiRutilities::study_config(cfg$root), join = "echo"), "ancillary")
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "job-data")'`
Expected: the new tests FAIL, `unused argument (join = "echo")`.

- [ ] **Step 3: Write the implementation**

In `R/job-data.R`:

1. Replace `read_job_data()` with:

```r
read_job_data <- function(cfg, dataset = "study", analysis_set = NULL, where = NULL,
                          id = "ccfid", key = NULL, join = NULL, join_vars = NULL, reduce = NULL,
                          join_key = NULL) {
  .check_job_settings(dataset, analysis_set, where, id, key, join, join_vars, reduce, join_key)
  read <- .read_job_source(cfg, dataset, analysis_set)
  d <- read$value
  # Taken now: subsetting the columns below drops attributes.
  attrition <- attr(d, "attrition", exact = TRUE)
  rows_read <- nrow(d)
  who <- .resolve_job_id(d, id)
  resolved <- .resolve_job_key(key, if (is.null(analysis_set)) .registered_shape(cfg, dataset)$key, who$id)
  key <- .match_columns(replace(resolved$key, resolved$key == id, who$id), names(d))
  ids <- .drop_identifiers(d, who$id)
  notes <- c(read$notes, resolved$note)
  joined <- NULL
  if (!is.null(join)) {
    joined <- .read_join(cfg, join, id, join_key, ids$data, who$id, join_vars, reduce)
    ids$data <- joined$data
    ids$dropped <- unique(c(ids$dropped, joined$dropped))
    key <- joined$key
    notes <- c(notes, joined$notes)
  }
  # MRN and eMRN are refused even when dropped: the condition would be saved.
  identifiers <- unique(c(who$id, names(d)[tolower(names(d)) %in% .job_identifier_names], .job_identifier_names))
  # Their values too, read from `d` before MRN and eMRN are dropped.
  id_values <- if (!is.null(where)) {
    lapply(d[intersect(identifiers, names(d))], function(x) unique(.id_text(x[!is.na(x)])))
  }
  kept <- .apply_where(ids$data, where, env = parent.frame(), cols = c(who$id, key), identifiers = identifiers,
                       id_values = if (is.null(id_values)) list() else id_values)
  counts <- .check_job_key(kept$data, key, who$id)
  record <- .job_record(read$source, rows_read, who, ids$dropped, kept$steps, counts, notes = unique(notes),
                        join = joined$summary)
  attr(record, "selection") <- list(
    dataset = dataset, analysis_set = analysis_set, where = kept$steps$condition,
    where_shown = kept$steps$shown,
    id = who$id, key = key, rows = counts$rows, patients = counts$patients,
    key_hash = .key_hash(kept$data, key),
    join = join, join_vars = join_vars, reduce = reduce
  )
  list(data = kept$data, record = record, provenance = read$record,
       provenance_join = if (!is.null(joined)) joined$provenance, attrition = attrition)
}
```

Keep `read_job_data()`'s roxygen block above it, with these changes: `@param key` becomes "Columns that make a row unique. \code{NULL} (the default) uses the key registered for \code{dataset}, and \code{id} when none is registered. A key that differs from the registered one is noted in the record."; and add:

```r
#' @param join Name of a registered ancillary dataset (such as echoes or labs)
#'   to join to the cohort on \code{id}, or \code{NULL}. Only patients in the
#'   cohort are kept.
#' @param join_vars Cohort columns each joined row carries; \code{NULL} carries
#'   all of them.
#' @param reduce \code{NULL} keeps one row per joined record, keyed on the
#'   joined dataset's key. \code{list(rule = "first", by = "echo_date")} keeps
#'   one row per cohort patient: the record with the smallest \code{by}
#'   (\code{"first"}), the largest (\code{"last"}), or the one nearest a cohort
#'   column (\code{rule = "nearest"} with \code{to = "dt_surg"}). A patient with
#'   no record keeps the row with the joined columns missing.
#' @param join_key Columns that make the joined dataset's rows unique,
#'   overriding its registered key. A join needs one or the other.
```

2. Add below `read_job_data()`:

```r
.registered_shape <- function(cfg, dataset) {
  if (dataset %in% c("study", "built")) return(list(kind = "built", key = cfg$key))
  contract <- cfg$additional_datasets[[dataset]]
  list(kind = contract$kind, key = contract$key)
}

.resolve_job_key <- function(key, registered, id) {
  if (is.null(key)) return(list(key = if (is.null(registered)) id else registered, note = NULL))
  note <- if (!is.null(registered) && !setequal(tolower(key), tolower(registered))) {
    paste0("This job's KEY (", toString(key), ") differs from the registered key (", toString(registered), ").")
  }
  list(key = key, note = note)
}

.read_join <- function(cfg, join, id, join_key, cohort, cohort_id, join_vars, reduce) {
  shape <- .registered_shape(cfg, join)
  if (!is.null(shape$kind) && !identical(shape$kind, "ancillary")) {
    stop("JOIN names `", join, "`, registered as a ", shape$kind, " dataset. JOIN takes an ancillary dataset.",
         call. = FALSE)
  }
  jkey <- if (is.null(join_key)) shape$key else join_key
  if (is.null(jkey)) {
    stop("`", join, "` has no registered key and this job sets no JOIN_KEY. Register it with key = ... in ",
         "hvtiRutilities::register_data(), or set JOIN_KEY in this job's study choices.", call. = FALSE)
  }
  jr <- .read_job_source(cfg, join, NULL)
  a <- jr$value
  a_who <- .resolve_job_id(a, id)
  jkey <- .match_columns(replace(jkey, jkey == id, a_who$id), names(a))
  absent <- setdiff(jkey, names(a))
  if (length(absent)) {
    stop("The key for `", join, "` names a column it does not have: ", toString(absent), ".", call. = FALSE)
  }
  repeats <- sum(duplicated(a[jkey]))
  if (repeats) {
    stop(repeats, if (repeats == 1L) " row" else " rows", " of `", join, "` repeat on its key (", toString(jkey),
         "). Set JOIN_KEY to columns that make each row unique.", call. = FALSE)
  }
  a_ids <- .drop_identifiers(a, a_who$id)
  j <- .join_ancillary(cohort, a_ids$data, cohort_id, a_who$id, jkey, join_vars, reduce)
  list(
    data = j$data, key = j$key, dropped = a_ids$dropped, notes = jr$notes, provenance = jr$record,
    summary = list(source = jr$source, outside = j$outside, without = j$without, ignored = j$ignored, rule = j$rule)
  )
}
```

3. In `.check_job_settings()`, give it the four new arguments, change the `key` check to allow `NULL`:

```r
  if (!is.null(key) && (!is.character(key) || !length(key) || anyNA(key) || !all(nzchar(key)))) {
    stop("KEY must be NULL or name one or more columns, such as ID or c(ID, \"iv_echo\").", call. = FALSE)
  }
```

and add before `invisible(TRUE)`:

```r
  if (!is.null(join) && (!is.character(join) || length(join) != 1L || is.na(join) || !nzchar(join))) {
    stop("JOIN must be NULL or name one registered ancillary dataset, such as \"echo\".", call. = FALSE)
  }
  if (!is.null(join) && identical(join, dataset)) {
    stop("JOIN names the dataset this job already reads, `", dataset, "`.", call. = FALSE)
  }
  if (is.null(join) && (!is.null(join_vars) || !is.null(reduce) || !is.null(join_key))) {
    stop("JOIN_VARS, REDUCE and JOIN_KEY apply only with JOIN. Set JOIN, or set them back to NULL.", call. = FALSE)
  }
  if (!is.null(join_vars) && (!is.character(join_vars) || !length(join_vars) || anyNA(join_vars))) {
    stop("JOIN_VARS must be NULL or name cohort columns.", call. = FALSE)
  }
  if (!is.null(reduce) && (!is.list(reduce) || is.null(reduce$rule) || is.null(reduce$by))) {
    stop("REDUCE must be NULL or list(rule = ..., by = ...).", call. = FALSE)
  }
  if (!is.null(join_key) && (!is.character(join_key) || !length(join_key) || anyNA(join_key))) {
    stop("JOIN_KEY must be NULL or name one or more columns.", call. = FALSE)
  }
```

and change `read_job_data()`'s call to pass them (already done in step 1).

4. In `.read_job_source()`, wrap the analysis-set branch's `.provenance_file_read(...)` call in the same `withCallingHandlers(..., hvtiRutilities_out_of_date = ...)` handler design 2 added to the dataset branch, collecting `notes`, and set `read$notes <- unique(notes)` there instead of `character()`.

5. In `.job_record()`, add a `join = NULL` argument after `notes` and, directly before the notes loop, add:

```r
  if (!is.null(join)) {
    rows[[length(rows) + 1L]] <- c("Joined", join$source)
    rows[[length(rows) + 1L]] <- c("Joined records outside the cohort", format(join$outside, big.mark = ","))
    rows[[length(rows) + 1L]] <- c("Cohort patients with no joined record", format(join$without, big.mark = ","))
    if (!is.null(join$rule)) rows[[length(rows) + 1L]] <- c("Reduced to one row per patient", join$rule)
    if (isTRUE(join$ignored > 0L)) {
      rows[[length(rows) + 1L]] <- c("Joined records with no reduction value", format(join$ignored, big.mark = ","))
    }
  }
```

6. Add the join settings to the fields a downstream job must agree on. Change `.upstream_fields` to:

```r
.upstream_fields <- c(dataset = "DATASET", analysis_set = "ANALYSIS_SET", where = "WHERE", id = "ID",
                      key = "KEY", time = "TIME", event = "EVENT", join = "JOIN", join_vars = "JOIN_VARS",
                      reduce = "REDUCE")
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "job-data|job-join|template-lineage")'`
Expected: PASS. If an existing test asserted the default `key = id` by calling `read_job_data()` without `key`, it still passes: with no registered key the default is `id`.

- [ ] **Step 5: Commit**

```bash
git add R/job-data.R tests/testthat/test-job-data.R
git commit -m "Join an ancillary dataset in read_job_data(), with registered keys and recorded counts"
```

---

### Task 8: Every template offers the join

Lands after designs 3 to 5 have edited the templates, or is rebased onto them.

**Files:**
- Modify: every `inst/templates/**/*.qmd` whose R chunks call `hvtiRtemplates::read_job_data(` (find them with `grep -rl "read_job_data(" inst/templates`)
- Test: `tests/testthat/test-template-data-routes.R` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/testthat/test-template-data-routes.R`:

```r
test_that("every template that reads data passes the join choices and records the joined data", {
  files <- list.files(system.file("templates", package = "hvtiRtemplates"), pattern = "[.]qmd$",
                      recursive = TRUE, full.names = TRUE)
  for (f in files) {
    src <- readLines(f, warn = FALSE)
    if (!any(grepl("read_job_data(", src, fixed = TRUE))) next
    text <- paste(src, collapse = "\n")
    for (arg in c("join = JOIN", "join_vars = JOIN_VARS", "reduce = REDUCE", "join_key = JOIN_KEY")) {
      expect_true(grepl(arg, text, fixed = TRUE), info = paste(basename(f), arg))
    }
    for (choice in c("^JOIN <- NULL$", "^JOIN_VARS <- NULL$", "^REDUCE <- NULL$", "^JOIN_KEY <- NULL$")) {
      expect_true(any(grepl(choice, src)), info = paste(basename(f), choice))
    }
    expect_true(grepl("job_data$provenance_join", text, fixed = TRUE), info = basename(f))
  }
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "template-data-routes")'`
Expected: FAIL for every template that reads data.

- [ ] **Step 3: Edit each template**

In each file found, make three edits.

(a) In the `edit-study-choices` chunk, directly after the line that sets `KEY`, add these lines exactly. They carry no `EDIT:` marker on purpose: the edit guard would otherwise render every finished job as a draft.

```r
# To join an ancillary dataset (echoes, labs) to this cohort, name it in JOIN.
# JOIN_VARS: the cohort columns each joined row carries (NULL carries all).
# REDUCE: NULL keeps a row per joined record; list(rule = "first", by = "echo_date")
# keeps one row per patient ("last", or "nearest" with to = a cohort date column).
# JOIN_KEY overrides the joined dataset's registered key.
JOIN <- NULL
JOIN_VARS <- NULL
REDUCE <- NULL
JOIN_KEY <- NULL
```

(b) In the call to `hvtiRtemplates::read_job_data(`, add `join = JOIN, join_vars = JOIN_VARS, reduce = REDUCE, join_key = JOIN_KEY` as the last arguments, wrapped to 135 characters.

(c) Replace the line

```r
.provenance_data <- c(if (exists(".provenance_data")) .provenance_data else list(), list(job_data$provenance))
```

with

```r
.provenance_data <- c(if (exists(".provenance_data")) .provenance_data else list(), list(job_data$provenance),
                      if (!is.null(job_data$provenance_join)) list(job_data$provenance_join))
```

A template whose `KEY` is set to something other than `ID` keeps it. One that reads `KEY` from an upstream job's selection is unaffected: `.check_upstream_selection()` now also carries `JOIN`, `JOIN_VARS` and `REDUCE`.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test()'`
Expected: `FAIL 0`. Template-render tests that run a whole job exercise the new lines with every choice `NULL`, the default path.

- [ ] **Step 5: Commit**

```bash
git add inst/templates tests/testthat/test-template-data-routes.R
git commit -m "Offer the ancillary join in every template's study choices"
```

---

### Task 9: Phase C documentation and gates

- [ ] **Step 1:** Raise `hvtiRutilities (>= ...)` in `DESCRIPTION` to the Phase A version, and `hvtiRdatabuild (>= ...)` in `Suggests` to the Phase B version.
- [ ] **Step 2: NEWS.** Under `# hvtiRtemplates (unreleased)`:

```markdown
* **Jobs can join an ancillary dataset to their cohort.** `read_job_data()`
  gains `join`, `join_vars`, `reduce` and `join_key`, and every template's
  study choices gain `JOIN`, `JOIN_VARS`, `REDUCE` and `JOIN_KEY`. A join keeps
  only cohort patients, one row per joined record, or one row per patient with
  `REDUCE = list(rule = "first" | "last" | "nearest", by = ...)`. The job's
  data table records the joined dataset and its counts, and its provenance
  records the joined dataset's version. `KEY` now defaults to the dataset's
  registered key; a different `KEY` is noted. A stale analysis set's message
  from hvtiRdatabuild is shown in the data table in a draft.
```

- [ ] **Step 3:** `Rscript -e 'devtools::document()'`, then `lintr::lint_package()`, `devtools::test()`, `devtools::check(document = FALSE, manual = FALSE)`. Expected: no lints; `FAIL 0`; 0 errors, 0 warnings, 0 notes.
- [ ] **Step 4: End to end.** In a scratch study, register `built.csv` with `key = "ccfid"` and `echo.csv` as ancillary; scaffold a `dc-general` job; set `JOIN <- "echo"`; render; confirm the data table's Joined rows. Set `REDUCE` to `nearest`; render again.
- [ ] **Step 5:** Commit, push, open the pull request linking the design and this plan.

---

## Self-review

- **Spec coverage.**
  - §3 registration (kind, key, parents, the key check, parent versions): Tasks 1 and 2.
  - §4 one note with the fix:
    - combined datasets: Task 3;
    - analysis sets: Task 5;
    - `study_status()` and `update_manifest()` listing: Task 3;
    - the shared class with design 2: Tasks 3 and 5.
  - §5 analysis sets, draft and final: Task 5.
  - §6 joining:
    - long and reduced forms: Task 6;
    - keys, provenance and `where` on the joined result: Task 7;
    - the template choices: Task 8.
  - §7 `bd`: deferred by amendment 4.
  - §8 out of scope: nothing built.
  - §9 tests: Tasks 1, 2, 3, 5, 6, 7 and 8.
- **Placeholders.** None left in code. The hvtiRutilities and hvtiRdatabuild minimum versions are named at their bumps, as in the design 2 plan.
- **Names.** These are spelled the same in every task:
  - in hvtiRutilities: `.study_validate_shapes`, `.check_registration_key`, `.dataset_version`, `.parent_versions`, `.stale_parents`, `.parent_changed_condition`, `.status_out_of_date`;
  - in hvtiRdatabuild: `.final_render`, `.stale_set`;
  - in hvtiRtemplates: `.join_ancillary`, `.registered_shape`, `.resolve_job_key`, `.read_join`;
  - the arguments `join`, `join_vars`, `reduce`, `join_key`;
  - the template choices `JOIN`, `JOIN_VARS`, `REDUCE`, `JOIN_KEY`.
