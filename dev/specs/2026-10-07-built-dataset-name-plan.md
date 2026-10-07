# `"built"` as a second name for the `"study"` dataset: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `"built"` and `"study"` name the same default dataset everywhere a dataset is named, and the job templates say `DATASET <- "built"`.

**Architecture:** One function, `.canonical_dataset()` in hvtiRutilities, turns `"built"` into `"study"`. Every exported function that takes a dataset name calls it first, so everything downstream (manifests, provenance, status, release adoption) keeps seeing the one canonical name `"study"`. `"built"` becomes reserved, like `"study"`, and a study that already registered an additional dataset called `built` is told how to rename it. hvtiRtemplates canonicalises in `read_job_data()` and in the upstream-selection check, so a job saying `"built"` and an upstream job that said `"study"` still agree; then every template's study choices switch to `"built"`.

**Tech Stack:** R (>= 4.4.0), testthat edition 3, roxygen2 with Rd markup in both packages.

**Spec:** `hvtiR/dev/specs/2026-10-07-built-dataset-name-design.md`.

## Global Constraints

- Two repositories, in order: `ehrlinger/hvtiRutilities` (Phase A, Tasks 1 and 2), then `ehrlinger/hvtiRtemplates` (Phase B, Tasks 3 to 5). One branch and pull request each. Never push to `main`.
- Phase B raises `hvtiRutilities (>= ...)` to the version that ships Phase A, named when hvtiRutilities is bumped after Phase A merges.
- The canonical name is `"study"`. Manifests, provenance records, status rows and `selection` attributes record `"study"`, never `"built"`, so records written before and after this change compare equal.
- `"built"` is reserved for the default dataset. A named dataset may not be called `"built"`.
- Rd markup in both packages. Line length 135. `lintr::lint_package()` clean.
- The template lines changed keep their `EDIT:` markers exactly where they are; only the dataset's name in them changes.
- `NEWS.md` bullets under `(unreleased)`. Do not touch `Version:`.
- Definition of done per repository: `devtools::test()` passes; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` run, `man/` and `NAMESPACE` committed.
- The planning container had no R. Run every command on a machine with R and Quarto.

## Order relative to the other designs

Independent of designs 1, 2 and 6 in Phase A. Phase B edits the same templates as designs 4, 5 and 6's Task 8, so it lands in the order the overview gives (3, then 4, then 5), and the later ones rebase onto it. Design 6's plan already treats `"built"` as the study dataset in hvtiRtemplates' `.registered_shape()`.

## Amendment to the design, made while planning

The design said 30 templates set `DATASET`. 26 do: 23 say `DATASET <- "study"` and three downstream jobs (`hm`, `hp`, `hs-setup`) say `DATASET <- NULL` and take the dataset from their upstream job. The three keep `NULL`. Recorded in the design file.

## File structure

**hvtiRutilities**

| file | change |
|---|---|
| `R/study_data.R` | add `.canonical_dataset()`; `.study_dataset()`, `built_path()`, `built_manifest()`, `read_built()` canonicalise; unknown-dataset message names both |
| `R/provenance.R` | `provenance_data()` canonicalises, so records say `"study"` |
| `R/register_data.R` | the default dataset may be registered as `"built"`; a named dataset may not be called `"built"` |
| `R/data_updates.R` | `check_data_updates()`, `review_data_update()`, `adopt_data_update()` canonicalise |
| `R/study_config.R` | an additional dataset named `built` stops with the rename message |
| `tests/testthat/test-built-name.R` | create |
| `NEWS.md`, `man/` | |

If design 2 has landed, `R/registered_versions.R`'s `.update_study_manifest()` also canonicalises its `dataset` argument (Task 1, Step 3, item 6).

**hvtiRtemplates**

| file | change |
|---|---|
| `R/job-data.R` | `read_job_data()` and `.check_upstream_selection()` canonicalise; the analysis-set check accepts both names |
| `inst/templates/**/*.qmd` | `DATASET <- "built"` and the prose around it, in 23 templates; `dp-postage` and `bd` prose |
| `tests/testthat/test-job-data.R`, `test-data-contract.R`, the `test-migrate-*.R` files | expectations |
| `DESCRIPTION`, `NEWS.md` | |

---

## Phase A: hvtiRutilities

### Task 1: `"built"` names the study dataset

**Files:**
- Modify: `R/study_data.R`, `R/provenance.R`, `R/register_data.R`, `R/data_updates.R`, `R/study_config.R`
- Test: `tests/testthat/test-built-name.R` (create)

**Interfaces:**
- Produces: `.canonical_dataset(dataset)` returns `"study"` for `"built"` and its argument otherwise. Every exported function taking `dataset` accepts `"built"`.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-built-name.R`:

```r
built_name_study <- function(env = parent.frame()) {
  skip_if_not_installed("arrow")  # registration converts to parquet once design 2 has landed
  root <- file.path(withr::local_tempdir(.local_envir = env), "study")
  suppressMessages(study_setup(root, "Built name", 42L))
  data_dir <- study_dir("datasets", root)
  utils::write.csv(data.frame(id = 1:3, dead = c(1L, 0L, 0L)), file.path(data_dir, "built.csv"), row.names = FALSE)
  suppressMessages(register_data(root, "built.csv"))
  root
}

test_that("\"built\" and \"study\" name the same dataset", {
  root <- built_name_study()
  cfg <- study_config(root)
  expect_identical(built_path(cfg, "built"), built_path(cfg, "study"))
  expect_identical(read_built(cfg, dataset = "built"), read_built(cfg, dataset = "study"))
  expect_identical(.study_dataset(cfg, "built")$dataset, "study")
})

test_that("provenance records the canonical name", {
  root <- built_name_study()
  expect_identical(provenance_data("built", cfg = study_config(root))$dataset, "study")
})

test_that("the default dataset may be registered under either name", {
  skip_if_not_installed("arrow")
  root <- file.path(withr::local_tempdir(), "study")
  suppressMessages(study_setup(root, "Register as built", 42L))
  utils::write.csv(data.frame(id = 1:2), file.path(study_dir("datasets", root), "b.csv"), row.names = FALSE)
  suppressMessages(register_data(root, "b.csv", dataset = "built"))
  expect_identical(study_config(root)$built, "b.csv")
})

test_that("a named dataset may not be called built", {
  root <- built_name_study()
  utils::write.csv(data.frame(id = 1:2), file.path(study_dir("datasets", root), "x.csv"), row.names = FALSE)
  expect_error(register_data(root, "x.csv", dataset = "built", role = "named"), "reserved")
})

test_that("an existing additional dataset named built stops with the way to rename it", {
  root <- built_name_study()
  y <- yaml::read_yaml(file.path(root, "_study.yml"))
  y$additional_datasets <- list(built = list(built = "x.csv"))
  yaml::write_yaml(y, file.path(root, "_study.yml"))
  expect_error(study_config(root), "Rename it under additional_datasets: and in manifest.yaml", fixed = TRUE)
})

test_that("an unknown dataset's message names both spellings", {
  root <- built_name_study()
  expect_error(built_path(study_config(root), "nope"), "study (or built)", fixed = TRUE)
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "built-name")'`
Expected: FAIL; `"built"` is an unknown dataset.

- [ ] **Step 3: Write the implementation**

1. In `R/study_data.R`, directly above `.study_dataset()`, add:

```r
# "built" is the team's word for the study dataset, and a second name for it.
# Everything recorded uses "study", so records made under either name compare
# equal. Design: hvtiR dev/specs/2026-10-07-built-dataset-name-design.md.
.canonical_dataset <- function(dataset) {
  if (is.character(dataset) && length(dataset) == 1L && identical(dataset, "built")) "study" else dataset
}
```

   In `.study_dataset()`, after its validation `stop()` (the "dataset must be one non-empty character name" check), add `dataset <- .canonical_dataset(dataset)`. Change the unknown-dataset branch's `choices` line to:

```r
    choices <- c("study (or built)", names(cfg$additional_datasets))
```

   As the first statement of `built_path()`, `built_manifest()` and `read_built()`, add `dataset <- .canonical_dataset(dataset)`. (`read_built()` validates `allow_withdrawn` first; put the line after that check.)

2. In `R/provenance.R`, as the first statement of `provenance_data()`, add `dataset <- .canonical_dataset(dataset)`.

3. In `R/data_updates.R`:
   - In `check_data_updates()`, change the `else` branch to `dataset <- .canonical_dataset(dataset); .study_dataset(cfg, dataset); dataset`, written as three lines.
   - As the first statement of `review_data_update()` and `adopt_data_update()`, add `dataset <- .canonical_dataset(dataset)`. The `identical(dataset, "study")` test in `adopt_data_update()` then holds for both names, unchanged.

4. In `R/register_data.R`, inside `register_data()`, directly after `dataset <- scalar(dataset, "dataset", required = TRUE)`, add:

```r
  if (identical(role, "named") && identical(dataset, "built")) {
    stop("register_data(): \"built\" is reserved: it is a second name for the study dataset. ",
         "Give the named dataset another name.", call. = FALSE)
  }
  dataset <- .canonical_dataset(dataset)
```

   The existing named-dataset name check (`identical(dataset, "study") || !grepl(...)`) is unchanged and still refuses `"study"`.

5. In `R/study_config.R`, in `.study_validate_additional()`, as the first statement inside `for (name in names(value)) {`, add:

```r
    if (identical(name, "built")) {
      stop("study_config(): ", found, " registers an additional dataset named 'built', which is now a second ",
           "name for the study dataset. Rename it under additional_datasets: and in manifest.yaml.",
           call. = FALSE)
    }
```

6. If design 2 has landed: in `R/registered_versions.R`, in `.update_study_manifest()`, as its first statement add `if (!is.null(dataset)) dataset <- .canonical_dataset(dataset)`.

7. Documentation. In each roxygen `@param dataset` that says the default is `"study"` (`built_path`, `built_manifest`, `read_built`, `provenance_data`, `review_data_update`, `adopt_data_update`, `register_data`, and `update_manifest` if design 2 has landed), append: `\code{"built"} is a second name for \code{"study"}.`

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "built-name|study_data|study_config|register_data|data_updates|provenance")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R tests/testthat/test-built-name.R
git commit -m "Accept \"built\" as a second name for the study dataset"
```

---

### Task 2: Phase A documentation and gates

- [ ] **Step 1: NEWS.** Under `# hvtiRutilities (unreleased)`:

```markdown
* `"built"` is now a second name for the study dataset. Every function that
  takes a `dataset` accepts it, and everything recorded (manifests,
  provenance, status) still says `"study"`, so records made under either name
  compare equal. `"built"` is reserved: a named dataset may not use it, and a
  study that already registered an additional dataset called `built` is asked
  to rename it.
```

- [ ] **Step 2:** `Rscript -e 'devtools::document()'`, `lintr::lint_package()`, `devtools::test()`, `devtools::check(document = FALSE, manual = FALSE)`. Expected: no lints; `FAIL 0`; 0 errors, 0 warnings, 0 notes.
- [ ] **Step 3:** Commit (`git add NEWS.md man && git commit -m "Document \"built\" as a dataset name"`), push, open the pull request.

---

## Phase B: hvtiRtemplates

### Task 3: The job data step accepts `"built"`

**Files:**
- Modify: `R/job-data.R` (`read_job_data()`, `.check_job_settings()`, `.check_upstream_selection()`)
- Test: `tests/testthat/test-job-data.R` (append)

**Interfaces:**
- Consumes: hvtiRutilities' acceptance of `"built"` (Phase A).
- Produces: `read_job_data(dataset = "built")` reads the study dataset and records `dataset = "study"` in its selection; an upstream selection saying `"study"` agrees with a setting of `"built"`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-job-data.R` (it already defines `job_study(data)`, line 74, which registers a study dataset):

```r
test_that("DATASET \"built\" reads the study dataset and records it as \"study\"", {
  cfg <- job_study(data.frame(ccfid = 1:3, age = c(50, 60, 70)))
  out <- read_job_data(cfg, dataset = "built")
  expect_identical(nrow(out$data), 3L)
  expect_identical(attr(out$record, "selection")$dataset, "study")
  expect_identical(out$provenance$dataset, "study")
})

test_that("an upstream job's \"study\" agrees with a downstream \"built\"", {
  up <- list(dataset = "study", analysis_set = NULL, id = "ccfid", rows = 3L, patients = 3L)
  expect_no_error(hvtiRtemplates:::.check_upstream_selection(up, list(dataset = "built")))
})

test_that("an analysis set may be read with DATASET \"built\"", {
  expect_no_error(hvtiRtemplates:::.check_job_settings("built", "eda", NULL, "ccfid", "ccfid"))
})
```

If design 6 has landed, `.check_job_settings()` takes four more arguments; call it as `.check_job_settings("built", "eda", NULL, "ccfid", "ccfid", NULL, NULL, NULL, NULL)`.

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "job-data")'`
Expected: the first test records `"built"`; the third stops with "An analysis set is written from the study dataset".

- [ ] **Step 3: Write the implementation**

In `R/job-data.R`:

1. Above `read_job_data()`'s roxygen block, add:

```r
# "built" is a second name for the study dataset (hvtiRutilities). The selection
# records "study", so an upstream job's record and a downstream setting agree
# whichever name each used.
.canonical_job_dataset <- function(dataset) {
  if (is.character(dataset) && length(dataset) == 1L && identical(dataset, "built")) "study" else dataset
}
```

2. In `read_job_data()`, directly after the `.check_job_settings(...)` call, add `dataset <- .canonical_job_dataset(dataset)`.

3. In `.check_job_settings()`, change `!identical(dataset, "study")` in the analysis-set check to `!dataset %in% c("study", "built")`, and the message's first sentence to "An analysis set is written from the study dataset (\"built\"), not `".

4. In `.check_upstream_selection()`, as its first statement add:

```r
  if (!is.null(settings$dataset)) settings$dataset <- .canonical_job_dataset(settings$dataset)
```

5. In `read_job_data()`'s roxygen, change `@param dataset` to: "Name of a dataset registered in \code{_study.yml}; \code{"built"} and \code{"study"} both name the study dataset."

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "job-data|template-lineage")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/job-data.R tests/testthat/test-job-data.R man
git commit -m "Let the job data step read DATASET \"built\""
```

---

### Task 4: Every template says `"built"`

**Files:**
- Modify: 23 templates under `inst/templates/` that contain `DATASET <- "study"`, plus `10_descriptive/dp-postage.qmd` and `00_datasets/bd.qmd` prose
- Modify: `tests/testthat/test-data-contract.R`, `tests/testthat/test-migrate-dc-gfup.R`, `test-migrate-dc-tables.R`, `test-migrate-dp-postage.R`, `test-migrate-dp-trends.R`

- [ ] **Step 1: Change the test that pins the defaults, and watch it fail**

In `tests/testthat/test-data-contract.R`, in `expected_defaults()`, change `DATASET = 'DATASET <- "study"'` to `DATASET = 'DATASET <- "built"'`.

Run: `Rscript -e 'devtools::test(filter = "data-contract")'`
Expected: FAIL for every template that reads data.

- [ ] **Step 2: Make the mechanical edits**

From the package root, run this script once. Each replacement is a fixed string, so it touches nothing else:

```r
files <- list.files("inst/templates", pattern = "[.]qmd$", recursive = TRUE, full.names = TRUE)
swaps <- c(
  'DATASET <- "study"' = 'DATASET <- "built"',
  '# EDIT: the registered dataset this job reads ("study" is the built dataset).' =
    '# EDIT: the registered dataset this job reads ("built" is the study dataset).',
  'and leave `DATASET` as "study", because a set is always cut from the' =
    'and leave `DATASET` as "built", because a set is always cut from the',
  '`DATASET <- "study"`' = '`DATASET <- "built"`'
)
for (f in files) {
  x <- readLines(f, warn = FALSE)
  y <- x
  for (from in names(swaps)) y <- gsub(from, swaps[[from]], y, fixed = TRUE)
  if (!identical(x, y)) writeLines(y, f)
}
```

The fourth swap runs after the first. In the prose that quotes the line in backticks, the first swap has already changed it, so the fourth matches nothing. That is harmless.

- [ ] **Step 3: Edit the two templates the script does not cover**

In `inst/templates/10_descriptive/dp-postage.qmd`, replace

```r
# EDIT: the built dataset this job reads. "study" is the file named by built:
# in _study.yml; any other name must be declared under additional_datasets:,
# such as a column subset written for R. Analysis sets are derived from
# "study" only, so another dataset needs ANALYSIS_SET <- NULL.
```

with

```r
# EDIT: the built dataset this job reads. "built" is the file named by built:
# in _study.yml; any other name must be declared under additional_datasets:,
# such as a column subset written for R. Analysis sets are derived from
# "built" only, so another dataset needs ANALYSIS_SET <- NULL.
```

and replace

```r
} else if (!identical(DATASET, "study")) {
```

with

```r
} else if (!DATASET %in% c("study", "built")) {
```

In `inst/templates/00_datasets/bd.qmd`, replace the prose `` `"study"` dataset, the one every analysis job reads. `` with `` `"built"` dataset (also called `"study"`), the one every analysis job reads. ``, and the comment `# makes it this study's "study" dataset, which every analysis job then reads.` with `# makes it this study's "built" dataset, which every analysis job then reads.` Leave `SUBJECT <- "study"` alone: it is the job's set name, not a dataset.

- [ ] **Step 4: Check that nothing was missed**

Run: `grep -rn '"study"' inst/templates --include=*.qmd`
Expected: only `bd.qmd`'s `SUBJECT <- "study"`, and the `dp-postage.qmd` line that now reads `!DATASET %in% c("study", "built")`.

- [ ] **Step 5: Update the migration tests**

`migrate_job()` copies a template, so a migrated job now says `DATASET <- "built"`. In each of these files, change only the expectations about the template's default:

- `tests/testthat/test-migrate-dc-gfup.R`: line 30, `'DATASET <- "study"'` → `'DATASET <- "built"'`; line 223, `expect_identical(env$DATASET, "study")` → `"built"`.
- `tests/testthat/test-migrate-dc-tables.R`: line 62, `'DATASET <- "study"'` → `'DATASET <- "built"'`.
- `tests/testthat/test-migrate-dp-postage.R`: lines 37 and 347, `"study"` → `"built"`. Leave lines 335 and 527, which *set* `DATASET` in a test environment; `"study"` is still accepted there.
- `tests/testthat/test-migrate-dp-trends.R`: lines 44 and 74, `"study"` → `"built"`.

Line numbers are as of `cf77df6`. If they have moved, find each `DATASET` expectation with `grep -n 'DATASET' <file>`.

- [ ] **Step 6: Run the tests**

Run: `Rscript -e 'devtools::test()'`
Expected: `FAIL 0`. Template-render tests now render with `DATASET <- "built"`, which exercises Task 3 end to end.

- [ ] **Step 7: Commit**

```bash
git add inst/templates tests/testthat
git commit -m "Name the study dataset \"built\" in every template"
```

---

### Task 5: Phase B documentation and gates

- [ ] **Step 1:** Raise `hvtiRutilities (>= ...)` in `DESCRIPTION` to the Phase A version.
- [ ] **Step 2: NEWS.** Under `# hvtiRtemplates (unreleased)`:

```markdown
* Templates now name the study dataset `"built"`, the team's word for it:
  `DATASET <- "built"`. `"study"` still works, so jobs scaffolded before this
  release keep running, and a downstream job agrees with an upstream one
  whichever name each used. Requires the hvtiRutilities release that made
  `"built"` a second name for the study dataset.
```

- [ ] **Step 3:** `Rscript -e 'devtools::document()'`, `lintr::lint_package()`, `devtools::test()`, `devtools::check(document = FALSE, manual = FALSE)`. Expected: no lints; `FAIL 0`; 0 errors, 0 warnings, 0 notes.
- [ ] **Step 4: End to end.** In a scratch study, scaffold an `ac` and an `hz` job with `add_job()`, render `ac`, change nothing in `hz` but confirm it says `DATASET <- "built"`, render `hz`, and confirm the upstream check passes and both provenance sidecars record `"dataset": "study"`.
- [ ] **Step 5:** Commit, push, open the pull request linking the design and this plan.

---

## Self-review

- **Spec coverage.**
  - Section 3 (hvtiRutilities):
    - resolver and other checks: Task 1, items 1 to 3 and 6;
    - reserved name: item 4;
    - existing collision: item 5;
    - help pages: item 7;
    - NEWS: Task 2.
  - Section 4 (hvtiRtemplates):
    - edit blocks and prose: Task 4;
    - `read_job_data()` default kept, both names work: Task 3;
    - minimum version: Task 5;
    - existing jobs that say `"study"` keep working: Task 3 and the canonical records.
  - Section 5 (tests):
    - the same data under both names: Task 1;
    - `register_data()` refusing `built`: Task 1;
    - the collision stop: Task 1;
    - a template rendering with `"built"`: Task 4, Step 6, and Task 5, Step 4.
- **Placeholders.** None in code. The hvtiRutilities minimum version is named at its bump.
- **Names.** `.canonical_dataset()` (hvtiRutilities) and `.canonical_job_dataset()` (hvtiRtemplates) are each spelled the same throughout.
