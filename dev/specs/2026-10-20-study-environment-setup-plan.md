# Study Environment Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One command, `hvtiR::setup()`, leaves a study with a correct renv environment (cleanup before renv, explicit-mode lockfile, restore-never-upgrade), and the family installs missing optional packages instead of naming them.

**Architecture:** Four repositories, in release order. Downstream test suites first make every `study_setup()` call explicit (Part A), so the `hvtiRutilities` default flip (Part B) breaks nothing on `main`. `hvtiRutilities` gains `study_declare()` (the study `DESCRIPTION`) and `study_need()` (install-or-stop), and runs renv in explicit mode. `hvtiRtemplates` makes `add_job()` call `study_need()` (Part C). `hvtiR` adds `setup()`, which orchestrates the rest in a child R process, and two `doctor()` checks (Part D).

**Tech Stack:** R (>= 4.4.0), renv 1.2.4 (installed; verify in Task 1), pak, testthat 3e with `local_mocked_bindings()`, cli, rstudioapi (Suggests).

**Spec:** [2026-10-20-study-environment-setup-design.md](2026-10-20-study-environment-setup-design.md).

## Global Constraints

- Never push to `main`. One branch and one PR per part per repo; run `/code-review` locally before opening each PR and say so in the PR body.
- Versions: straight three digits, **patch bumps only**. A PR adds a `news/<branch-with-slashes-as-dashes>.md` fragment and does not touch `Version:` or `NEWS.md`.
- `hvtiRutilities` and `hvtiRtemplates` roxygen is **Rd markup, not markdown** (`\code{}`, `\strong{}`); check each repo's `DESCRIPTION` for `Roxygen: list(markdown = TRUE)` before writing docs. `hvtiR` roxygen is markdown (its sources use backticks).
- Line width: read each repo's `.lintr` (135 in `hvtiRtemplates`, 80 in `hvtiRutilities`).
- Every PR: `devtools::document()`, `devtools::test()`, `devtools::check()` at 0/0/0, `man/` and `NAMESPACE` committed.
- No `git add -A` after a test run (failing runs write `tests/testthat/_problems/`). Stage named files.
- Release order: **Part A (`hvtiRtemplates`, `hvtiRdatabuild`) merges before Part B**; then B, C, D. A version floor on another family package moves only in the depending package's own bump.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File map

| Repo | File | Change |
|---|---|---|
| hvtiR | `dev/specs/artifacts/2026-10-20-renv-spike.md` | Task 1 findings |
| hvtiRtemplates | `tests/testthat/test-study-setup-explicit.R` | new guard test |
| hvtiRtemplates | `tests/testthat/helper-*.R`, `test-*.R`, `R/*.R` examples | explicit `renv`/`cleanup` |
| hvtiRdatabuild | `tests/testthat/test-study-setup-explicit.R`, `helper-analysis-set.R`, `R/analysis_set.R` | same |
| hvtiRutilities | `R/study_declare.R` | new: `study_declare()` |
| hvtiRutilities | `R/study_need.R` | new: `study_need()` and seams |
| hvtiRutilities | `R/study_setup.R` | defaults, explicit mode, `.renvignore` |
| hvtiRutilities | `R/registered_versions.R`, `R/read_clinical_data.R` | use `study_need()` |
| hvtiRtemplates | `R/template-packages.R` | new: `.template_packages()` |
| hvtiRtemplates | `R/add-job.R` | call `study_need()` |
| hvtiR | `R/setup.R` | new: `setup()` and helpers |
| hvtiR | `R/status.R` | `doctor()` checks, `unresolved_imports()`, `lockfile_r_version()` |

---

## Part 0: verify renv's behavior

### Task 1: renv spike

The design rests on four renv 1.2.4 behaviors. Verify them before writing code; if any fails, stop and revise the spec.

**Files:**
- Create: `hvtiR/dev/specs/artifacts/2026-10-20-renv-spike.md`

- [ ] **Step 1: Write the spike script in the scratchpad** (not in any repo)

```r
# spike.R -- run with: Rscript spike.R
p <- file.path(tempdir(), "spike-study")
dir.create(file.path(p, "30_analyses"), recursive = TRUE)
writeLines("library(cli)", file.path(p, "30_analyses", "tp.hz.R"))        # stale template
writeLines(c("Type: Project", "Title: spike", "Depends: jsonlite"),
           file.path(p, "DESCRIPTION"))
run <- function(expr) {
  out <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(expr)),
                 stdout = TRUE, stderr = TRUE, env = "RENV_CONFIG_PAK_ENABLED=TRUE")
  cat(out, sep = "\n"); invisible(out)
}
q <- deparse(p)
# 1. bare init + explicit snapshot records DESCRIPTION deps only
run(paste0("setwd(", q, "); renv::init(bare = TRUE, restart = FALSE); renv::load(", q, "); ",
           "renv::settings$snapshot.type('explicit', project = ", q, "); ",
           "renv::install('jsonlite', project = ", q, ", prompt = FALSE); ",
           "renv::snapshot(project = ", q, ", prompt = FALSE)"))
lock <- jsonlite::read_json(file.path(p, "renv.lock"))
cat("1. jsonlite locked:", "jsonlite" %in% names(lock$Packages),
    "| cli locked (must be FALSE):", "cli" %in% names(lock$Packages), "\n")
# 2. owner/repo install through the pak back end records a GitHub source
run(paste0("renv::load(", q, "); renv::install('ehrlinger/hvtiRutilities', project = ", q,
           ", prompt = FALSE)"))
# 3. restore does not upgrade a locked package
v <- lock$Packages$jsonlite$Version
run(paste0("renv::load(", q, "); renv::restore(project = ", q, ", prompt = FALSE)"))
cat("3. jsonlite still", v, ":", identical(
  jsonlite::read_json(file.path(p, "renv.lock"))$Packages$jsonlite$Version, v), "\n")
# 4. the R version renv records in the lockfile
cat("4. lockfile R:", lock$R$Version, "\n")
```

- [ ] **Step 2: Run it**

Run: `Rscript spike.R 2>&1 | tail -30`
Expected: `1. jsonlite locked: TRUE | cli locked (must be FALSE): FALSE`, the install in 2 finishes without error, `3. jsonlite still <v> : TRUE`, and `4. lockfile R:` prints the running R version.

- [ ] **Step 3: Record the findings**

Write `dev/specs/artifacts/2026-10-20-renv-spike.md` with the date, `packageVersion("renv")`, the four results verbatim, and, for 2, the `Source`/`RemoteRepo` fields of `hvtiRutilities` in the lockfile after a `renv::snapshot()`. If 1, 2 or 3 fails, stop here and report.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/GitHub/hvtiR-spec-env
git add dev/specs/artifacts/2026-10-20-renv-spike.md
git commit -m "spec(setup): renv explicit-mode spike findings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Part A: make every downstream `study_setup()` call explicit

These calls rely on today's defaults (`renv = FALSE`, `cleanup = FALSE`). Passing them explicitly is valid against the current `hvtiRutilities`, so this merges first and keeps downstream CI green when Part B flips the defaults.

### Task 2: `hvtiRtemplates`, explicit arguments and a guard

**Files:**
- Create: `tests/testthat/test-study-setup-explicit.R`
- Modify: every `tests/testthat/*.R` and `R/*.R` example calling `study_setup(` (59 calls; list them with `git grep -n "study_setup(" -- tests R vignettes inst`)
- Create: `news/test-study-setup-explicit-args.md`

Branch: `git -C ~/Documents/GitHub/hvtiRtemplates worktree add ../hvtiRtemplates-explicit -b test/study-setup-explicit-args origin/main`

- [ ] **Step 1: Write the guard test**

```r
# Every study_setup() call in this suite names renv, and names cleanup when it
# names adopt. hvtiRutilities makes renv = TRUE and cleanup = adopt the
# defaults: a call that relied on the old ones would start a real renv
# environment for every temporary study, or stop for want of the template
# corpus, which exists only on the analysis server.
calls_to <- function(e, fn) {
  found <- list()
  walk <- function(x) {
    if (is.call(x)) {
      head <- x[[1L]]
      name <- if (is.symbol(head)) {
        as.character(head)
      } else if (is.call(head) && identical(head[[1L]], as.symbol("::"))) {
        as.character(head[[3L]])
      } else {
        ""
      }
      if (identical(name, fn)) found[[length(found) + 1L]] <<- x
      for (arg in as.list(x)[-1L]) if (!identical(arg, quote(expr = ))) walk(arg)
    } else if (is.expression(x) || is.pairlist(x)) {
      for (arg in as.list(x)) if (!identical(arg, quote(expr = ))) walk(arg)
    }
  }
  walk(e)
  found
}

test_that("every study_setup() call in the tests is explicit about renv and cleanup", {
  files <- list.files(test_path(), pattern = "[.]R$", full.names = TRUE)
  bad <- character(0)
  for (file in files) {
    for (call in calls_to(parse(file, keep.source = FALSE), "study_setup")) {
      args <- names(as.list(call))[-1L]
      if (!"renv" %in% args || ("adopt" %in% args && !"cleanup" %in% args)) {
        bad <- c(bad, paste0(basename(file), ": ", paste(deparse(call), collapse = " ")))
      }
    }
  }
  expect(length(bad) == 0L, paste(c("implicit study_setup() calls:", bad), collapse = "\n"))
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "study-setup-explicit")'`
Expected: FAIL listing the implicit calls (helper-bd.R, helper-hazard.R, helper-lm.R, ...). The guard file itself contains no call, so it does not list itself.

- [ ] **Step 3: Add the arguments**

To every `study_setup()` call in `tests/testthat/`, add `renv = FALSE`, and `cleanup = FALSE` where it passes `adopt`. Example, `helper-bd.R:41`:

```r
  suppressMessages(hvtiRutilities::study_setup(root, study = "bd test", study_tracker_id = 9L,
                                               adopt = TRUE, cleanup = FALSE, renv = FALSE))
```

Then the roxygen examples (`R/add-job.R:117`, `R/job-data.R:736`, `R/migrate-job.R:91`, `R/open-job.R:29`, `R/render-job.R:48`, `R/upgrade-job.R:70`): add `renv = FALSE` (and `cleanup = FALSE` with `adopt`). Leave `R/add-job.R:258` and `R/study-root.R:10` alone; they are message strings.

- [ ] **Step 4: Verify the examples by grep, since the guard reads tests only**

Run: `git grep -n "study_setup(" -- R | grep -v "renv = FALSE" | grep -v '"'`
Expected: no output except multi-line calls whose `renv = FALSE` sits on a following line; open each remaining hit and confirm by eye.

- [ ] **Step 5: Run the guard and the suite**

Run: `Rscript -e 'devtools::document(); devtools::test()'`
Expected: guard PASS; whole suite PASS with the same skip count as `main` (`SKIP 0` on macOS).

- [ ] **Step 6: News fragment and commit**

`news/test-study-setup-explicit-args.md`:

```markdown
* Tests and examples pass `renv` and `cleanup` to `hvtiRutilities::study_setup()` explicitly, ahead of
  `hvtiRutilities` turning both on by default. A new test fails on any call that leaves them implicit.
```

```bash
git add tests/testthat news/test-study-setup-explicit-args.md R man
git commit -m "test: pass renv and cleanup to study_setup() explicitly

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Check, review, PR**

Run `devtools::check()` (0/0/0), `/code-review`, then `gh pr create --base main`. Body notes it must merge before the `hvtiRutilities` defaults PR.

### Task 3: `hvtiRdatabuild`, the same

**Files:**
- Create: `tests/testthat/test-study-setup-explicit.R` (the same file as Task 2 Step 1, verbatim)
- Modify: `tests/testthat/helper-analysis-set.R:5`, `R/analysis_set.R:302`, `R/analysis_set.R:454`
- Create: `news/test-study-setup-explicit-args.md`

Branch: `git -C ~/Documents/GitHub/hvtiRdatabuild worktree add ../hvtiRdatabuild-explicit -b test/study-setup-explicit-args origin/main`

- [ ] **Step 1:** Copy the guard test from Task 2 Step 1 verbatim into `tests/testthat/test-study-setup-explicit.R`.
- [ ] **Step 2:** Run `Rscript -e 'devtools::test(filter = "study-setup-explicit")'`. Expected: FAIL naming `helper-analysis-set.R`.
- [ ] **Step 3:** Add `renv = FALSE` (and `cleanup = FALSE` if `adopt` is passed) to the three calls.
- [ ] **Step 4:** Run `Rscript -e 'devtools::document(); devtools::test()'`. Expected: PASS.
- [ ] **Step 5:** News fragment, same text as Task 2 with the package name unchanged (`hvtiRutilities::study_setup()`). Commit:

```bash
git add tests/testthat R man news/test-study-setup-explicit-args.md
git commit -m "test: pass renv and cleanup to study_setup() explicitly

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6:** `devtools::check()`, `/code-review`, PR against `main`.

---

## Part B: `hvtiRutilities`

Branch: `git -C ~/Documents/GitHub/hvtiRutilities worktree add ../hvtiRutilities-env -b feat/study-environment origin/main`. Every task below works in that worktree.

### Task 4: explicit arguments in the package's own tests and examples

**Files:**
- Create: `tests/testthat/test-study-setup-explicit.R` (Task 2 Step 1, verbatim, **minus** `test-study_setup.R`, which tests the defaults themselves: add `files <- setdiff(files, test_path("test-study_setup.R"))` after `list.files()`)
- Modify: the 83 implicit calls under `tests/testthat/` outside `test-study_setup.R`, and the roxygen examples in `R/data_updates.R` (343, 502, 650), `R/provenance.R` (412, 467, 520, 593, 683), `R/register_data.R` (204), plus any other hit of `git grep -n "study_setup(" -- R | grep -v "R/study_setup.R"`

- [ ] **Step 1:** Write the guard test as described. Run `Rscript -e 'devtools::test(filter = "study-setup-explicit")'`. Expected: FAIL listing the helpers and test files.
- [ ] **Step 2:** Add `renv = FALSE` (and `cleanup = FALSE` with `adopt`) to each listed call, and to each roxygen example: `invisible(study_setup(root, study = "Example", study_tracker_id = 1L, renv = FALSE))`.
- [ ] **Step 3:** Run `Rscript -e 'devtools::document(); devtools::test()'`. Expected: PASS, skip count unchanged from `main`.
- [ ] **Step 4: Commit**

```bash
git add tests/testthat R man
git commit -m "test: pass renv and cleanup to study_setup() explicitly

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: `study_declare()`

Writes the study's `DESCRIPTION`, the declaration renv's explicit snapshot reads.

**Files:**
- Create: `R/study_declare.R`
- Create: `tests/testthat/test-study_declare.R`

**Interfaces:**
- Produces: `study_declare(packages = character(0), root = NULL)` (exported). Returns the sorted declared package names, invisibly. Writes `<root>/DESCRIPTION` with `Type: Project`, `Title: <basename(root)>`, `Depends: <names>`. Rewrites only when the set changes. Refuses to edit a `DESCRIPTION` without `Type: Project`.

- [ ] **Step 1: Write the failing tests**

```r
test_that("study_declare writes a project DESCRIPTION", {
  root <- withr::local_tempdir()
  out <- study_declare(c("hvtiRutilities", "arrow"), root)
  expect_identical(out, c("arrow", "hvtiRutilities"))
  dcf <- read.dcf(file.path(root, "DESCRIPTION"))
  expect_identical(unname(dcf[1L, "Type"]), "Project")
  expect_identical(unname(dcf[1L, "Depends"]), "arrow, hvtiRutilities")
})

test_that("study_declare adds to what is declared and never removes", {
  root <- withr::local_tempdir()
  study_declare("arrow", root)
  out <- study_declare("randomForestSRC", root)
  expect_identical(out, c("arrow", "randomForestSRC"))
})

test_that("study_declare leaves the file alone when nothing changes", {
  root <- withr::local_tempdir()
  study_declare("arrow", root)
  path <- file.path(root, "DESCRIPTION")
  before <- file.mtime(path)
  Sys.sleep(1.1)
  study_declare("arrow", root)
  expect_identical(file.mtime(path), before)
})

test_that("study_declare with no packages writes an empty declaration", {
  root <- withr::local_tempdir()
  expect_identical(study_declare(root = root), character(0))
  expect_true(file.exists(file.path(root, "DESCRIPTION")))
})

test_that("study_declare refuses a package DESCRIPTION", {
  root <- withr::local_tempdir()
  writeLines(c("Package: foo", "Version: 1.0.0"), file.path(root, "DESCRIPTION"))
  expect_error(study_declare("arrow", root), "not a study project DESCRIPTION")
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "study_declare")'`
Expected: FAIL, `could not find function "study_declare"`.

- [ ] **Step 3: Implement**

```r
#' Declare the packages a study needs
#'
#' @description
#' Records package names in the study's \code{DESCRIPTION}, the file renv reads
#' to build the study's \code{renv.lock} in explicit mode. Declaring rather than
#' letting renv scan the code means a stale template copy can never put a
#' package into the lockfile.
#'
#' Names are only ever added. The file is rewritten only when the set changes,
#' and a \code{DESCRIPTION} that is not a study project's (no
#' \code{Type: Project}) is never edited.
#'
#' @param packages Character. Package names to declare.
#' @param root Character(1). The study root; by default the study enclosing the
#'   working directory, as \code{\link{study_root}} finds it.
#' @return The sorted declared package names, invisibly.
#' @export
#' @examples
#' root <- file.path(tempdir(), "declare-example")
#' dir.create(root, showWarnings = FALSE)
#' study_declare("arrow", root)
study_declare <- function(packages = character(0), root = NULL) {
  root <- if (is.null(root)) study_root() else normalizePath(root, mustWork = TRUE)
  path <- file.path(root, "DESCRIPTION")
  have <- character(0)
  if (file.exists(path)) {
    dcf <- read.dcf(path)
    if (!"Type" %in% colnames(dcf) || !identical(unname(dcf[1L, "Type"]), "Project")) {
      stop("study_declare(): ", path, " is not a study project DESCRIPTION (no Type: Project); ",
           "refusing to edit it", call. = FALSE)
    }
    if ("Depends" %in% colnames(dcf)) {
      have <- trimws(strsplit(dcf[1L, "Depends"], ",", fixed = TRUE)[[1L]])
      have <- sub("\\s*\\(.*$", "", have[nzchar(have)])
    }
  }
  all <- sort(unique(c(have, packages)))
  if (file.exists(path) && setequal(all, have)) return(invisible(all))
  fields <- matrix(c("Project", basename(root), paste(all, collapse = ", ")), nrow = 1L,
                   dimnames = list(NULL, c("Type", "Title", "Depends")))
  write.dcf(fields, path, width = 80L)
  invisible(all)
}
```

Check `study_root()`'s signature first (`args(hvtiRutilities::study_root)`); if it takes a start directory, the default call above is correct as written.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "study_declare")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/study_declare.R tests/testthat/test-study_declare.R NAMESPACE man/study_declare.Rd
git commit -m "feat(study_declare): declare a study's packages in its DESCRIPTION

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: explicit mode at `renv` initialization, and a wider `.renvignore`

**Files:**
- Modify: `R/study_setup.R` (`.study_renvignore()` at 31-48, `.study_init_renv()` at 247-280)
- Modify: `tests/testthat/test-study_setup.R` (`snapshot_expr()` at ~490)

**Interfaces:**
- Consumes: `study_declare(packages, root)` from Task 5.
- Produces: a study initialized by `study_setup(renv = TRUE)` has a `DESCRIPTION` and `snapshot.type` `"explicit"`.

- [ ] **Step 1: Update the tests**

In `test-study_setup.R`, change `snapshot_expr()` to the expression the code will send:

```r
snapshot_expr <- function(root) {
  project <- deparse(normalizePath(root, winslash = "/"))
  paste0("renv::load(", project, "); renv::settings$snapshot.type('explicit', project = ", project,
         "); renv::snapshot(project = ", project, ", prompt = FALSE)")
}
```

and add:

```r
test_that("renv = TRUE declares the study before initializing it", {
  root <- withr::local_tempdir()
  calls <- new.env()
  local_mocked_bindings(.study_rscript = fake_rscript(calls))
  study_setup(root, "New study", 42L, adopt = TRUE, cleanup = FALSE, renv = TRUE)
  expect_true(file.exists(file.path(root, "DESCRIPTION")))
  expect_identical(unname(read.dcf(file.path(root, "DESCRIPTION"))[1L, "Type"]), "Project")
})

test_that(".renvignore covers template copies outside templates/", {
  expect_true(all(c("tp.*", "old_RF_templates*/") %in% .study_renvignore()))
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "study_setup")'`
Expected: FAIL in the snapshot-expression tests and the two new tests.

- [ ] **Step 3: Implement**

In `.study_renvignore()`, add two entries after `"templates/",`:

```r
    "templates/",
    "old_RF_templates*/",
    "tp.*",
```

In `.study_init_renv()`, declare before init and set explicit mode in the snapshot expression:

```r
  if (!resumable) {
    study_declare(root = root)
    run("renv::init(bare = TRUE, restart = FALSE)", "renv initialization")
  }
  # Explicit mode: renv.lock is built from DESCRIPTION, never by scanning the
  # study's code, so a template copy cleanup missed cannot reach the lockfile.
  project <- deparse(normalizePath(root, winslash = "/"))
  run(paste0("renv::load(", project, "); renv::settings$snapshot.type('explicit', project = ",
             project, "); renv::snapshot(project = ", project, ", prompt = FALSE)"), "renv snapshot")
```

(The resumed path has a `DESCRIPTION` only if it was written by this code; add `study_declare(root = root)` before the snapshot `run()` as well, so a study interrupted by an older version resumes cleanly. `study_declare()` is idempotent.)

Update the `@details` paragraph on `renv = TRUE` in the roxygen block to say the environment is created in explicit mode from the study `DESCRIPTION`.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "study_setup")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/study_setup.R tests/testthat/test-study_setup.R man/study_setup.Rd
git commit -m "feat(study_setup): initialize renv in explicit mode from a study DESCRIPTION

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: the defaults, `cleanup = adopt` and `renv = TRUE`

**Files:**
- Modify: `R/study_setup.R:390-450` (signature, flag validation, corpus check) and after the adopt resolution (~482)
- Modify: `tests/testthat/test-study_setup.R` (the "cleanup is off by default" test at ~448)

**Interfaces:**
- Produces: `study_setup(..., adopt = FALSE, ..., cleanup = adopt, renv = TRUE, template_dir = ...)`. `cleanup`, when not supplied, takes the **final** `adopt`, including an adopt set by the interactive prompt.

- [ ] **Step 1: Write the failing tests**

Replace the "cleanup is off by default" test with:

```r
test_that("cleanup follows adopt when not given", {
  root <- legacy_study()          # the existing fixture used by the cleanup tests
  local_mocked_bindings(.study_rscript = fake_rscript(new.env()))
  study_setup(root, "Legacy study", 42L, adopt = TRUE, template_dir = local_corpus())
  expect_false(file.exists(file.path(root, "analyses/tp.hz.R")))
})

test_that("cleanup = FALSE overrides adopt", {
  root <- legacy_study()
  local_mocked_bindings(.study_rscript = fake_rscript(new.env()))
  study_setup(root, "Legacy study", 42L, adopt = TRUE, cleanup = FALSE)
  expect_true(file.exists(file.path(root, "analyses/tp.hz.R")))
})

test_that("an adopt accepted at the prompt cleans up too", {
  root <- legacy_study()
  study_setup(root, "Legacy study", 42L, adopt = TRUE, cleanup = FALSE, renv = FALSE)
  write_file(root, "analyses/tp.hz.R")   # a template copy arriving after the first setup
  local_mocked_bindings(.study_interactive = function() TRUE,
                        .study_ask_adopt = function(root) TRUE,
                        .study_rscript = fake_rscript(new.env()))
  study_setup(root, "Legacy study", 42L, template_dir = local_corpus())
  expect_false(file.exists(file.path(root, "analyses/tp.hz.R")))
})

test_that("an implied cleanup with no template corpus stops before writing", {
  root <- legacy_study()
  expect_error(study_setup(root, "Legacy study", 42L, adopt = TRUE, renv = FALSE,
                           template_dir = file.path(tempdir(), "no-such-corpus")),
               "template corpus not found")
  expect_false(file.exists(file.path(root, "_study.yml")))
})

test_that("renv is on by default", {
  root <- withr::local_tempdir()
  calls <- new.env()
  local_mocked_bindings(.study_rscript = fake_rscript(calls))
  study_setup(root, "New study", 42L, adopt = TRUE, cleanup = FALSE)
  expect_true(any(grepl("renv::init", calls$exprs, fixed = TRUE)))
})
```

Use the fixture helpers the existing cleanup tests use (`write_file()`, `local_corpus()`, and whatever builds the legacy root, around lines 341-353); if no `legacy_study()` exists, add it there, building the same tree the cleanup tests build inline. The legacy fixture's `_study.yml` must be absent for the "stops before writing" test.

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "study_setup")'`
Expected: FAIL on all five.

- [ ] **Step 3: Implement**

Signature:

```r
study_setup <- function(root = NULL, study, study_tracker_id,
                        umbrella = NULL, owner = NULL,
                        irb_number = NULL, cvir_no = NULL,
                        study_creation_date = NULL, adopt = FALSE,
                        identity_source = c("tracker", "manual"),
                        cleanup = adopt, renv = TRUE,
                        template_dir = "/programs/development/template") {
  # cleanup defaults to the FINAL adopt, which the interactive prompt below may
  # set. Validating it here would force the default with the caller's adopt.
  cleanup_given <- !missing(cleanup)
```

Flag validation loop:

```r
  for (flag in c("adopt", if (cleanup_given) "cleanup", "renv")) {
```

Delete the `if (cleanup) { ... template corpus ... overlap ... }` block from its current place and re-insert it immediately after the adopt prompt resolution (after the closing `}` of `if (identity_exists) { ... adopt <- TRUE }`, before `layout <-`), preceded by the default:

```r
  if (!cleanup_given) cleanup <- adopt
  if (cleanup) {
    template_dir <- .study_scalar(template_dir, "template_dir", required = TRUE)
    if (!dir.exists(template_dir)) {
      stop("study_setup(): template corpus not found at ", template_dir,
           "; pass template_dir, or cleanup = FALSE", call. = FALSE)
    }
    if (.study_paths_overlap(root, template_dir)) {
      stop("study_setup(): the study root and template_dir overlap; cleanup would ",
           "delete the corpus or the study", call. = FALSE)
    }
  }
```

This is still before the first write (`dir.create(root)` follows `layout`).

Roxygen: `@param cleanup` gains "Defaults to \code{adopt}: adopting a study cleans it, including an adoption accepted at the prompt. Pass \code{FALSE} to adopt without cleaning." `@param renv` gains "Defaults to \code{TRUE}; test suites that build temporary studies should pass \code{FALSE}." Point the description at \code{hvtiR::setup()} as the usual entry point.

- [ ] **Step 4: Run the whole suite**

Run: `Rscript -e 'devtools::document(); devtools::test()'`
Expected: PASS. Any new failure elsewhere is an implicit call Task 4 missed; the guard test names it.

- [ ] **Step 5: Mutation check**

Temporarily move `if (!cleanup_given) cleanup <- adopt` above the prompt block; run `devtools::test(filter = "study_setup")`. Expected: "an adopt accepted at the prompt cleans up too" FAILS. Revert.

- [ ] **Step 6: Commit**

```bash
git add R/study_setup.R tests/testthat/test-study_setup.R man/study_setup.Rd
git commit -m "feat(study_setup): cleanup follows adopt and renv is on by default

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: `study_need()`, install instead of naming the fix

**Files:**
- Create: `R/study_need.R`
- Create: `tests/testthat/test-study_need.R`
- Modify: `R/registered_versions.R:13-26` (`.require_arrow()`), `R/read_clinical_data.R:164-168`
- Modify: `DESCRIPTION` (`renv` into Suggests)
- Modify: any test asserting the old `install.packages("arrow")` text: `git grep -n 'install.packages' -- tests`

**Interfaces:**
- Consumes: `study_declare()`, `.study_interactive()`.
- Produces: `study_need(packages, root = NULL, caller = "study_need", note = NULL, only_in_renv = FALSE)` (exported). Returns the names it installed, invisibly. In an active renv study: declares all `packages`; missing ones are installed after one yes/no when interactive, then snapshotted; otherwise stops naming `hvtiR::setup()`. With `only_in_renv = TRUE`, does nothing outside an active renv study. Never upgrades.

- [ ] **Step 1: Write the failing tests**

```r
local_need <- function(installed = character(0), renv_root = NULL, interactive = FALSE,
                       answer = TRUE, env = parent.frame()) {
  state <- new.env()
  state$installed <- installed
  state$asked <- 0L
  state$snapshots <- 0L
  local_mocked_bindings(
    .package_installed = function(pkg) pkg %in% state$installed,
    .need_root = function(root) renv_root,
    .renv_active = function(root) !is.null(renv_root),
    .study_interactive = function() interactive,
    .need_ask = function(pkgs, caller) { state$asked <- state$asked + 1L; answer },
    .need_install = function(pkgs, root) state$installed <- c(state$installed, pkgs),
    .need_snapshot = function(root) state$snapshots <- state$snapshots + 1L,
    .env = env
  )
  state
}

test_that("an installed package needs nothing", {
  state <- local_need(installed = "arrow")
  expect_identical(study_need("arrow"), character(0))
  expect_identical(state$asked, 0L)
})

test_that("in a renv study, interactively, a missing package is installed and locked", {
  root <- withr::local_tempdir()
  state <- local_need(renv_root = root, interactive = TRUE)
  expect_identical(study_need("arrow", caller = "register_data"), "arrow")
  expect_identical(state$snapshots, 1L)
  expect_match(readLines(file.path(root, "DESCRIPTION")), "arrow", all = FALSE)
})

test_that("declining the install stops and names setup()", {
  root <- withr::local_tempdir()
  local_need(renv_root = root, interactive = TRUE, answer = FALSE)
  expect_error(study_need("arrow", caller = "register_data"), "register_data\\(\\).*hvtiR::setup\\(\\)")
})

test_that("outside renv a missing package stops and names setup(), with the note", {
  local_need()
  expect_error(study_need("arrow", caller = "register_data", note = "Nothing was written."),
               "hvtiR::setup\\(\\).*Nothing was written")
})

test_that("only_in_renv does nothing outside a renv study", {
  state <- local_need()
  expect_identical(study_need("randomForestSRC", only_in_renv = TRUE), character(0))
  expect_identical(state$asked, 0L)
})

test_that("an install that leaves the package missing stops", {
  root <- withr::local_tempdir()
  state <- local_need(renv_root = root, interactive = TRUE)
  local_mocked_bindings(.need_install = function(pkgs, root) invisible(NULL))
  expect_error(study_need("arrow"), "did not install")
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "study_need")'`
Expected: FAIL, `could not find function "study_need"`.

- [ ] **Step 3: Implement**

```r
#' Install a package a study needs, or say how
#'
#' @description
#' Called where a function needs a package the study may not have, such as
#' \pkg{arrow} for registered data. In the study's active renv project the
#' packages are declared (see \code{\link{study_declare}}); a missing one is
#' installed into the study's library after one question, when the session is
#' interactive, and recorded in \code{renv.lock}. Otherwise the call stops and
#' names \code{hvtiR::setup()}, which installs everything a study needs.
#'
#' An installed package is never upgraded, whatever its version: moving a
#' study's package versions is \code{hvtiR::update()}'s job.
#'
#' @param packages Character. Package names.
#' @param root Character(1). The study root; by default the study enclosing the
#'   working directory, if any.
#' @param caller Character(1). The function that needs the packages, named in
#'   the question and the error.
#' @param note Character(1) or \code{NULL}. Appended to the error.
#' @param only_in_renv Logical(1). Do nothing outside an active renv study.
#' @return The names of the packages installed, invisibly.
#' @export
study_need <- function(packages, root = NULL, caller = "study_need", note = NULL,
                       only_in_renv = FALSE) {
  root <- .need_root(root)
  in_renv <- !is.null(root) && .renv_active(root)
  if (only_in_renv && !in_renv) return(invisible(character(0)))
  if (in_renv) study_declare(packages, root)
  missing <- packages[!vapply(packages, .package_installed, logical(1))]
  if (!length(missing)) return(invisible(character(0)))
  if (in_renv && .study_interactive() && isTRUE(.need_ask(missing, caller))) {
    .need_install(missing, root)
    still <- missing[!vapply(missing, .package_installed, logical(1))]
    if (length(still)) {
      stop(caller, "(): ", paste(still, collapse = ", "), " did not install; run hvtiR::setup() ",
           "in the study project", call. = FALSE)
    }
    .need_snapshot(root)
    return(invisible(missing))
  }
  stop(caller, "(): needs ", paste(missing, collapse = ", "), ", which is not installed",
       if (in_renv) " in this study's library" else "",
       ". Run hvtiR::setup() in the study project to install everything the study needs",
       if (in_renv) ", or run this again interactively to install only this" else "", ".",
       if (!is.null(note)) paste0(" ", note) else "", call. = FALSE)
}

.package_installed <- function(pkg) nzchar(system.file(package = pkg))

.need_root <- function(root) {
  if (!is.null(root)) return(normalizePath(root, mustWork = TRUE))
  tryCatch(study_root(), error = function(e) NULL)
}

.renv_active <- function(root) {
  project <- Sys.getenv("RENV_PROJECT", "")
  nzchar(project) && identical(normalizePath(project, winslash = "/", mustWork = FALSE),
                               normalizePath(root, winslash = "/", mustWork = FALSE))
}

.need_ask <- function(pkgs, caller) {
  utils::askYesNo(paste0(caller, "() needs ", paste(pkgs, collapse = ", "),
                         ". Install into this study's library and record it in renv.lock?"),
                  default = TRUE)
}

.need_install <- function(pkgs, root) renv::install(pkgs, project = root, prompt = FALSE)

.need_snapshot <- function(root) renv::snapshot(project = root, prompt = FALSE)
```

`DESCRIPTION`: add `renv` to Suggests, alphabetically.

`.require_arrow()` becomes:

```r
.require_arrow <- function(caller, action = c("register", "read")) {
  action <- match.arg(action)
  if (!.arrow_available()) {
    study_need("arrow", caller = caller,
               note = if (action == "register") "Nothing was written." else NULL)
  }
  invisible(TRUE)
}
```

`read_clinical_data.R`, the parquet branch:

```r
    parquet  = {
      study_need("arrow", caller = "read_clinical_data")
      arrow::read_parquet(file, mmap = FALSE)
    },
```

Update any test that matched the old `install.packages("arrow")` text to match `hvtiR::setup\\(\\)` instead.

- [ ] **Step 4: Run the suite**

Run: `Rscript -e 'devtools::document(); devtools::test()'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/study_need.R R/registered_versions.R R/read_clinical_data.R DESCRIPTION NAMESPACE \
  man/study_need.Rd tests/testthat
git commit -m "feat(study_need): install a missing package into the study instead of naming it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: release the part

- [ ] **Step 1:** `news/feat-study-environment.md`:

```markdown
* `study_setup()` now cleans up template copies whenever it adopts a study (`cleanup` defaults to `adopt`,
  including an adoption accepted at the prompt) and sets up renv by default (`renv = TRUE`). Adopting a study
  where the template corpus is absent now stops unless `template_dir` is given or `cleanup = FALSE`.
* renv environments are created in explicit mode: `renv.lock` is built from the study's `DESCRIPTION`, never by
  scanning its code, so stale template copies cannot add packages to it. `.renvignore` also covers `tp.*` and
  `old_RF_templates*/` for studies set up before.
* New `study_declare()` records the packages a study needs in its `DESCRIPTION`.
* New `study_need()` installs a missing package such as arrow into the study's library and records it, instead
  of stopping with an `install.packages()` line. Outside a renv study it names `hvtiR::setup()`.
```

- [ ] **Step 2:** `devtools::check()` with manual and vignettes: 0/0/0. Read the `testthat` summary line for the skip count.
- [ ] **Step 3:** Commit the fragment, `/code-review`, push, `gh pr create --base main`. The body states Part A's PRs merged first (link them), and that `hvtiR` and `hvtiRtemplates` will move their floors to the version this releases under.

---

## Part C: `hvtiRtemplates`, `add_job()` brings its template's packages

Branch: `worktree add ../hvtiRtemplates-addjob -b feat/add-job-declares-packages origin/main`, after Part B is released and tagged.

### Task 10: read a template's packages

**Files:**
- Create: `R/template-packages.R`
- Create: `tests/testthat/test-template-packages.R`

**Interfaces:**
- Produces: `.template_packages(file)` returns `data.frame(package = character, floor = character)`, one row per package the `setup` chunk attaches with `library()` or version-checks with `utils::packageVersion("<pkg>") < "<floor>"`; `floor` is `NA` when none is stated.

- [ ] **Step 1: Write the failing tests**

```r
test_that("the rfc-fit template's setup chunk yields its packages and floors", {
  pkgs <- .template_packages(template_path("rfc", qualifier = "fit"))
  expect_identical(pkgs$package, c("randomForestSRC", "ggRandomForests", "hvtiRutilities"))
  expect_identical(pkgs$floor, c("3.7.0", "4.0.0", NA))
})

test_that("every shipped template's setup chunk names at least one package", {
  files <- template_list()$file
  for (file in files) {
    pkgs <- .template_packages(file)
    expect(nrow(pkgs) > 0L, paste("no packages read from", basename(file)))
    expect_false(anyNA(pkgs$package))
  }
})

test_that("a template with no setup chunk is an error", {
  file <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("```{r}", "x <- 1", "```"), file)
  expect_error(.template_packages(file), "no setup chunk")
})
```

Check `template_list()`'s file column name and `template_path()`'s signature with `args()` before running; adjust the two calls if they differ.

- [ ] **Step 2:** Run `Rscript -e 'devtools::test(filter = "template-packages")'`. Expected: FAIL, function not found.

- [ ] **Step 3: Implement**

```r
# The packages a template's setup chunk attaches and the version floors it
# checks: the one place a template states what it needs, read rather than
# copied into a second list that would drift from it.
.template_packages <- function(file) {
  lines <- readLines(file, warn = FALSE)
  start <- grep("^#\\|\\s*label:\\s*setup\\s*$", lines)[1L]
  if (is.na(start)) stop("no setup chunk in ", file, call. = FALSE)
  end <- start + grep("^```\\s*$", lines[-seq_len(start)])[1L]
  chunk <- lines[start:end]
  attached <- sub("^\\s*library\\(([A-Za-z0-9.]+)\\).*$", "\\1",
                  grep("^\\s*library\\([A-Za-z0-9.]+\\)", chunk, value = TRUE))
  hits <- regmatches(chunk, regexec('packageVersion\\("([A-Za-z0-9.]+)"\\)\\s*<\\s*"([0-9.-]+)"', chunk))
  hits <- hits[lengths(hits) == 3L]
  floor_pkg <- vapply(hits, `[[`, character(1), 2L)
  floor_val <- vapply(hits, `[[`, character(1), 3L)
  package <- unique(c(attached, floor_pkg))
  data.frame(package = package, floor = floor_val[match(package, floor_pkg)],
             stringsAsFactors = FALSE)
}
```

- [ ] **Step 4:** Run the filter again. Expected: PASS. If a shipped template fails "names at least one package", read its setup chunk: it is either a template attaching packages some other way (fix the parser to read it) or one with no `library()` call (record why in the test with an explicit exclusion).

- [ ] **Step 5: Commit**

```bash
git add R/template-packages.R tests/testthat/test-template-packages.R
git commit -m "feat: read a template's packages from its setup chunk

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 11: `add_job()` calls `study_need()`

**Files:**
- Modify: `R/add-job.R` (before the `file.copy()` at ~197), its roxygen
- Modify: `DESCRIPTION` (`hvtiRutilities (>= <Part B's version>)`)
- Modify: `tests/testthat/test-add-job.R`
- Create: `news/feat-add-job-declares-packages.md`

**Interfaces:**
- Consumes: `.template_packages()` (Task 10); `hvtiRutilities::study_need(packages, root, caller, only_in_renv = TRUE)` (Task 8).

- [ ] **Step 1: Write the failing tests**

```r
test_that("add_job asks the study for the template's packages before writing", {
  root <- make_study()            # the helper the other add_job tests use
  seen <- NULL
  local_mocked_bindings(
    study_need = function(packages, root, caller, only_in_renv, ...) {
      seen <<- list(packages = packages, caller = caller, only_in_renv = only_in_renv)
      invisible(character(0))
    },
    .package = "hvtiRutilities"
  )
  add_job("rfc", "dead", "rfc", dir = root, qualifier = "fit")
  expect_identical(seen$packages, c("randomForestSRC", "ggRandomForests", "hvtiRutilities"))
  expect_identical(seen$caller, "add_job")
  expect_true(seen$only_in_renv)
})

test_that("add_job writes nothing when the study cannot get the packages", {
  root <- make_study()
  local_mocked_bindings(study_need = function(...) stop("add_job(): needs randomForestSRC"),
                        .package = "hvtiRutilities")
  expect_error(add_job("rfc", "dead", "rfc", dir = root, qualifier = "fit"), "needs randomForestSRC")
  expect_length(list.files(root, pattern = "rfc", recursive = TRUE), 0L)
})
```

Use the study-building helper `test-add-job.R` already uses at lines 77 and 96 in place of `make_study()`.

- [ ] **Step 2:** Run `Rscript -e 'devtools::test(filter = "add-job")'`. Expected: the two new tests FAIL.

- [ ] **Step 3: Implement**

In `add_job()`, after the refuse-to-overwrite loop and before `file.copy(row$file[[1L]], out, ...)`:

```r
  # The template's packages, before anything is written: in the study's renv
  # project a missing one is installed and recorded, and a refusal leaves the
  # study as it was. Outside a renv project (a test's temporary study) this
  # does nothing, and the job's own setup chunk reports a missing package at
  # render time.
  needs <- .template_packages(row$file[[1L]])
  hvtiRutilities::study_need(needs$package, root = dir, caller = "add_job", only_in_renv = TRUE)
```

Roxygen `@details`: one sentence saying the job's packages are installed into the study's library when it is a renv project. `DESCRIPTION`: raise the `hvtiRutilities` floor to Part B's released version.

- [ ] **Step 4:** Run `Rscript -e 'devtools::document(); devtools::test()'`. Expected: PASS, `SKIP 0` on macOS.

- [ ] **Step 5:** Mutation check: comment out the `study_need()` line, rerun the filter, confirm both new tests FAIL, restore.

- [ ] **Step 6:** News fragment:

```markdown
* `add_job()` installs the packages a template needs into the study's library, and records them in
  `renv.lock`, when the study is a renv project. It asks first, and writes nothing if the packages cannot be had.
```

Commit, `devtools::check()` 0/0/0, `/code-review`, PR.

```bash
git add R/add-job.R R/template-packages.R DESCRIPTION man tests/testthat news/feat-add-job-declares-packages.md
git commit -m "feat(add_job): install the template's packages into the study

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Part D: `hvtiR`

Branch: `git -C ~/Documents/GitHub/hvtiR worktree add ../hvtiR-setup -b feat/setup origin/main`, after Part B is released.

### Task 12: what a study declares

**Files:**
- Create: `R/setup.R`
- Create: `tests/testthat/test-setup.R`

**Interfaces:**
- Produces: `environment_extras()` returns `c("arrow")`. `declared_packages(registry = members())` returns `c("hvtiR", registry$package, environment_extras())`. `install_specs(packages, registry = members())` maps members and `hvtiR` to `"owner/repo"` and leaves other names unchanged.

- [ ] **Step 1: Write the failing tests**

```r
test_that("a study declares hvtiR, every member and the extras", {
  pkgs <- declared_packages()
  expect_identical(pkgs[1L], "hvtiR")
  expect_true(all(members()$package %in% pkgs))
  expect_true("arrow" %in% pkgs)
})

test_that("install_specs sends members to GitHub and leaves others to the repositories", {
  specs <- install_specs(c("hvtiR", "hvtiRutilities", "arrow"))
  expect_identical(specs, c(SELF_REPO, "ehrlinger/hvtiRutilities", "arrow"))
})
```

- [ ] **Step 2:** Run `Rscript -e 'devtools::test(filter = "setup")'`. Expected: FAIL, functions not found.

- [ ] **Step 3: Implement** (top of `R/setup.R`)

```r
#' Packages a study needs beyond the members
#'
#' Suggested packages that members' study-facing functions use: `arrow` reads
#' and writes registered data. Kept here, beside [members()], so one place owns
#' the list.
#'
#' @return A character vector of package names.
#' @noRd
environment_extras <- function() {
  c("arrow")
}

#' Every package a study declares
#' @param registry The registry, as returned by [members()].
#' @return A character vector: `hvtiR`, the members, then the extras.
#' @noRd
declared_packages <- function(registry = members()) {
  c("hvtiR", registry$package, environment_extras())
}

#' Install specs for declared packages
#' @param packages Character vector of package names.
#' @param registry The registry, as returned by [members()].
#' @return `packages` with `hvtiR` and members as `"owner/repo"`.
#' @noRd
install_specs <- function(packages, registry = members()) {
  repos <- c(hvtiR = SELF_REPO, stats::setNames(registry$repo, registry$package))
  unname(ifelse(packages %in% names(repos), repos[packages], packages))
}
```

If `stats` is not already used, write `setNames` via `names<-` instead to keep Imports at `cli, utils`:

```r
  repos <- c(SELF_REPO, registry$repo)
  names(repos) <- c("hvtiR", registry$package)
```

- [ ] **Step 4:** Run the filter. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R
git commit -m "feat(setup): the packages a study declares

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 13: `doctor()` sees broken libraries and a different R

**Files:**
- Modify: `R/status.R` (new helpers beside `renv_state()`; two checks in `doctor()`'s Environment section, after the renv lines)
- Modify: `tests/testthat/test-doctor.R`

**Interfaces:**
- Produces: `unresolved_imports(packages, lib.loc = .libPaths())` returns `data.frame(package, missing)`, one row per hard dependency of an installed package that is not found on `lib.loc` (base packages excluded; uninstalled `packages` skipped). `lockfile_r_version(root)` returns the R version string `renv.lock` records, or `NA_character_`.

- [ ] **Step 1: Write the failing tests**

```r
test_that("unresolved_imports names an installed package's missing dependency", {
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "fakepkg"))
  writeLines(c("Package: fakepkg", "Version: 1.0.0", "Imports: utils, nosuchpkgxyz (>= 1.0)"),
             file.path(lib, "fakepkg", "DESCRIPTION"))
  out <- unresolved_imports(c("fakepkg", "notinstalled"), lib.loc = c(lib, .Library))
  expect_identical(out$package, "fakepkg")
  expect_identical(out$missing, "nosuchpkgxyz")
})

test_that("lockfile_r_version reads the R block, not a package version", {
  root <- withr::local_tempdir()
  writeLines(c('{', '  "R": {', '    "Version": "4.6.1",', '    "Repositories": [', '      {"Name": "CRAN"}',
               '    ]', '  },', '  "Packages": {"renv": {"Version": "1.2.4"}}', '}'),
             file.path(root, "renv.lock"))
  expect_identical(lockfile_r_version(root), "4.6.1")
  expect_identical(lockfile_r_version(withr::local_tempdir()), NA_character_)
})

test_that("doctor reports a member whose dependency is missing", {
  local_mocked_bindings(
    fetch_description = function(...) NULL,
    unresolved_imports = function(...) data.frame(package = "hvtiRutilities", missing = "digest"),
    lockfile_r_version = function(...) NA_character_
  )
  out <- capture.output(doctor(remote = FALSE))
  expect_match(out, "hvtiRutilities.*digest", all = FALSE)
  expect_match(out, "hvtiR::setup", all = FALSE)
})

test_that("doctor warns when the study's lockfile was made under another R", {
  withr::local_envvar(RENV_PROJECT = withr::local_tempdir())
  local_mocked_bindings(
    fetch_description = function(...) NULL,
    unresolved_imports = function(...) data.frame(package = character(), missing = character()),
    lockfile_r_version = function(...) "4.4.1"
  )
  out <- capture.output(doctor(remote = FALSE))
  expect_match(out, "4[.]4[.]1", all = FALSE)
})
```

- [ ] **Step 2:** Run `Rscript -e 'devtools::test(filter = "doctor")'`. Expected: the four new tests FAIL.

- [ ] **Step 3: Implement** (in `R/status.R`, after `renv_state()`)

```r
#' Hard dependencies of installed packages that cannot be found
#'
#' A member that loads from one library while its Imports sit in another
#' fails with "there is no package called ...". That is a library-path fault,
#' and installing the named package by hand hides it.
#'
#' @param packages Character vector of package names; uninstalled ones are
#'   skipped.
#' @param lib.loc Library paths to search.
#' @return A data frame with character columns `package` and `missing`.
#' @noRd
unresolved_imports <- function(packages, lib.loc = .libPaths()) {
  base <- rownames(utils::installed.packages(lib.loc = .Library, priority = "base"))
  found <- function(p) length(find.package(p, lib.loc = lib.loc, quiet = TRUE)) > 0L
  rows <- lapply(packages, function(p) {
    path <- find.package(p, lib.loc = lib.loc, quiet = TRUE)
    if (!length(path)) return(NULL)
    dcf <- read.dcf(file.path(path[1L], "DESCRIPTION"), fields = c("Depends", "Imports", "LinkingTo"))
    deps <- trimws(sub("\\(.*$", "", unlist(strsplit(dcf[!is.na(dcf)], ",", fixed = TRUE))))
    deps <- setdiff(deps[nzchar(deps)], c("R", base))
    gone <- deps[!vapply(deps, found, logical(1))]
    if (length(gone)) data.frame(package = p, missing = gone, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) data.frame(package = character(), missing = character()) else out
}

#' The R version a study's renv.lock records
#'
#' Read with a pattern rather than a JSON parser, keeping Imports at cli and
#' utils. renv writes `"Version"` first inside the `"R"` block.
#'
#' @param root The study root.
#' @return A version string, or `NA_character_` when there is no lockfile.
#' @noRd
lockfile_r_version <- function(root) {
  path <- file.path(root, "renv.lock")
  if (!file.exists(path)) return(NA_character_)
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  hit <- regmatches(text, regexec('"R"\\s*:\\s*\\{[^}]*?"Version"\\s*:\\s*"([^"]+)"', text, perl = TRUE))[[1L]]
  if (length(hit) == 2L) hit[2L] else NA_character_
}
```

In `doctor()`, after the renv `if/else` block and before `if (remote)`:

```r
    gone <- unresolved_imports(c("hvtiR", members()$package))
    for (i in seq_len(nrow(gone))) {
      cli::cli_alert_danger(
        "{.pkg {gone$package[i]}} is installed, but its dependency {.pkg {gone$missing[i]}} is not on this library path"
      )
    }
    if (nrow(gone)) {
      cli::cli_alert_info("Run {.code hvtiR::setup()} in the study project; do not install these one at a time.")
    }

    project <- Sys.getenv("RENV_PROJECT", "")
    locked_r <- if (nzchar(project)) lockfile_r_version(project) else NA_character_
    if (!is.na(locked_r) && !identical(locked_r, as.character(current))) {
      cli::cli_alert_warning(
        "This study's {.file renv.lock} was made under R {locked_r}; this session runs R {current}."
      )
    }
```

Roxygen for `doctor()`: add a sentence naming the two checks.

- [ ] **Step 4:** Run the filter. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add R/status.R tests/testthat/test-doctor.R man/doctor.Rd
git commit -m "feat(doctor): report unresolved dependencies and a lockfile made under another R

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 14: `setup()`

**Files:**
- Modify: `R/setup.R`, `tests/testthat/test-setup.R`, `DESCRIPTION` (`rstudioapi` into Suggests)

**Interfaces:**
- Consumes: `declared_packages()`, `install_specs()` (Task 12); `unresolved_imports()`, `lockfile_r_version()` (Task 13); `install_members()`, `expand_targets()`, `installed_version()`, `MIN_R_VERSION` (existing); `hvtiRutilities::study_setup()`, `study_declare()`, `study_root()` (Part B), reached through `utilities_fn()`.
- Produces: exported `setup(study, study_tracker_id, root = NULL, adopt = FALSE, ...)`, returning `study_setup()`'s status, invisibly. Seams for tests: `utilities_fn(name)`, `run_in_study(expr, root)`, `set_workspace_prefs()`, `open_project(root)`.

- [ ] **Step 1: Write the failing tests**

```r
local_setup <- function(run_status = 0L, gone = data.frame(package = character(), missing = character()),
                        locked_r = NA_character_, env = parent.frame()) {
  log <- new.env()
  log$steps <- character(0)
  step <- function(x) log$steps <- c(log$steps, x)
  fns <- list(
    study_root = function(...) stop("no study"),
    study_setup = function(...) { log$setup_args <- list(...); step("study_setup"); structure(list(), class = "x") },
    study_declare = function(packages, root) { log$declared <- packages; step("declare") }
  )
  local_mocked_bindings(
    utilities_fn = function(name) fns[[name]],
    run_in_study = function(expr, root) { log$expr <- expr; step("run")
      list(status = run_status, output = "installing\nHVTIR_LIB=/tmp/lib\n") },
    unresolved_imports = function(...) gone,
    lockfile_r_version = function(...) locked_r,
    set_workspace_prefs = function() step("prefs"),
    open_project = function(root) step("open"),
    .env = env
  )
  log
}

test_that("setup runs prefs, study_setup, declare, install, then hands over", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  expect_identical(log$steps, c("prefs", "study_setup", "declare", "run", "open"))
})

test_that("setup turns renv on and leaves cleanup to follow adopt", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root, adopt = TRUE)
  expect_true(log$setup_args$renv)
  expect_true(log$setup_args$adopt)
  expect_false("cleanup" %in% names(log$setup_args))
})

test_that("setup passes cleanup through when given", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root, adopt = TRUE, cleanup = FALSE)
  expect_false(log$setup_args$cleanup)
})

test_that("the install restores, then installs only what the lockfile lacks, then snapshots", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  at <- function(s) regexpr(s, log$expr, fixed = TRUE)
  expect_true(at("snapshot.type('explicit'") < at("renv::restore("))
  expect_true(at("renv::restore(") < at("renv::install("))
  expect_true(at("renv::install(") < at("renv::snapshot("))
  expect_match(log$expr, "ehrlinger/hvtiRutilities", fixed = TRUE)
})

test_that("a failed install stops with the child's output", {
  root <- withr::local_tempdir()
  local_setup(run_status = 1L)
  expect_error(setup("A study", 7L, root = root), "installing")
})

test_that("a package whose dependency is still missing stops", {
  root <- withr::local_tempdir()
  local_setup(gone = data.frame(package = "hvtiRutilities", missing = "digest"))
  expect_error(setup("A study", 7L, root = root), "digest")
})

test_that("a lockfile made under another R warns before anything runs", {
  root <- withr::local_tempdir()
  local_setup(locked_r = "4.4.1")
  expect_message(setup("A study", 7L, root = root), "4[.]4[.]1")
})
```

- [ ] **Step 2:** Run `Rscript -e 'devtools::test(filter = "setup")'`. Expected: new tests FAIL, `setup` not found.

- [ ] **Step 3: Implement** (append to `R/setup.R`)

```r
# The hvtiRutilities release that carries study_declare() and study_need().
# Set to Part B's released version when this merges.
UTILITIES_FLOOR <- "1.5.6"

#' An exported hvtiRutilities function, installing the package first if needed
#'
#' Reached by name rather than through Imports, so hvtiR still installs on a
#' bare machine with only cli and utils.
#' @param name Function name.
#' @return The function.
#' @noRd
utilities_fn <- function(name) {
  version <- installed_version("hvtiRutilities")
  if (is.na(version) || package_version(version) < UTILITIES_FLOOR) {
    install_members(expand_targets("hvtiRutilities"), command = "setup()")
  }
  getExportedValue("hvtiRutilities", name)
}

#' Run R code in a fresh R process in the study
#'
#' The study's library is the target only in a process that loads the
#' project; this session's namespaces came from another library.
#' @param expr R code, one string.
#' @param root The study root.
#' @return A list: `status` (integer) and `output` (one string).
#' @noRd
run_in_study <- function(expr, root) {
  owd <- setwd(root)
  on.exit(setwd(owd), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(expr)),
    stdout = TRUE, stderr = TRUE, env = "RENV_CONFIG_PAK_ENABLED=TRUE"
  ))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else status, output = paste(out, collapse = "\n"))
}

rstudio_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()
}

#' Stop RStudio restoring and saving .RData
#' @return `TRUE` if RStudio preferences were written, invisibly.
#' @noRd
set_workspace_prefs <- function() {
  if (!rstudio_available()) return(invisible(FALSE))
  rstudioapi::writeRStudioPreference("load_workspace", FALSE)
  rstudioapi::writeRStudioPreference("save_workspace", "never")
  cli::cli_alert_success("RStudio will no longer restore or save {.file .RData}.")
  invisible(TRUE)
}

#' Restart into the study project
#' @param root The study root.
#' @noRd
open_project <- function(root) {
  if (rstudio_available()) {
    rstudioapi::openProject(root)
  } else {
    cli::cli_alert_info("Restart R in {.path {root}} to use the study's library.")
  }
  invisible(NULL)
}

#' The child process's install step
#' @param root The study root.
#' @param packages Declared package names.
#' @return One string of R code.
#' @noRd
install_expr <- function(root, packages) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  names_ <- deparse1(packages, width.cutoff = 500L)
  specs <- deparse1(install_specs(packages), width.cutoff = 500L)
  paste0(
    "renv::load(", p, "); ",
    "renv::settings$snapshot.type('explicit', project = ", p, "); ",
    "renv::restore(project = ", p, ", prompt = FALSE); ",
    "locked <- names(renv::lockfile_read(file.path(", p, ", 'renv.lock'))$Packages); ",
    "add <- ", specs, "[!", names_, " %in% locked]; ",
    "if (length(add)) renv::install(add, project = ", p, ", prompt = FALSE); ",
    "renv::snapshot(project = ", p, ", prompt = FALSE); ",
    "cat('\\nHVTIR_LIB=', .libPaths()[1L], '\\n', sep = '')"
  )
}

#' Set up a study's environment
#'
#' The one command a study needs before analysis. In order: checks R and
#' turns off RStudio's `.RData` restore and save; runs
#' `hvtiRutilities::study_setup()` with renv on, which cleans up template
#' copies before renv when adopting; declares `hvtiR`, every member and the
#' packages they need in the study's `DESCRIPTION`; installs them into the
#' study's library in a fresh R process; snapshots; checks that every
#' package's dependencies resolve there; and restarts into the project.
#'
#' A study that already has a `renv.lock` keeps its locked versions: they are
#' restored, and only packages the lockfile lacks are installed. Moving a
#' study's versions is [update()]'s job, and the study owner's decision.
#'
#' Safe to rerun: each step checks before it acts.
#'
#' @param study The Study Tracker title.
#' @param study_tracker_id The Study Tracker ID, an integer.
#' @param root The study root. By default the study enclosing the working
#'   directory, or the working directory.
#' @param adopt Set up an existing study, adding only what is missing.
#'   Adopting cleans up template copies unless `cleanup = FALSE` is passed.
#' @param ... Passed to `hvtiRutilities::study_setup()`, such as `cleanup`,
#'   `template_dir` or `owner`.
#' @return The study status from `hvtiRutilities::study_setup()`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' setup(study = "Study Tracker title", study_tracker_id = 1234L)
#' }
setup <- function(study, study_tracker_id, root = NULL, adopt = FALSE, ...) {
  if (getRversion() < MIN_R_VERSION) {
    cli::cli_abort("R {getRversion()} is below the {MIN_R_VERSION} the family requires.")
  }
  if (is.null(root)) {
    root <- tryCatch(utilities_fn("study_root")(), error = function(e) getwd())
  }
  locked_r <- lockfile_r_version(root)
  if (!is.na(locked_r) && !identical(locked_r, as.character(getRversion()))) {
    cli::cli_alert_warning(
      "This study's {.file renv.lock} was made under R {locked_r}; this session runs R {getRversion()}."
    )
  }
  set_workspace_prefs()

  status <- utilities_fn("study_setup")(
    root = root, study = study, study_tracker_id = study_tracker_id,
    adopt = adopt, renv = TRUE, ...
  )
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)

  packages <- declared_packages()
  utilities_fn("study_declare")(packages, root = root)

  result <- run_in_study(install_expr(root, packages), root)
  if (result$status != 0L) {
    cli::cli_abort(c("Installing the study's packages failed.", x = "{result$output}"))
  }
  lib <- sub("^HVTIR_LIB=", "", grep("^HVTIR_LIB=", strsplit(result$output, "\n")[[1L]], value = TRUE))
  gone <- unresolved_imports(packages, lib.loc = c(lib, .Library))
  if (nrow(gone)) {
    cli::cli_abort(c(
      "Packages in the study's library are missing dependencies:",
      stats::setNames(paste(gone$package, "needs", gone$missing), rep("x", nrow(gone)))
    ))
  }

  cli::cli_alert_success("The study's environment is set up.")
  open_project(root)
  invisible(status)
}
```

(Replace `stats::setNames()` with `names<-` if `stats` is not otherwise used, as in Task 12.) `DESCRIPTION`: add `rstudioapi` to Suggests. `NAMESPACE` via `document()`.

Note: `setup` masks nothing in base, but `devtools`/`usethis` users may have `usethis::setup`-style names attached; it is always called as `hvtiR::setup()` in docs.

- [ ] **Step 4:** Run `Rscript -e 'devtools::document(); devtools::test()'`. Expected: PASS.

- [ ] **Step 5:** Mutation check: in `install_expr()`, move the `renv::install(` clause above `renv::restore(`; rerun the filter; confirm the ordering test FAILS; revert.

- [ ] **Step 6: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R DESCRIPTION NAMESPACE man/setup.Rd
git commit -m "feat(setup): set up a study's environment in one command

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 15: end-to-end run against real renv

Too slow and network-bound for CI (it installs the family into a fresh library), so it runs when `HVTIR_E2E=true`. **Say so in the PR body: CI reports it as a skip by design.**

**Files:**
- Create: `tests/testthat/test-setup-e2e.R`

- [ ] **Step 1: Write the test**

```r
test_that("setup cleans a legacy study before renv and locks only declared packages", {
  skip_if_not(identical(Sys.getenv("HVTIR_E2E"), "true"), "set HVTIR_E2E=true to run")
  skip_on_cran()
  skip_if_not_installed("renv")
  skip_if_not_installed("hvtiRutilities", UTILITIES_FLOOR)

  corpus <- withr::local_tempdir()
  writeLines("corpus", file.path(corpus, "README.txt"))
  root <- file.path(withr::local_tempdir(), "legacy")
  dir.create(file.path(root, "analyses"), recursive = TRUE)
  writeLines("library(somepkgthatdoesnotexist)", file.path(root, "analyses", "tp.hz.R"))
  writeLines("study: legacy", file.path(root, "notes.txt"))

  local_mocked_bindings(set_workspace_prefs = function() invisible(FALSE),
                        open_project = function(root) invisible(NULL))
  setup("Legacy", 1L, root = root, adopt = TRUE, template_dir = corpus)

  expect_false(file.exists(file.path(root, "analyses", "tp.hz.R")))
  lock <- paste(readLines(file.path(root, "renv.lock")), collapse = "\n")
  expect_false(grepl("somepkgthatdoesnotexist", lock, fixed = TRUE))
  expect_true(grepl('"hvtiRutilities"', lock, fixed = TRUE))
  expect_true(grepl('"arrow"', lock, fixed = TRUE))
})
```

- [ ] **Step 2:** Run it: `HVTIR_E2E=true Rscript -e 'devtools::test(filter = "setup-e2e")'`. Expected: PASS (minutes). Record the wall time in the PR body.
- [ ] **Step 3:** Mutation check: in a scratch copy of `hvtiRutilities`, swap the cleanup and renv lines in `study_setup()`, install it into a private library (`R CMD INSTALL -l <lib>`), rerun with `R_LIBS=<lib>`. Expected: the `tp.hz.R` assertion FAILS. Discard the scratch copy.
- [ ] **Step 4: Commit**

```bash
git add tests/testthat/test-setup-e2e.R
git commit -m "test(setup): end-to-end run against real renv, behind HVTIR_E2E

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 16: documentation and release

**Files:**
- Modify: `README.md` and `vignettes/hvtiR.qmd` (the install section)
- Create: `news/feat-setup.md`

- [ ] **Step 1:** In the README and vignette install sections, after the existing `pak::pak("ehrlinger/hvtiR")` line, add a "Set up a study" subsection:

```r
install.packages("pak")
pak::pak("ehrlinger/hvtiR")
hvtiR::setup(
  study = "EDIT: the Study Tracker title",
  study_tracker_id = 0L  # EDIT: the Study Tracker ID
)
```

with two sentences: run it once per study, in the study project, before anything else; it is safe to rerun. Apply the `ehrlinger-writing` voice.

- [ ] **Step 2:** `news/feat-setup.md`:

```markdown
* New `setup()` sets up a study's environment in one command: it cleans up template copies before renv,
  declares the family and the packages it needs, installs them into the study's library, and snapshots.
  A study with a `renv.lock` keeps its locked versions.
* `doctor()` reports a member whose dependencies are not on the library path, and a study lockfile made
  under a different R.
```

- [ ] **Step 3:** Set `UTILITIES_FLOOR` to Part B's released `hvtiRutilities` version. `devtools::check()` with manual and vignettes: 0/0/0. Commit, `/code-review`, PR. The body links Parts A-C and states the E2E test is gated.

---

## After release (not code)

- Rewrite the SharePoint Quick Start's setup section to the three lines in Task 16 Step 1, and drop the `register_data()` arguments it no longer needs. John's document; offer a draft.
- Rebuild the template gallery per the release-day rule if Part C changed template output (it should not).
