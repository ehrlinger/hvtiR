# Job names: template first, periods between fields: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `add_job()` names a job `<prefix>[.<qualifier>].<subject>.<type>.qmd` (runner `....runner.R`); every template, `open_job()` and `job_census()` read both that form and the old `<subject>-<type>-<prefix>[-<qualifier>].qmd`; and `template_list()` shows qualified templates as `dp.trends`.

**Architecture:** One new file in hvtiRtemplates, `R/job-name.R`, owns the job name: `.job_stem()` builds the new form and `.job_name_fields()` reads `c(subject, type)` from either form. `add_job()` and `open_job()` build through it, and each template's existing filename check swaps its one parsing line for a call to it, so the check's logic and messages are unchanged. Template *display* names change from `dp-trends` to `dp.trends`, and selection accepts both. The template files inside the package keep their names. In hvtiRutilities, `job_census()` gains a parser for the new form that runs before its SAS-legacy parser.

**Tech Stack:** R (>= 4.4.0), testthat edition 3, roxygen2 (Rd markup in both packages), Quarto.

**Spec:** `hvtiR/dev/specs/2026-10-07-job-naming-template-first-design.md`.

## Global Constraints

- Two repositories, independent of each other: `ehrlinger/hvtiRutilities` (Phase A, Task 1) and `ehrlinger/hvtiRtemplates` (Phase B, Tasks 2 to 7). One branch and pull request each. Never push to `main`.
- Phase B edits the same templates as designs 3, 5 and 6's Task 8. It lands after design 3's Phase B, and later ones rebase onto it.
- Field rule, unchanged: `subject`, `type` and `qualifier` match `^[A-Za-z0-9_]+$`. Neither `.` nor `-` can appear inside a field, so the separator tells the two forms apart, and the field count (three or four) says whether a qualifier is present. No catalog lookup is needed to parse a name.
- Results folders stay `estimates/<subject>-<type>/` and `graphs/<subject>-<type>/`. Nothing here touches `set_path()`.
- Template files inside the package keep their names (`inst/templates/40_graphs/dp-trends.qmd`). Only the name shown and accepted changes.
- Existing jobs are not renamed, and keep rendering.
- Rd markup in both packages. Line length 135. `lintr::lint_package()` clean.
- `NEWS.md` bullets under `(unreleased)`. Do not touch `Version:`.
- Definition of done per repository: `devtools::test()` passes; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` run, `man/` and `NAMESPACE` committed.
- The planning container had no R. Run every command on a machine with R and Quarto.

## Amendments to the design, made while planning

Recorded in the design file.

1. **The census parser needs no catalog.** The design said it would claim four fields "when that prefix carries a qualifier", which hvtiRutilities cannot know, because the catalog lives in hvtiRtemplates. Because no field contains a period, the count alone settles it: three fields means no qualifier, four means one. A name the new parser claims is labelled `naming = "scaffolded"`, the same convention in its new spelling.
2. **The template change is one line per template.** Each template's filename check keeps its own block, comments and stop message, and only the line that splits the name changes to `.fields <- hvtiRtemplates:::.job_name_fields(.current)`. The new function returns `c(subject, type)` in the order the old split did.
3. **`add_job()` also refuses when the old spelling of the same job exists**, and **`open_job()` opens it**. Without this, a study that already has `dead_pa-hz-ac.qmd` would gain a second, empty `ac.dead_pa.hz.qmd` for the same set the next time someone scaffolds or opens it.

## File structure

**hvtiRutilities:** `R/job_names.R` (new pattern), `R/job_census.R` (runner stem), `tests/testthat/test-job-names.R`, `NEWS.md`.

**hvtiRtemplates**

| file | change |
|---|---|
| `R/job-name.R` | create: `.job_stem()`, `.job_name_fields()`, `.job_path_legacy()` |
| `R/add-job.R` | `.job_path()` builds the new form; runner name; refuse when the old spelling exists; roxygen |
| `R/open-job.R` | open the old spelling when it is the one present |
| `R/templates.R` | display names with `.`; `.split_template_name()` accepts `.` or `-`; the two joined-name messages |
| `inst/templates/**/*.qmd` | one line in each of 34 templates; comments that spell out job names |
| `inst/runners/*.R`, `inst/templates/README.md`, `README.md`, `vignettes/*.qmd`, `AGENTS.md` | examples and the naming rule |
| `tests/testthat/test-job-name.R` | create |
| `tests/testthat/test-add-job.R`, `test-open-job.R`, `test-migrate-job.R`, `test-migrate-dc-tables.R`, `test-templates.R`, `helper-rf.R` | expectations |
| `NEWS.md` | |

---

## Phase A: hvtiRutilities

### Task 1: `job_census()` reads the template-first form

**Files:**
- Modify: `R/job_names.R` (`.job_name_fields()`), `R/job_census.R` (the runner stem lines, about line 310)
- Test: `tests/testthat/test-job-names.R` (append)
- Modify: `NEWS.md`

**Interfaces:**
- Produces: `.job_name_fields()` returns `naming = "scaffolded"`, the prefix, and the qualifier (when four fields) for `<prefix>[.<qualifier>].<subject>.<type>.qmd` and `....runner.R`; `job_files()` gives a dotted runner its report's stem.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-job-names.R`:

```r
test_that("the template-first form is parsed as scaffolded, before the legacy parser", {
  # hvtiRtemplates::add_job() writes <prefix>[.<qualifier>].<subject>.<type>.qmd
  # since 2026-10. The legacy parser would read any dotted name as <prefix>.<anything>
  # and call it a SAS-era job.
  out <- hvtiRutilities:::.job_name_fields(
    c("ac.death.hz.qmd", "dp.trends.cohort.eda.qmd", "bl.death.boot.runner.R")
  )
  expect_equal(out$naming, rep("scaffolded", 3))
  expect_equal(out$prefix, c("ac", "dp", "bl"))
  expect_equal(out$qualifier1, c(NA, "trends", NA))
  expect_equal(out$n_qualifiers, c(0L, 1L, 0L))
})

test_that("SAS-era dotted names stay legacy", {
  out <- hvtiRutilities:::.job_name_fields(c("hm.dead.sas", "dp.trends.sas", "ac.death.hz.lst", "zz.death.hz.qmd"))
  expect_equal(out$naming, rep("legacy", 4))
})

test_that("a template-first runner takes its report's stem in job_files()", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "analyses"))
  file.create(file.path(root, "analyses", c("bl.death.boot.qmd", "bl.death.boot.runner.R")))
  files <- job_files(root)
  expect_identical(unique(files$stem[files$naming %in% "scaffolded"]), "bl.death.boot")
})
```

`zz` is not a taxonomy prefix, so `zz.death.hz.qmd` stays legacy. If `job_files()` needs a different root layout or column names than the test assumes, read the existing `job_files()` tests in `test-job-files.R` and match them; the assertion is that the runner and its report share one stem.

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "job-names|job-files")'`
Expected: FAIL; the dotted names parse as `legacy`.

- [ ] **Step 3: Write the implementation**

In `R/job_names.R`, inside `.job_name_fields()`:

1. Directly after the existing block that claims `sca_known` (the scaffolded names whose prefix is known), add:

```r
  # <prefix>[.<qualifier>].<subject>.<type>.qmd, add_job()'s form since
  # 2026-10, and its .runner.R. No field contains a period, so three fields is
  # a template with no qualifier and four is one with a qualifier: the count
  # settles it without the template catalog, which lives in hvtiRtemplates.
  # Claimed only for a known prefix, and before `legacy`, which would otherwise
  # read any dotted name as a SAS-era job.
  dotted <- "^([A-Za-z0-9]+)(?:[.]([A-Za-z0-9_]+))?[.][A-Za-z0-9_]+[.][A-Za-z0-9_]+(?:[.]qmd|[.]runner[.]R)$"
  dot_hit <- is.na(naming) & grepl(dotted, stripped, perl = TRUE) &
    sub(dotted, "\\1", stripped, perl = TRUE) %in% known
  naming[dot_hit] <- "scaffolded"
  prefix[dot_hit] <- sub(dotted, "\\1", stripped[dot_hit], perl = TRUE)
```

2. In the qualifier block for `sca`, the qualifier of a dotted name comes from the same pattern. Replace

```r
  sca <- !is.na(naming) & naming == "scaffolded"
  if (any(sca)) {
    q <- sub(patterns$scaffolded, "\\2", stripped[sca])
    quals[sca] <- lapply(q, function(x) if (nzchar(x)) x else character(0))
  }
```

with

```r
  sca <- !is.na(naming) & naming == "scaffolded"
  if (any(sca)) {
    is_dot <- grepl(dotted, stripped[sca], perl = TRUE)
    q <- ifelse(is_dot, sub(dotted, "\\2", stripped[sca], perl = TRUE), sub(patterns$scaffolded, "\\2", stripped[sca]))
    quals[sca] <- lapply(q, function(x) if (nzchar(x)) x else character(0))
  }
```

A three-field dotted name leaves group 2 empty, so it has no qualifier.

In `R/job_census.R`, replace

```r
    runner <- fields$naming %in% "scaffolded" & grepl("-runner[.]R$", base)
    stem[runner] <- sub("-runner$", "", stem[runner])
```

with

```r
    runner <- fields$naming %in% "scaffolded" & grepl("([.]|-)runner[.]R$", base)
    stem[runner] <- sub("([.]|-)runner$", "", stem[runner])
```

Update the comment above `.job_name_fields()`'s `patterns` list, and the `@description` of `job_files()` that mentions `-runner.R`, to name both spellings.

Add under `# hvtiRutilities (unreleased)` in `NEWS.md`:

```markdown
* `job_census()` and `job_files()` read hvtiRtemplates' template-first job
  names, `<prefix>[.<qualifier>].<subject>.<type>.qmd` and their
  `.runner.R`, as scaffolded jobs. Before, the SAS-legacy parser claimed any
  dotted name and counted them as SAS-era jobs.
```

- [ ] **Step 4: Run tests and gates**

Run: `Rscript -e 'devtools::document(); devtools::test()'`, `lintr::lint_package()`, `devtools::check(document = FALSE, manual = FALSE)`.
Expected: `FAIL 0`; no lints; 0 errors, 0 warnings, 0 notes.

- [ ] **Step 5: Commit, push, open the pull request**

```bash
git add R/job_names.R R/job_census.R tests/testthat/test-job-names.R NEWS.md man
git commit -m "Read template-first job names in the job census"
```

---

## Phase B: hvtiRtemplates

### Task 2: The job name, in one place

**Files:**
- Create: `R/job-name.R`
- Test: `tests/testthat/test-job-name.R` (create)

**Interfaces:**
- Produces:
  - `.job_stem(prefix, qualifier, subject, type)` returns `"ac.death.hz"` (`qualifier` `NA` or `NULL` for none).
  - `.job_name_fields(path)` returns `c(subject, type)` from either form, or `character(0)`.
  - `.job_path_legacy(row, subject, type, root)` returns the old-form path for the same job.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-job-name.R`:

```r
test_that("the stem is template first, with periods", {
  expect_identical(hvtiRtemplates:::.job_stem("ac", NA_character_, "death", "hz"), "ac.death.hz")
  expect_identical(hvtiRtemplates:::.job_stem("dp", "trends", "cohort", "eda"), "dp.trends.cohort.eda")
  expect_identical(hvtiRtemplates:::.job_stem("ac", NULL, "death", "hz"), "ac.death.hz")
})

test_that("subject and type are read from either spelling", {
  f <- hvtiRtemplates:::.job_name_fields
  expect_identical(f("x/20_distributions/ac.death.hz.qmd"), c("death", "hz"))
  expect_identical(f("dp.trends.cohort.eda.qmd"), c("cohort", "eda"))
  expect_identical(f("bl.death.boot.runner.R"), c("death", "boot"))
  expect_identical(f("dead_pa-hz-ac.qmd"), c("dead_pa", "hz"))
  expect_identical(f("cohort-eda-dp-trends.qmd"), c("cohort", "eda"))
  expect_identical(f("dead_pa-boot-bl-runner.R"), c("dead_pa", "boot"))
})

test_that("Quarto's intermediate file reads the same as the job", {
  f <- hvtiRtemplates:::.job_name_fields
  expect_identical(f("ac.death.hz.rmarkdown"), c("death", "hz"))
  expect_identical(f("dead_pa-hz-ac.rmarkdown"), c("dead_pa", "hz"))
})

test_that("a name in neither form gives no fields", {
  f <- hvtiRtemplates:::.job_name_fields
  expect_identical(f("analysis.qmd"), character(0))
  expect_identical(f("a.b.qmd"), character(0))
  expect_identical(f("a.b.c.d.e.qmd"), character(0))
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "job-name")'`
Expected: FAIL, `.job_stem` not found.

- [ ] **Step 3: Write the implementation**

Create `R/job-name.R`:

```r
# A job's file name. add_job() writes the first spelling; both are read.
#
#   <prefix>[.<qualifier>].<subject>.<type>.qmd   since 2026-10
#   <subject>-<type>-<prefix>[-<qualifier>].qmd   before
#
# subject, type and qualifier match ^[A-Za-z0-9_]+$, so neither "." nor "-"
# can appear inside a field: the separator tells the spellings apart, and in
# the period form the field count says whether a qualifier is present. A
# runner adds .runner.R (or -runner.R). Design: hvtiR
# dev/specs/2026-10-07-job-naming-template-first-design.md.

.job_stem <- function(prefix, qualifier, subject, type) {
  has_qualifier <- !is.null(qualifier) && !is.na(qualifier)
  paste(c(prefix, if (has_qualifier) qualifier, subject, type), collapse = ".")
}

# c(subject, type) from a job's path, or character(0) when the name is in
# neither spelling. Quarto knits through an intermediate (<stem>.rmarkdown),
# so the last extension is stripped whatever it is. The dash spelling keeps
# the old check's leniency: it took the first two fields of any dashed name.
.job_name_fields <- function(path) {
  stem <- sub("([.]|-)runner$", "", sub("[.][^.]+$", "", basename(path)))
  field <- "^[A-Za-z0-9_]+$"
  if (grepl("-", stem, fixed = TRUE)) {
    parts <- strsplit(stem, "-", fixed = TRUE)[[1L]]
    return(if (length(parts) >= 2L) parts[1:2] else character(0))
  }
  parts <- strsplit(stem, ".", fixed = TRUE)[[1L]]
  if (length(parts) %in% 3:4 && all(grepl(field, parts))) return(parts[(length(parts) - 1L):length(parts)])
  character(0)
}

# The same job in the dash spelling, so add_job() can refuse a duplicate and
# open_job() can open a job scaffolded before 2026-10.
.job_path_legacy <- function(row, subject, type, root) {
  out_dir <- hvtiRutilities::study_dir(row$folder[[1L]], root = root)
  stem <- paste0(subject, "-", type, "-", row$prefix[[1L]],
                 if (!is.na(row$qualifier[[1L]])) paste0("-", row$qualifier[[1L]]) else "")
  file.path(out_dir, paste0(stem, ".qmd"))
}
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "job-name")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/job-name.R tests/testthat/test-job-name.R
git commit -m "Build and read job names in one place, in both spellings"
```

---

### Task 3: `add_job()` and `open_job()` use the new form

**Files:**
- Modify: `R/add-job.R` (`add_job()`, `.job_path()`, roxygen), `R/open-job.R`
- Modify: `tests/testthat/test-add-job.R`, `test-open-job.R`, `test-migrate-job.R`, `test-migrate-dc-tables.R`, `helper-rf.R`

**Interfaces:**
- Consumes: Task 2.
- Produces: `add_job("ac", "death", "hz")` writes `ac.death.hz.qmd`; a runner is `<stem>.runner.R`; `add_job()` refuses when either spelling exists; `open_job()` opens whichever exists.

- [ ] **Step 1: Update the expectations and add the two new tests**

In `tests/testthat/test-add-job.R`, change every expected job file name from the dash form to the period form: `dead_pa-hz-ac.qmd` becomes `ac.dead_pa.hz.qmd` (lines 58, 72, 89, 109, 122). In the runner test (about lines 330 to 355), runners are now `sub("[.]qmd$", ".runner.R", job)` and `paste0(prefix, ".dead_pa.boot.runner.R")`. The runner *templates* in `inst/runners/` keep their names, so the expectation listing `paste0(c("bl", "br", "bc", "bh"), "-runner.R")` at line 332 is unchanged.

In `tests/testthat/test-open-job.R` line 105, `"^dead-eda-dc-tables[.]qmd$"` becomes `"^dc[.]tables[.]dead[.]eda[.]qmd$"`.

In `tests/testthat/test-migrate-job.R` (lines 27, 328, 344, 476, 648, 659) and `test-migrate-dc-tables.R` (line 234), `cohort-eda-dc-tables.qmd` becomes `dc.tables.cohort.eda.qmd`, `mortality-eda-dc-tables.qmd` becomes `dc.tables.mortality.eda.qmd`, and `named-eda-dc-tables.qmd` becomes `dc.tables.named.eda.qmd`. If line numbers have moved, find them with `grep -n "eda-dc-tables" <file>`.

In `tests/testthat/helper-rf.R` line 274, `"-runner.R"` becomes `".runner.R"`.

Append to `tests/testthat/test-add-job.R`:

```r
test_that("add_job refuses a job whose old spelling already exists", {
  d <- file.path(withr::local_tempdir(), "study")
  invisible(hvtiRutilities::study_setup(d, study = "Old spelling", study_tracker_id = 1L))
  old <- file.path(hvtiRutilities::study_dir("distributions", d), "dead_pa-hz-ac.qmd")
  dir.create(dirname(old), recursive = TRUE, showWarnings = FALSE)
  file.copy(template_path("ac"), old)
  expect_error(add_job("ac", "dead_pa", "hz", dir = d), "dead_pa-hz-ac.qmd")
  expect_false(file.exists(file.path(dirname(old), "ac.dead_pa.hz.qmd")))
})
```

Append to `tests/testthat/test-open-job.R`:

```r
test_that("open_job opens a job scaffolded under the old spelling", {
  d <- file.path(withr::local_tempdir(), "study")
  invisible(hvtiRutilities::study_setup(d, study = "Old spelling", study_tracker_id = 1L))
  old <- file.path(hvtiRutilities::study_dir("distributions", d), "dead_pa-hz-ac.qmd")
  dir.create(dirname(old), recursive = TRUE, showWarnings = FALSE)
  file.copy(template_path("ac"), old)
  expect_message(out <- open_job("ac", "dead_pa", "hz", dir = d), "already exists")
  expect_identical(normalizePath(out), normalizePath(old))
})
```

`open_job()`'s argument order is `(prefix, subject, type, ...)`; if it differs, match it.

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "add-job|open-job|migrate")'`
Expected: FAIL; files are still written in the dash form.

- [ ] **Step 3: Write the implementation**

In `R/add-job.R`:

1. Replace `.job_path()`'s body with:

```r
.job_path <- function(row, subject, type, root) {
  out_dir <- hvtiRutilities::study_dir(row$folder[[1L]], root = root)
  file.path(out_dir, paste0(.job_stem(row$prefix[[1L]], row$qualifier[[1L]], subject, type), ".qmd"))
}
```

   and update its comment to say the name is template first, with periods (`<prefix>[.<qualifier>].<subject>.<type>.qmd`), and that `.job_name_fields()` reads both spellings.

2. In `add_job()`, replace

```r
  runner_src <- .runner_template(row$name[[1L]])
  runner <- if (nzchar(runner_src)) sub("[.]qmd$", "-runner.R", out) else character()
```

   with

```r
  runner_src <- .runner_template(sub("[.]qmd$", "", basename(row$file[[1L]])))
  runner <- if (nzchar(runner_src)) sub("[.]qmd$", ".runner.R", out) else character()
  # The same job scaffolded before 2026-10 has the dash spelling. A second,
  # empty copy under the new spelling would split one set's edits across two files.
  legacy <- .job_path_legacy(row, subject, type, dir)
  if (file.exists(legacy)) {
    stop("add_job(): this job already exists as '", legacy, "', its name before 2026-10; refusing to write a ",
         "second copy. Open it with open_job(), or rename it to '", basename(out), "' first.", call. = FALSE)
  }
```

   `.runner_template()` is unchanged: it looks up `inst/runners/<template stem>-runner.R`.

3. Update the roxygen block of `add_job()`. Replace every `\code{<subject>-<type>-<prefix>[-<qualifier>].qmd}` with `\code{<prefix>[.<qualifier>].<subject>.<type>.qmd}`, the runner name `\code{<subject>-<type>-<prefix>-runner.R}` with `\code{<prefix>.<subject>.<type>.runner.R}`, and the sentence about `-` separating fields with: "\code{.} separates the filename's fields, so neither \code{.} nor \code{-} may appear in a field." Add one paragraph to `@details`:

```r
#' \strong{Names before 2026-10.} Jobs were named
#' \code{<subject>-<type>-<prefix>[-<qualifier>].qmd} until 2026-10. They keep
#' that name and keep rendering; \code{add_job()} refuses to write a second
#' copy of such a job under the new name, and \code{\link{open_job}} opens it.
```

   Update `@examples` comments that name the written file.

In `R/open-job.R`, directly after `out <- .job_path(row, subject, type, root)`, add:

```r
  legacy <- .job_path_legacy(row, subject, type, root)
  if (!file.exists(out) && file.exists(legacy)) out <- legacy
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "add-job|open-job|migrate|rf")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/add-job.R R/open-job.R tests/testthat man
git commit -m "Scaffold jobs template first, and keep finding jobs named the old way"
```

---

### Task 4: Templates are shown as `dp.trends`

**Files:**
- Modify: `R/templates.R` (`template_list()`, `.template_call()`, `.split_template_name()`, the two joined-name lines)
- Modify: `tests/testthat/test-templates.R`

**Interfaces:**
- Produces: `template_list()$name` and `$call` use `.`; `.split_template_name()` accepts `"dp.trends"` and `"dp-trends"`; messages name templates with `.`.

- [ ] **Step 1: Update and add the tests**

In `tests/testthat/test-templates.R`:
- In the test ".select_template() resolves a template stem" (about line 853), keep the `"dp-trends"` expectation and add `expect_equal(hvtiRtemplates:::.select_template(tl, "dp.trends")$file, "a.qmd")`. In its `bad` loop, add `"dp."`, `".trends"` and `"dp.trends.x"`.
- In "a stem and a qualifier together are refused", add `expect_error(template_path("dp.trends", "trends"), "not both")`.
- In "the choices on offer are shown by full name", change `expect_error(template_path("dp"), "dp-trends")` to `"dp.trends"`.

Append:

```r
test_that("template_list shows qualified templates with a period, and the call uses it", {
  tl <- template_list()
  row <- tl[!is.na(tl$qualifier) & tl$prefix == "dp" & tl$qualifier == "trends", ]
  expect_identical(row$name, "dp.trends")
  expect_match(row$call, '^add_job\\("dp[.]trends"')
  expect_false(any(grepl("-", tl$name, fixed = TRUE)))
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "templates")'`
Expected: FAIL; names still use `-`.

- [ ] **Step 3: Write the implementation**

In `R/templates.R`:

1. In `template_list()`, change `name = sub("[.]qmd$", "", basename(files)),` to

```r
    name      = sub("-", ".", sub("[.]qmd$", "", basename(files)), fixed = TRUE),
```

   A template file is `<prefix>[-<qualifier>].qmd`, and neither part contains `-`, so the first dash is the only one.

2. In `.template_call()`, change the `sprintf` line's first argument from `sub("[.]qmd$", "", basename(file))` to `sub("-", ".", sub("[.]qmd$", "", basename(file)), fixed = TRUE)`.

3. Replace `.split_template_name()` with:

```r
.split_template_name <- function(prefix, qualifier = NULL) {
  if (!is.null(qualifier)) .check_scalar_string("qualifier", qualifier)
  if (!grepl("[.-]", prefix)) return(list(prefix = prefix, qualifier = qualifier))
  if (!is.null(qualifier)) {
    stop("template selection: name the template by its full name ('", prefix,
         "') or as prefix plus qualifier, not both.", call. = FALSE)
  }
  if (!grepl("^[^.-]+[.-][^.-]+$", prefix)) {
    stop("template selection: '", prefix, "' is not a template name; ",
         "expected <prefix>.<qualifier>, e.g. 'dp.trends'.", call. = FALSE)
  }
  list(prefix = sub("[.-].*$", "", prefix), qualifier = sub("^[^.-]*[.-]", "", prefix))
}
```

4. At about line 161, change `paste0(hit$prefix, "-", hit$qualifier)` to `paste0(hit$prefix, ".", hit$qualifier)`; at about line 281, the same change.

5. Update `template_list()`'s and `template_path()`'s roxygen where they describe `name` or give `"dp-trends"` as the example: the name is `dp.trends`, and `"dp-trends"` is still accepted.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "templates|template-catalog|add-job|deprecation")'`
Expected: PASS. A test that compares `template_list()$name` with file stems (for example a roadmap or ledger check) compares against `sub("-", ".", stem, fixed = TRUE)`; update it to do so.

- [ ] **Step 5: Commit**

```bash
git add R/templates.R tests/testthat man
git commit -m "Show qualified templates as dp.trends, and accept either spelling"
```

---

### Task 5: Every template reads either spelling

**Files:**
- Modify: the 34 templates in `inst/templates/` that contain the old splitting line
- Test: `tests/testthat/test-job-name.R` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/testthat/test-job-name.R`:

```r
test_that("every template reads its own name through .job_name_fields()", {
  files <- list.files(system.file("templates", package = "hvtiRtemplates"), pattern = "[.]qmd$",
                      recursive = TRUE, full.names = TRUE)
  old <- 'strsplit(sub("[.][^.]+$", "", basename(.current)), "-", fixed = TRUE)'
  for (f in files) {
    src <- readLines(f, warn = FALSE)
    expect_false(any(grepl(old, src, fixed = TRUE)), info = basename(f))
    if (any(grepl("knitr::current_input()", src, fixed = TRUE)) && any(grepl("^SUBJECT", src))) {
      expect_true(any(grepl(".fields <- hvtiRtemplates:::.job_name_fields(.current)", src, fixed = TRUE)),
                  info = basename(f))
    }
  }
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "job-name")'`
Expected: FAIL for 34 templates.

- [ ] **Step 3: Swap the line**

From the package root, run once:

```r
files <- list.files("inst/templates", pattern = "[.]qmd$", recursive = TRUE, full.names = TRUE)
from <- '.fields <- strsplit(sub("[.][^.]+$", "", basename(.current)), "-", fixed = TRUE)[[1L]]'
to <- ".fields <- hvtiRtemplates:::.job_name_fields(.current)"
n <- 0L
for (f in files) {
  x <- readLines(f, warn = FALSE)
  y <- sub(from, to, x, fixed = TRUE)
  if (!identical(x, y)) {
    writeLines(y, f)
    n <- n + 1L
  }
}
n
```

Expected: `34`. The rest of each block (`.name_subject <- if (length(.fields) >= 1L) ...`, or `bd.qmd`'s `.fields[1L]`) works unchanged, because the function returns `c(subject, type)` in the order the old split did, and `character(0)` for a name in neither form, which those lines already treat as a mismatch.

- [ ] **Step 4: Run the tests, including a render of each spelling**

Run: `Rscript -e 'devtools::test()'`
Expected: `FAIL 0`. The tests that scaffold a real template with `add_job()` and render it (the hazard-chain, `bd` and rf tests) now produce period names, so they run the new line on the new spelling. Add one render of a period name to `test-template-provenance.R`, beside the test "an endpoint-free render writes a stem-matched sidecar without invented blocks". `write_provenance_job()` writes a job without the set check, so this test covers Quarto's file naming, not the check:

```r
test_that("a job named template first renders, and its sidecar takes its name", {
  skip_if_not_installed("quarto")
  skip_if_not(quarto::quarto_available(), "Quarto CLI is required for rendering")
  root <- make_provenance_study(withr::local_tempdir())
  job <- write_provenance_job(
    root, "dc.general.cohort.eda", "dc-general",
    c('SUBJECT <- "cohort"', 'TYPE <- "eda"', 'DATASET <- "study"')
  )
  render_provenance_job(job, root)
  expect_true(file.exists(file.path(root, "dc.general.cohort.eda.html")))
  expect_true(file.exists(file.path(root, "dc.general.cohort.eda.provenance.json")))
})
```

This also confirms the one thing the planner could not check: that Quarto names its intermediate and output files for a stem containing periods as `<stem>.rmarkdown` and `<stem>.html`.

- [ ] **Step 5: Commit**

```bash
git add inst/templates tests/testthat/test-job-name.R tests/testthat/test-template-provenance.R
git commit -m "Let every template's name check read both spellings"
```

---

### Task 6: Documentation

**Files:**
- Modify: `README.md`, `vignettes/study-setup.qmd`, `vignettes/sas-to-r-descriptive.qmd`, `vignettes/work-a-job.qmd`, `vignettes/new-study.qmd`, `inst/templates/README.md`, `inst/runners/bl-runner.R`, `inst/runners/bh-runner.R`, template comments that spell out a job name, `AGENTS.md`

- [ ] **Step 1: Replace the example names**

From the package root, run once:

```r
files <- c("README.md", list.files("vignettes", pattern = "[.]qmd$", full.names = TRUE),
           "inst/templates/README.md", list.files("inst/runners", full.names = TRUE),
           list.files("inst/templates", pattern = "[.]qmd$", recursive = TRUE, full.names = TRUE))
swaps <- c(
  "cohort-eda-dc-tables" = "dc.tables.cohort.eda",
  "cohort-eda-dc-gfup" = "dc.gfup.cohort.eda",
  "cohort-eda-dc-general" = "dc.general.cohort.eda",
  "dead_pa-hz-ac" = "ac.dead_pa.hz",
  "<subject>-<type>-<prefix>[-<qualifier>]" = "<prefix>[.<qualifier>].<subject>.<type>",
  "<subject>-<type>-<prefix>-runner.R" = "<prefix>.<subject>.<type>.runner.R"
)
for (f in files) {
  x <- readLines(f, warn = FALSE)
  y <- x
  for (from in names(swaps)) y <- gsub(from, swaps[[from]], y, fixed = TRUE)
  if (!identical(x, y)) writeLines(y, f)
}
```

- [ ] **Step 2: Find what the script did not cover**

Run: `grep -rnE '[a-z0-9_]+-[a-z0-9_]+-(ac|hz|hm|hp|hs|bc|bh|bl|br|dc|dp|lm|nb|rf[crs])(-[a-z_]+)?(\.qmd|-runner\.R)' README.md vignettes inst AGENTS.md`

Rewrite each hit to the period form by hand, reading the sentence around it. Leave `NEWS.md` and `dev/` alone: they record what was true when written. A mention of the old form *as* the old form (for example "jobs named before 2026-10, such as `dead_pa-hz-ac.qmd`") stays.

- [ ] **Step 3: Update `AGENTS.md`'s naming rule**

In `AGENTS.md`, in the "Template naming" section, replace the paragraph beginning "`add_job(prefix, subject, type, dir = ".", qualifier = NULL)` writes" with:

```markdown
`add_job(prefix, subject, type, dir = NULL, qualifier = NULL)` writes
`<folder>/<prefix>[.<qualifier>].<subject>.<type>.qmd`, where `<folder>` follows the study's
numbered or legacy bare layout, and **refuses to overwrite an existing job**, under either
spelling, because a job file accumulates a study's edits. Jobs scaffolded before 2026-10
are `<subject>-<type>-<prefix>[-<qualifier>].qmd`; they keep that name, and every template's
name check reads both (`.job_name_fields()` in `R/job-name.R`). `subject` and `type` name the
`(subject, analysis type)` set the job belongs to; both are required and restricted to
`[A-Za-z0-9_]+`, because `.` separates the filename's fields. Template *files* in this
package keep `<prefix>[-<qualifier>].qmd`; `template_list()` shows them as `dp.trends`.
```

`AGENTS.md` is in `.Rbuildignore`, so this edit needs no NEWS entry of its own.

- [ ] **Step 4: Build the vignettes**

Run: `Rscript -e 'devtools::build_vignettes()'`
Expected: builds without error.

- [ ] **Step 5: Commit**

```bash
git add README.md vignettes inst AGENTS.md
git commit -m "Name jobs template first in the documentation"
```

---

### Task 7: Phase B NEWS and gates

- [ ] **Step 1: NEWS.** Under `# hvtiRtemplates (unreleased)`:

```markdown
* **Jobs are named template first, with periods.** `add_job()` writes
  `<prefix>[.<qualifier>].<subject>.<type>.qmd`, such as `ac.death.hz.qmd` or
  `dp.trends.cohort.eda.qmd`, and a runner beside it as `....runner.R`, so a
  study's jobs sort by template, then subject, then type. Jobs scaffolded
  before this release keep their `<subject>-<type>-<prefix>` names and keep
  rendering: every template's name check reads both spellings. `add_job()`
  refuses to write a second copy of a job that exists under its old name, and
  `open_job()` opens it. `template_list()` shows qualified templates as
  `dp.trends`; `"dp-trends"` is still accepted. Results folders
  (`estimates/<subject>-<type>/`) are unchanged.
```

- [ ] **Step 2:** `Rscript -e 'devtools::document()'`, `lintr::lint_package()`, `devtools::test()`, `devtools::check(document = FALSE, manual = FALSE)`. Expected: no lints; `FAIL 0` with the `SKIP` count unchanged from `main`; 0 errors, 0 warnings, 0 notes.
- [ ] **Step 3: End to end.** In a scratch study:
  1. `add_job("ac", "death", "hz")`, `add_job("hz", "death", "hz")` and `add_job("hm", "death", "hz")`.
  2. Render the three in order. `hm` must find `estimates/death-hz/hz.rds`.
  3. Rename one job by hand to `ac.death.other.qmd` and render it. It must stop with the existing "named ... but declares" message.
  4. Run `hvtiRutilities::job_census(hvtiRutilities::job_files(<study>))`. The three jobs must count as scaffolded `ac`, `hz` and `hm`.
- [ ] **Step 4:** Commit (`git add NEWS.md man && git commit -m "Record template-first job names in NEWS"`), push, open the pull request linking the design and this plan.

---

## Self-review

- **Spec coverage.**
  - Section 2, the form and its unambiguous parse: Task 2.
  - Section 3, what changes:
    - `add_job()`: Task 3;
    - the template filename check, both spellings: Tasks 2 and 5;
    - the catalog display: Task 4;
    - `job_census()`: Task 1.
  - Section 4, what does not change:
    - results folders: untouched by every task;
    - existing jobs: Tasks 3 and 5;
    - template file names: Task 4.
  - Section 5, tests:
    - `add_job()` naming and runners: Task 3;
    - the shared check accepting both forms and stopping on a mismatch: Tasks 2 and 5, and Task 7's end-to-end run;
    - the census: Task 1;
    - the display: Task 4.
- **Placeholders.** None in code. Task 6, Step 2 is a search-and-read step by design: prose needs reading.
- **Names.** `.job_stem()`, `.job_name_fields()` and `.job_path_legacy()` are spelled the same in every task. The census pattern is held in a variable named `dotted`.
