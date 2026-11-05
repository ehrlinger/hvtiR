# Robust setup() Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `hvtiR::setup()` heals install failures it can fix safely, leaves out
optional packages it cannot fix, records them, and still finishes with a
usable study. `hvtiRutilities::study_setup()` stops only on identity errors and
decisions.

**Architecture:** Implements
[2026-11-05-robust-setup-design.md](2026-11-05-robust-setup-design.md).

- **Part A, hvtiRutilities.** Three changes to `study_setup()`:
  - a missing template corpus warns and skips cleanup;
  - undeletable files warn;
  - a sound lock without its activation scaffolding is repaired with
    `renv::activate()`.
- **Part B, hvtiR.** A new file `R/heal.R` holds:
  - the failure classifier;
  - a pure per-round decision function, `plan_round()`;
  - the child expressions that record, install and drop;
  - the healing loop, `heal_restore()`;
  - the setup record.

  `R/setup.R` wires it in at three points: the restore, the install of
  non-family packages, and the final dependency check. `doctor()` in
  `R/status.R` reads the record.

**Tech Stack:** R, renv ≥ 1.2.4 in the study (renv 1.3.1 on the dev Mac), pak,
cli, testthat 3 with `local_mocked_bindings()`, withr.

## Global Constraints

- **Order:** Part A first, in `~/Documents/GitHub/hvtiRutilities`, on a branch
  from `origin/main` after John tags the release that merges hvtiRutilities #280.
  Part B in `~/Documents/GitHub/hvtiR-robust-setup`, on the branch
  `feat/robust-setup` from `docs/robust-setup-design`, after John decides draft
  hvtiR #177. That draft also edits `R/setup.R`; rebase on `origin/main` first.
- **Line width:** hvtiR has lintr defaults, 80 characters. hvtiRutilities has a
  `.lintr` at **135** characters.
- **Roxygen:** hvtiR roxygen is markdown, and new internals are `@noRd`.
  hvtiRutilities roxygen follows that repo's existing style in
  `R/study_setup.R`.
- **Versions:** do not bump `Version:` and do not edit `NEWS.md` in either repo.
  Each PR adds `news/<branch with / replaced by ->.md`, bullets only.
- **Staging:** `git add` only the named files, never `-A`.
- **Tests:** run them in each repo with
  `Rscript -e 'devtools::test(filter = "<name>")'`. They are package repos, so
  running on the Mac is allowed. **Nothing is run against `/Volumes/qhsstudies`;**
  the acceptance run (Task B8) is John's, on lri.
- **Essential vs optional (decided):** a failure of `hvtiR` or a family member
  (`members()$package`) stops `setup()` after healing. Anything else is left out
  and recorded.
- **Healing:**
  - Pins move only under `upgrade = TRUE`, only for packages R forced, and to the
    newest version in the **study's configured repositories**: the child sets
    `options(repos = hvtir_repos)` through `repos_expr()`.
  - A package that fails again after its pin moved is not moved again.
  - A round whose failed set equals the previous round's ends healing.
  - The cap is 10 rounds.
- **Lock backup:** `renv.lock` is copied to
  `renv/renv.lock.before-setup-<YYYYMMDD-HHMMSS>` before the first change to it.
- **Plan deviations from the spec, decided here (the spec is amended in the
  same commit):**
  - **(a) The record is DCF, `renv/hvtiR-setup.dcf`, not JSON.** hvtiR imports
    only `cli` and `utils`, because it is the bootstrap package installed before
    anything else, and JSON would add `jsonlite`. `read.dcf()` is base R.
  - **(b) "Essential" is the family names only, not their resolved hard
    dependencies.** A family member whose dependency cannot install fails with
    "dependency 'x' is not available". The member is essential, so the run
    still stops, naming the chain. The effect is the same with no dependency
    resolution in the session.
  - **(c) The install stage degrades but does not heal.** pak installs current
    releases, so there is no pin to move. It tries the non-family packages in
    one call and, on failure, one at a time.

---

## Part A: hvtiRutilities

### Task A1: A missing template corpus warns and skips cleanup

**Files:**
- Modify: `R/study_setup.R` (`study_setup()`, the `if (cleanup) { ... }` block
  after `if (!cleanup_given) cleanup <- adopt`, and the line
  `cleaned <- if (cleanup) .study_cleanup(root, template_dir)`)
- Modify: `tests/testthat/test-study_setup.R` (the tests "an implied cleanup
  with no template corpus stops before writing" and the one around line 688
  that expects `"template corpus not found"`)

**Interfaces:**
- Produces: `attr(status, "cleanup")` is now always a list when cleanup was
  requested:
  `list(status = "done" | "skipped", reason = <chr or NULL>, deleted = <chr>,
  removed_dirs = <chr>, left = <chr>)`. hvtiR (Task B6) reads `status` and
  `left` and must tolerate the older shape (`deleted`, `removed_dirs` only).

- [ ] **Step 1: Create the branch**

```bash
cd ~/Documents/GitHub/hvtiRutilities
git fetch origin && git checkout -b feat/study-setup-degrade origin/main
```

- [ ] **Step 2: Rewrite the two tests to expect a warning (they fail)**

Replace the body of "an implied cleanup with no template corpus stops before
writing". Rename it "an implied cleanup with no template corpus warns and sets
the study up":

```r
test_that("an implied cleanup with no template corpus warns and sets the study up", {
  root <- legacy_study()
  expect_warning(
    status <- study_setup(root, "Legacy study", 42L, adopt = TRUE, renv = FALSE,
                          template_dir = file.path(tempdir(), "no-such-corpus")),
    "template corpus not found"
  )
  expect_true(file.exists(file.path(root, "_study.yml")))
  expect_identical(attr(status, "cleanup")$status, "skipped")
  expect_match(attr(status, "cleanup")$reason, "template corpus not found")
})
```

In the test around line 688, which passes `template_dir = missing` and
`cleanup = TRUE`, replace `expect_error(..., "template corpus not found")` and
the `_study.yml` assertion with:

```r
  expect_warning(
    study_setup(root, "Legacy study", 42L, adopt = TRUE, cleanup = TRUE, template_dir = missing, renv = FALSE),
    "template corpus not found"
  )
  expect_true(file.exists(tp))
  expect_true(file.exists(file.path(root, "_study.yml")))
```

Rename that test so its name says it warns rather than stops.

- [ ] **Step 3: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "study_setup")'`
Expected: both FAIL. `study_setup()` still raises the error.

- [ ] **Step 4: Implement**

In `study_setup()`, replace

```r
  if (cleanup) {
    template_dir <- .study_scalar(template_dir, "template_dir", required = TRUE)
    if (!dir.exists(template_dir)) {
      stop("study_setup(): template corpus not found at ", template_dir,
           "; pass template_dir, or cleanup = FALSE", call. = FALSE)
    }
    if (.study_paths_overlap(root, template_dir)) {
```

with

```r
  skipped <- NULL
  if (cleanup) {
    template_dir <- .study_scalar(template_dir, "template_dir", required = TRUE)
    if (!dir.exists(template_dir)) {
      # Explicit-mode renv does not scan the study, so template copies can no
      # longer reach the lockfile: cleanup is tidiness, not a reason to stop.
      reason <- paste0("template corpus not found at ", template_dir)
      warning("study_setup(): ", reason, "; template copies were not cleaned up. ",
              "Pass template_dir to clean them, or cleanup = FALSE to skip this.",
              call. = FALSE)
      skipped <- list(status = "skipped", reason = reason, deleted = character(0),
                      removed_dirs = character(0), left = character(0))
      cleanup <- FALSE
    }
  }
  if (cleanup) {
    if (.study_paths_overlap(root, template_dir)) {
```

The closing brace of the old block now closes the second `if (cleanup)`.
Replace `cleaned <- if (cleanup) .study_cleanup(root, template_dir)` with

```r
  cleaned <- if (cleanup) .study_cleanup(root, template_dir) else skipped
```

In `.study_cleanup()`, change the final `list(deleted = found$files,
removed_dirs = removed)` to
`list(status = "done", reason = NULL, deleted = found$files, removed_dirs = removed, left = character(0))`.
Task A2 changes `deleted` and `left`.

- [ ] **Step 5: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "study")'`
Expected: FAIL 0. Any existing test that compares `attr(, "cleanup")` with
`identical()` against the old two-field list must be updated to the new
five-field shape. Update it, and list each one in the report.

- [ ] **Step 6: Commit**

```bash
git add R/study_setup.R tests/testthat/test-study_setup.R
git commit -m "study_setup: a missing template corpus warns and skips cleanup"
```

---

### Task A2: Files cleanup cannot delete warn instead of stopping

**Files:**
- Modify: `R/study_setup.R` (`.study_cleanup()`)
- Modify: `tests/testthat/test-study_setup.R` ("cleanup stops loudly when a
  file cannot be deleted")

**Interfaces:**
- Consumes: the five-field `attr(, "cleanup")` from A1.
- Produces: `deleted` holds only the files actually deleted. `left` holds the
  files and folders still present.

- [ ] **Step 1: Rewrite the test (it fails)**

```r
test_that("cleanup warns and lists what it could not delete", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "analyses"))
  write_file(root, "analyses/tp.hz.sas")
  local_mocked_bindings(.study_unlink = function(paths, recursive = FALSE) invisible(NULL))

  expect_warning(
    status <- study_setup(root, "Legacy study", 42L, adopt = TRUE, cleanup = TRUE,
                          template_dir = local_corpus(), renv = FALSE),
    "could not delete 1 .*analyses/tp.hz.sas"
  )
  cleaned <- attr(status, "cleanup")
  expect_identical(cleaned$status, "done")
  expect_identical(cleaned$left, "analyses/tp.hz.sas")
  expect_identical(cleaned$deleted, character(0))
  expect_true(file.exists(file.path(root, "_study.yml")))
})
```

- [ ] **Step 2: Run it and see it fail**

Run: `Rscript -e 'devtools::test(filter = "study_setup")'`
Expected: FAIL (an error, not a warning).

- [ ] **Step 3: Implement**

In `.study_cleanup()`, replace

```r
  left <- found$files[file.exists(file.path(root, found$files))]
  if (length(left)) {
    stop("study_setup(): cleanup could not delete ", length(left), " file(s), first ",
         paste(utils::head(left, 5L), collapse = ", "), call. = FALSE)
  }
```

with

```r
  left <- found$files[file.exists(file.path(root, found$files))]
  if (length(left)) {
    # A file left behind cannot reach the explicit-mode lockfile; say so and go on.
    warning("study_setup(): cleanup could not delete ", length(left), " file(s), first ",
            paste(utils::head(left, 5L), collapse = ", "), call. = FALSE)
  }
```

In the folder loop, replace

```r
      if (dir.exists(full)) {
        stop("study_setup(): cleanup could not remove folder ", folder, call. = FALSE)
      }
      removed <- c(removed, folder)
```

with

```r
      if (dir.exists(full)) {
        warning("study_setup(): cleanup could not remove folder ", folder, call. = FALSE)
        left <- c(left, folder)
      } else {
        removed <- c(removed, folder)
      }
```

Change the return to

```r
  list(status = "done", reason = NULL, deleted = setdiff(found$files, left),
       removed_dirs = removed, left = left)
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "study")'`
Expected: FAIL 0.

- [ ] **Step 5: Commit**

```bash
git add R/study_setup.R tests/testthat/test-study_setup.R
git commit -m "study_setup: warn on files cleanup cannot delete, and list them"
```

---

### Task A3: Repair a sound lock that lacks its activation

**Files:**
- Modify: `R/study_setup.R` (`.study_init_renv()`)
- Modify: `tests/testthat/test-study_setup.R`:
  - "renv = TRUE stops on any other partial environment without running R",
    around line 558;
  - the cases loop around line 790 that expects `"partial renv environment"`
    for locks that are sound;
  - `fake_rscript()`.

**Interfaces:**
- Produces: `attr(status, "renv")` can be `"repaired"`, as well as
  `"initialized"` and `"retained"`.

- [ ] **Step 1: Teach `fake_rscript()` about activation**

In `fake_rscript()`, add a branch before the `else`, mirroring the existing
`renv::init` branch:

```r
    } else if (grepl("renv::activate", expr, fixed = TRUE)) {
      if (!init_ok) return(list(status = 1L, output = "activate exploded"))
      write_renv_start(root)
```

`write_renv_start()` writes `renv/activate.R` and the sourcing `.Rprofile`, as
the real `renv::activate()` does. Read it to confirm. If it overwrites a
pre-existing `.Rprofile`, that is acceptable for the fake. The real-renv test
in Step 2 checks that the user's lines are kept.

- [ ] **Step 2: Write the tests (they fail)**

Replace "renv = TRUE stops on any other partial environment without running R"
with:

```r
test_that("renv = TRUE repairs a sound lock that lacks its activation, keeping the lock", {
  root <- withr::local_tempdir()
  write_lock(root)
  before <- readBin(file.path(root, "renv.lock"), "raw", file.size(file.path(root, "renv.lock")))
  calls <- new.env()
  local_mocked_bindings(.study_rscript = fake_rscript(calls))

  status <- study_setup(root, "Legacy study", 42L, adopt = TRUE, renv = TRUE, cleanup = FALSE)
  expect_identical(attr(status, "renv"), "repaired")
  expect_length(calls$exprs, 1L)
  expect_match(calls$exprs, "renv::activate(project = ", fixed = TRUE)
  after <- readBin(file.path(root, "renv.lock"), "raw", file.size(file.path(root, "renv.lock")))
  expect_identical(after, before)
})

test_that("renv = TRUE still stops when the lock itself is not sound", {
  root <- withr::local_tempdir()
  write_renv_start(root)
  writeLines("{", file.path(root, "renv.lock"))
  calls <- new.env()
  local_mocked_bindings(.study_rscript = fake_rscript(calls))
  expect_error(
    study_setup(root, "Legacy study", 42L, adopt = TRUE, renv = TRUE, cleanup = FALSE),
    "partial renv environment"
  )
  expect_null(calls$exprs)
})

test_that("real renv::activate() keeps the lock and the study's own .Rprofile lines", {
  skip_on_cran()
  skip_if_not_installed("renv")
  root <- withr::local_tempdir()
  write_lock(root)
  writeLines("options(digits = 4)", file.path(root, ".Rprofile"))
  lock <- readLines(file.path(root, "renv.lock"))
  result <- .study_rscript(
    paste0("renv::activate(project = ", deparse(normalizePath(root, winslash = "/")), ")"),
    root, "--vanilla"
  )
  expect_identical(result$status, 0L, info = result$output)
  expect_true(all(.study_renv_parts(root)))
  expect_identical(readLines(file.path(root, "renv.lock")), lock)
  expect_true("options(digits = 4)" %in% readLines(file.path(root, ".Rprofile")))
})
```

The cases loop near line 790 builds environments whose lock is sound and whose
`.Rprofile` does not source `activate.R`: `no_source`, `unsourced_path`,
`inline_comment`. Change its assertion from `expect_error(..., "partial renv
environment", info = case)` to

```r
    status <- study_setup(root, "Legacy study", 42L, adopt = TRUE, renv = TRUE, cleanup = FALSE)
    expect_identical(attr(status, "renv"), "repaired", info = case)
```

Also change its closing `expect_null(calls$exprs)` to
`expect_length(calls$exprs, length(cases))`. Rename the test to say these are
repaired. **Read each case first:** any case whose lock is *not* sound stays an
expected error, and moves into the "still stops" test above.

- [ ] **Step 3: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "study_setup")'`
Expected: the repair tests FAIL with "partial renv environment". The real-renv
test PASSES already, because it calls `.study_rscript()` directly. That is
intended: it pins renv's behavior, not ours.

- [ ] **Step 4: Implement**

In `.study_init_renv()`, replace

```r
  present <- file.exists(file.path(root, core))
  resumable <- all(sound[c("renv", ".Rprofile")]) && !present[3L]
  if (any(present) && !resumable) {
```

with

```r
  present <- file.exists(file.path(root, core))
  resumable <- all(sound[c("renv", ".Rprofile")]) && !present[3L]
  # A sound lock is the study's history: rebuild only the scaffolding around it.
  repairable <- sound[["renv.lock"]]
  if (any(present) && !resumable && !repairable) {
```

Then, directly after the `run <- function(expr, what) { ... }` definition, add

```r
  if (repairable) {
    project <- deparse(normalizePath(root, winslash = "/"))
    run(paste0("renv::activate(project = ", project, ")"), "renv activation")
    if (!all(.study_renv_parts(root))) {
      stop("study_setup(): renv activation finished without a complete environment",
           call. = FALSE)
    }
    return("repaired")
  }
```

`all(sound)` already returned `"retained"` above, so `repairable` here means a
sound lock with something else missing. Update the `@param renv` /
`@return` roxygen to list `"repaired"`, and add one sentence to the renv
paragraph of `@details`: "A sound `renv.lock` whose `renv/activate.R` or
`.Rprofile` line is missing is repaired with `renv::activate()`, which leaves
the lock unchanged."

- [ ] **Step 5: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "study")'`
Expected: FAIL 0.

- [ ] **Step 6: Commit**

```bash
git add R/study_setup.R tests/testthat/test-study_setup.R
git commit -m "study_setup: repair a sound lock that lacks its activation"
```

---

### Task A4: Docs, news and gates for Part A

**Files:**
- Modify: `R/study_setup.R` (roxygen of `study_setup()`)
- Modify: `man/study_setup.Rd` (regenerated)
- Create: `news/feat-study-setup-degrade.md`

- [ ] **Step 1: Roxygen**

In `study_setup()`'s `@details`:

- In the cleanup paragraph, replace "A file that cannot be deleted stops the
  setup with an error." with "A file or folder that cannot be deleted is warned
  about and listed in the \code{"cleanup"} attribute's \code{left}; setup goes
  on. With no template corpus at \code{template_dir}, cleanup is skipped with a
  warning."
- Replace the `@param template_dir` sentence "Setup stops with an error when it
  does not exist." with "When it does not exist, cleanup is skipped with a
  warning."
- Change `@return`'s cleanup sentence to describe the list
  (`status`, `reason`, `deleted`, `removed_dirs`, `left`) and add
  `"repaired"` to the renv values.

Match the file's existing roxygen markup (check whether the file uses
`\code{}` or backticks, and keep to it).

Run: `Rscript -e 'devtools::document()'`. Revert any `RoxygenNote` bump in
`DESCRIPTION`.

- [ ] **Step 2: News fragment** `news/feat-study-setup-degrade.md`:

```markdown
* `study_setup()` no longer stops when it cannot clean up: a missing template
  corpus skips cleanup with a warning, and files it cannot delete are warned
  about and listed in the `"cleanup"` attribute's `left`. Explicit-mode renv no
  longer reads the study's code, so leftover template copies cannot reach the
  lockfile.
* `study_setup()` repairs a study whose `renv.lock` is sound but whose
  `renv/activate.R` or `.Rprofile` line is missing, with `renv::activate()`;
  the lock is left unchanged and `attr(, "renv")` is `"repaired"`.
```

- [ ] **Step 3: Gates**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'lintr::lint_package()'
Rscript -e 'devtools::check()'
```

Expected: FAIL 0, lint clean, check 0/0/0. Report the SKIP count and explain
any new skip.

- [ ] **Step 4: Commit, review, PR**

```bash
git add R/study_setup.R man/study_setup.Rd news/feat-study-setup-degrade.md
git commit -m "study_setup: document the warnings and the repair"
```

Then run the task review and open the PR against `main`. **John merges and tags
the patch release**, which Part B's floor needs.

---

## Part B: hvtiR

### Task B1: Classify a child's failures

**Files:**
- Create: `R/heal.R`
- Create: `tests/testthat/test-heal.R`

**Interfaces:**
- Consumes: `compile_failures(output)` and `restore_failures(output)` from
  `R/setup.R`.
- Produces: `classify_failures(output)`, which returns a data.frame with
  columns `package` (chr), `cause` (`"compile"`, `"dependency"` or `"other"`)
  and `needs` (chr; the missing dependency for `"dependency"`, otherwise
  `NA`). It has one row per package, and the first cause found wins in the
  order compile, then dependency, then other.

- [ ] **Step 1: Create the branch**

```bash
cd ~/Documents/GitHub/hvtiR-robust-setup
git fetch origin && git checkout -b feat/robust-setup docs/robust-setup-design
git rebase origin/main
```

- [ ] **Step 2: Write the failing tests**

`tests/testthat/test-heal.R`:

```r
test_that("compile and configure failures are compile causes", {
  out <- paste(
    "ERROR: compilation failed for package ‘vctrs’",
    "ERROR: configuration failed for package ‘arrow’",
    sep = "\n"
  )
  f <- classify_failures(out)
  expect_identical(f$package, c("vctrs", "arrow"))
  expect_identical(f$cause, c("compile", "compile"))
  expect_true(all(is.na(f$needs)))
})

test_that("a missing dependency names the package and what it needs", {
  out <- "ERROR: dependency ‘tseries’ is not available for package ‘forecast’"
  f <- classify_failures(out)
  expect_identical(f$package, "forecast")
  expect_identical(f$cause, "dependency")
  expect_identical(f$needs, "tseries")
})

test_that("renv's failed list fills in packages with no other cause", {
  out <- paste(
    "ERROR: compilation failed for package 'xts'",
    "Error: failed to install \"xts\", \"igraph\"",
    sep = "\n"
  )
  f <- classify_failures(out)
  expect_identical(f$package, c("xts", "igraph"))
  expect_identical(f$cause, c("compile", "other"))
})

test_that("output with no recognisable failure gives no rows", {
  f <- classify_failures("Error: could not resolve host")
  expect_identical(nrow(f), 0L)
  expect_named(f, c("package", "cause", "needs"))
})

test_that("only valid package names are taken from untrusted output", {
  out <- "ERROR: compilation failed for package ‘bad name;rm’"
  expect_identical(nrow(classify_failures(out)), 0L)
})
```

- [ ] **Step 3: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "heal")'`
Expected: FAIL, `could not find function "classify_failures"`.

- [ ] **Step 4: Implement** `R/heal.R`:

```r
#' Why each package in a child's output failed to install
#'
#' Read from untrusted output, so only valid package names are taken. A
#' package gets the first cause found, in the order compile, dependency,
#' other.
#' @param output A child's output.
#' @return A data.frame: `package`, `cause` (`"compile"`, `"dependency"` or
#'   `"other"`) and `needs` (the missing dependency, else `NA`).
#' @noRd
classify_failures <- function(output) {
  name <- "([A-Za-z][A-Za-z0-9.]*[A-Za-z0-9])"
  open <- "[‘'\"“]"
  close <- "[’'\"”]"
  configured <- paste0(
    "configuration failed for package ", open, name, close
  )
  hits <- regmatches(output, gregexpr(configured, output))[[1L]]
  compiled <- unique(c(
    compile_failures(output), sub(configured, "\\1", hits)
  ))
  dependency <- paste0(
    "dependency ", open, name, close, " is not available for package ",
    open, name, close
  )
  dep_hits <- regmatches(output, gregexpr(dependency, output))[[1L]]
  dep_pkg <- sub(dependency, "\\2", dep_hits)
  dep_needs <- sub(dependency, "\\1", dep_hits)
  failed <- restore_failures(output)
  other <- if (is.null(failed)) character() else failed$pkgs
  out <- data.frame(
    package = c(compiled, dep_pkg, other),
    cause = c(
      rep("compile", length(compiled)), rep("dependency", length(dep_pkg)),
      rep("other", length(other))
    ),
    needs = c(
      rep(NA_character_, length(compiled)), dep_needs,
      rep(NA_character_, length(other))
    ),
    stringsAsFactors = FALSE
  )
  out <- out[!duplicated(out$package), , drop = FALSE]
  rownames(out) <- NULL
  out
}
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "heal")'`, then
`Rscript -e 'print(lintr::lint("R/heal.R")); print(lintr::lint("tests/testthat/test-heal.R"))'`
Expected: PASS and no lints.

- [ ] **Step 6: Commit**

```bash
git add R/heal.R tests/testthat/test-heal.R
git commit -m "setup: classify why each package failed to install"
```

---

### Task B2: Decide a round (pure)

**Files:**
- Modify: `R/heal.R`
- Modify: `tests/testthat/test-heal.R`

**Interfaces:**
- Consumes: `classify_failures()` output (B1); `record_specs(pkgs, root)` from
  `R/setup.R` (named chr, `NA` where there is no safe spec).
- Produces: `plan_round(failures, specs, moved, missing, essential, upgrade,
  stuck)`, which returns
  `list(move = <named chr of specs>, install = <chr of packages>,
  drop = data.frame(package, reason, because), stop = <chr>)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-heal.R`:

```r
fails <- function(package, cause, needs = NA_character_) {
  data.frame(package = package, cause = cause, needs = needs,
             stringsAsFactors = FALSE)
}
decide <- function(f, specs = stats::setNames(f$package, f$package),
                   moved = character(), missing = character(),
                   essential = "hvtiRutilities", upgrade = TRUE,
                   stuck = FALSE) {
  plan_round(f, specs, moved, missing, essential, upgrade, stuck)
}

test_that("a compile failure moves its pin under upgrade = TRUE", {
  r <- decide(fails("vctrs", "compile"))
  expect_identical(r$move, c(vctrs = "vctrs"))
  expect_identical(nrow(r$drop), 0L)
})

test_that("a pin that already moved is not moved again but dropped", {
  r <- decide(fails("vctrs", "compile"), moved = "vctrs")
  expect_length(r$move, 0L)
  expect_identical(r$drop$package, "vctrs")
  expect_match(r$drop$reason, "after its version moved")
})

test_that("upgrade = FALSE moves nothing", {
  r <- decide(fails("vctrs", "compile"), upgrade = FALSE)
  expect_length(r$move, 0L)
  expect_identical(r$drop$package, "vctrs")
})

test_that("a package with no safe spec is dropped, not moved", {
  r <- decide(fails("odd", "compile"), specs = c(odd = NA_character_))
  expect_length(r$move, 0L)
  expect_identical(r$drop$package, "odd")
})

test_that("a missing dependency is installed first", {
  r <- decide(fails("forecast", "dependency", "tseries"))
  expect_identical(r$install, "tseries")
  expect_identical(nrow(r$drop), 0L)
})

test_that("a dependency already left out drops its dependent, saying why", {
  r <- decide(fails("forecast", "dependency", "tseries"), missing = "tseries")
  expect_identical(r$drop$package, "forecast")
  expect_identical(r$drop$because, "tseries")
})

test_that("a stuck round drops what it would otherwise retry", {
  r <- decide(fails(c("vctrs", "forecast"), c("compile", "dependency"),
                    c(NA, "tseries")), stuck = TRUE)
  expect_length(r$move, 0L)
  expect_length(r$install, 0L)
  expect_setequal(r$drop$package, c("vctrs", "forecast"))
})

test_that("an essential package is never dropped: it stops", {
  r <- decide(fails("hvtiRutilities", "other"))
  expect_identical(r$stop, "hvtiRutilities")
  expect_identical(nrow(r$drop), 0L)
  r <- decide(fails("hvtiRutilities", "compile"), moved = "hvtiRutilities")
  expect_identical(r$stop, "hvtiRutilities")
})

test_that("an other failure is dropped with its reason", {
  r <- decide(fails("igraph", "other"))
  expect_identical(r$drop$package, "igraph")
  expect_identical(r$drop$reason, "failed to install")
})
```

- [ ] **Step 2: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "heal")'`
Expected: FAIL, `could not find function "plan_round"`.

- [ ] **Step 3: Implement**

Append to `R/heal.R`:

```r
#' What one healing round does with each failed package
#'
#' Pure, so every rule is testable without a child process.
#' @param failures From [classify_failures()].
#' @param specs From [record_specs()], named by package; `NA` has no safe spec.
#' @param moved Packages whose pins already moved this run.
#' @param missing Packages already left out this run.
#' @param essential Packages that stop the run rather than being left out.
#' @param upgrade As passed to [setup()].
#' @param stuck `TRUE` when this round failed on the same set as the last, or
#'   is the last round allowed.
#' @return `list(move, install, drop, stop)`.
#' @noRd
plan_round <- function(failures, specs, moved, missing, essential, upgrade,
                       stuck) {
  move <- character()
  install <- character()
  drop <- data.frame(
    package = character(), reason = character(), because = character(),
    stringsAsFactors = FALSE
  )
  stop_pkgs <- character()
  give_up <- function(pkg, reason, because = NA_character_) {
    if (pkg %in% essential) {
      stop_pkgs <<- c(stop_pkgs, pkg)
    } else {
      drop[nrow(drop) + 1L, ] <<- list(pkg, reason, because)
    }
  }
  for (i in seq_len(nrow(failures))) {
    pkg <- failures$package[i]
    cause <- failures$cause[i]
    if (cause == "compile") {
      spec <- unname(specs[pkg])
      if (pkg %in% moved) {
        give_up(pkg, "still failed to compile after its version moved")
      } else if (isTRUE(upgrade) && !stuck && length(spec) && !is.na(spec)) {
        move[pkg] <- spec
      } else {
        give_up(pkg, "failed to compile at its locked version")
      }
    } else if (cause == "dependency") {
      needs <- failures$needs[i]
      if (needs %in% missing) {
        give_up(pkg, paste0("needs ", needs, ", which was left out"), needs)
      } else if (!stuck) {
        install <- union(install, needs)
      } else {
        give_up(pkg, paste0("dependency ", needs, " is not available"), needs)
      }
    } else {
      give_up(pkg, "failed to install")
    }
  }
  list(move = move, install = install, drop = drop, stop = stop_pkgs)
}
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "heal")'` and lint `R/heal.R`.
Expected: PASS and no lints.

- [ ] **Step 5: Commit**

```bash
git add R/heal.R tests/testthat/test-heal.R
git commit -m "setup: decide each healing round in one pure function"
```

---

### Task B3: Child expressions to record, install and drop, plus the lock backup

**Files:**
- Modify: `R/heal.R`
- Modify: `R/setup.R` (`record_specs()`: extract its record-reading helper)
- Modify: `tests/testthat/test-heal.R`

**Interfaces:**
- Consumes: `pak_off()`, `repos_expr(repos)` from `R/setup.R`.
- Produces:
  - `lock_field(text, pkg, name)`, which returns a chr(1) or `NA`.
    `record_specs()` is refactored onto it.
  - `locked_versions(pkgs, root)`, which returns a chr named by `pkgs`, `NA`
    where there is no record.
  - `record_expr(root, specs, repos = NULL)` returns chr(1) of R code, which
    prints `HVTIR_RECORDED=pkg:version,...`.
  - `install_expr(root, specs, repos = NULL)` returns chr(1) of R code.
  - `drop_expr(root, pkgs)` returns chr(1) of R code.
  - `backup_lock(root, stamp = format(Sys.time(), "%Y%m%d-%H%M%S"))` returns
    the backup's path relative to `root`, or `NA` when there is no lock.

- [ ] **Step 1: Write the failing tests**

Append:

```r
local_lock <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  writeLines(c(
    "{", '  "R": {"Version": "4.5.1"},', '  "Packages": {',
    '    "vctrs": {"Package": "vctrs", "Version": "0.7.2",',
    '      "Source": "Repository", "Repository": "CRAN"},',
    '    "hvtiRutilities": {"Package": "hvtiRutilities", "Version": "1.5.6",',
    '      "Source": "GitHub", "RemoteUsername": "ehrlinger",',
    '      "RemoteRepo": "hvtiRutilities"}',
    "  }", "}"
  ), file.path(root, "renv.lock"))
  dir.create(file.path(root, "renv"))
  root
}

test_that("locked_versions reads each record's version", {
  root <- local_lock()
  expect_identical(
    locked_versions(c("vctrs", "hvtiRutilities", "absent"), root),
    c(vctrs = "0.7.2", hvtiRutilities = "1.5.6", absent = NA)
  )
})

test_that("record_specs is unchanged by the refactor", {
  root <- local_lock()
  expect_identical(
    record_specs(c("vctrs", "hvtiRutilities"), root),
    c(vctrs = "vctrs", hvtiRutilities = "ehrlinger/hvtiRutilities")
  )
})

test_that("record_expr records against the study's repositories", {
  root <- local_lock()
  expr <- record_expr(root, c(vctrs = "vctrs"), c(PPM = "https://ppm/x"))
  expect_match(expr, "options(repos = hvtir_repos)", fixed = TRUE)
  expect_match(expr, 'renv::record("vctrs", project = ', fixed = TRUE)
  expect_match(expr, "HVTIR_RECORDED=", fixed = TRUE)
  expect_true(startsWith(expr, pak_off()))
})

test_that("install_expr installs into the project with no prompt", {
  root <- local_lock()
  expr <- install_expr(root, "tseries@0.10-58")
  expect_match(expr, 'renv::install("tseries@0.10-58", project = ', fixed = TRUE)
  expect_match(expr, "prompt = FALSE", fixed = TRUE)
})

test_that("drop_expr removes records from the lock", {
  root <- local_lock()
  expect_match(drop_expr(root, "vctrs"), 'lf$Packages[c("vctrs")] <- NULL',
               fixed = TRUE)
})

test_that("drop_expr really removes the record from a lockfile", {
  skip_on_cran()
  skip_if_not_installed("renv")
  root <- local_lock()
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c("--vanilla", "-e", shQuote(drop_expr(root, "vctrs"))))
  expect_identical(status, 0L)
  kept <- names(renv::lockfile_read(file.path(root, "renv.lock"))$Packages)
  expect_identical(kept, "hvtiRutilities")
})

test_that("backup_lock copies the lock once under renv/", {
  root <- local_lock()
  rel <- backup_lock(root, stamp = "20261105-161000")
  expect_identical(rel, "renv/renv.lock.before-setup-20261105-161000")
  expect_identical(readLines(file.path(root, rel)),
                   readLines(file.path(root, "renv.lock")))
  expect_true(is.na(backup_lock(withr::local_tempdir())))
})
```

- [ ] **Step 2: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "heal")'`
Expected: FAIL, functions not found. The `record_specs` test passes already
and acts as the refactor's guard.

- [ ] **Step 3: Implement**

In `R/setup.R`, replace `record_specs()`'s inner `block`/`field` code with
calls to a new helper. Put the helper just above `record_specs()`:

```r
#' One field of a package's record in a lockfile's text
#'
#' Read with patterns, as [lockfile_r_version()] is.
#' @param text The lockfile's text.
#' @param pkg A valid package name.
#' @param name The field.
#' @return The value, or `NA` when the record or field is absent.
#' @noRd
lock_field <- function(text, pkg, name) {
  key <- gsub(".", "\\.", pkg, fixed = TRUE)
  block <- regmatches(
    text, regexpr(paste0('"', key, '"\\s*:\\s*\\{[^}]*\\}'), text)
  )
  hit <- regmatches(
    block, regexec(paste0('"', name, '"\\s*:\\s*"([^"]*)"'), block)
  )
  if (length(hit) && length(hit[[1L]]) == 2L) hit[[1L]][2L] else NA
}
```

and make `record_specs()`'s `spec()` read
`source <- lock_field(text, pkg, "Source")` and likewise for `user` and `repo`.
Its loading of `text` from the file stays as it is.

Append to `R/heal.R`:

```r
#' The locked version of each package
#' @param pkgs Valid package names.
#' @param root The study root.
#' @return A character vector named by `pkgs`, `NA` with no record.
#' @noRd
locked_versions <- function(pkgs, root) {
  path <- file.path(root, "renv.lock")
  text <- if (file.exists(path)) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  vapply(
    stats::setNames(pkgs, pkgs),
    function(pkg) lock_field(text, pkg, "Version"),
    character(1L)
  )
}

#' The child's code to move pins to the newest version the repositories serve
#' @param root The study root.
#' @param specs Specs from [record_specs()], named by package, none `NA`.
#' @param repos The study's repositories, or `NULL`.
#' @return One string of R code; it prints `HVTIR_RECORDED=pkg:version,...`.
#' @noRd
record_expr <- function(root, specs, repos = NULL) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    repos_expr(repos),
    "renv::record(", deparse1(unname(specs)), ", project = ", p, "); ",
    "lf <- renv::lockfile_read(file.path(", p, ", 'renv.lock'))$Packages; ",
    "pk <- ", deparse1(names(specs)), "; ",
    "cat('\\nHVTIR_RECORDED=', paste0(pk, ':', vapply(pk, function(x) ",
    "if (is.null(lf[[x]])) '' else as.character(lf[[x]]$Version), ''), ",
    "collapse = ','), '\\n', sep = '')"
  )
}

#' The child's code to install packages into the study's library
#' @param root The study root.
#' @param specs Install specs, such as `"tseries@0.10-58"` or `"tseries"`.
#' @param repos The study's repositories, or `NULL`.
#' @return One string of R code.
#' @noRd
install_expr <- function(root, specs, repos = NULL) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    repos_expr(repos),
    "renv::install(", deparse1(unname(specs)), ", project = ", p,
    ", prompt = FALSE)"
  )
}

#' The child's code to take records out of the study's lockfile
#' @param root The study root.
#' @param pkgs Valid package names.
#' @return One string of R code.
#' @noRd
drop_expr <- function(root, pkgs) {
  path <- deparse1(file.path(normalizePath(root, winslash = "/"), "renv.lock"))
  paste0(
    "lf <- renv::lockfile_read(", path, "); ",
    "lf$Packages[", deparse1(pkgs), "] <- NULL; ",
    "renv::lockfile_write(lf, ", path, ")"
  )
}

#' Copy the study's lockfile aside before healing changes it
#' @param root The study root.
#' @param stamp A time stamp for the file name.
#' @return The copy's path relative to `root`, or `NA` with no lockfile.
#' @noRd
backup_lock <- function(root, stamp = format(Sys.time(), "%Y%m%d-%H%M%S")) {
  lock <- file.path(root, "renv.lock")
  if (!file.exists(lock)) return(NA_character_)
  rel <- file.path("renv", paste0("renv.lock.before-setup-", stamp))
  dir.create(file.path(root, "renv"), showWarnings = FALSE)
  if (!file.copy(lock, file.path(root, rel), overwrite = FALSE)) {
    cli::cli_abort("Could not back up {.file renv.lock} to {.file {rel}}.")
  }
  rel
}
```

`deparse1(pkgs)` of one name gives `"vctrs"`, not `c("vctrs")`. Check the
test's expectation against what `deparse1()` actually prints and fix **the
test** to match `deparse1()`. Do not wrap the code to suit the test.

- [ ] **Step 4: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "heal|setup")'` and lint both R
files.
Expected: PASS. The existing setup tests that pin `record_command()` and
`record_specs()` output still pass.

- [ ] **Step 5: Commit**

```bash
git add R/heal.R R/setup.R tests/testthat/test-heal.R
git commit -m "setup: child code to record, install and drop, and a lock backup"
```

---

### Task B4: The healing loop

**Files:**
- Modify: `R/heal.R`
- Modify: `tests/testthat/test-heal.R`

**Interfaces:**
- Consumes: `restore_expr()`, `run_in_study()`, `abort_stage()`,
  `record_specs()`, `save_setup_log()` from `R/setup.R`; B1–B3.
- Produces: `heal_restore(root, repos, upgrade, essential, max_rounds = 10L)`,
  which returns `list(result, raw, healed, missing, backup)`:
  - `result` is the successful restore child's `list(status, output)`, with
    `output` converted to UTF-8;
  - `raw` is that child's raw output;
  - `healed` is a data.frame with `package`, `from`, `to` and `round`;
  - `missing` is a data.frame with `package`, `reason`, `because` and `log`;
  - `backup` is a chr(1) or `NA`.

  An essential failure, or a failure with no recognisable cause, calls
  `abort_stage()`, which stops with today's diagnosis.

- [ ] **Step 1: Write the failing tests**

Append. The child is scripted by expression type: restore calls pop a queue of
outputs, and record, install and drop calls are logged and answered.

```r
local_children <- function(restores, recorded = "vctrs:0.7.3",
                           env = parent.frame()) {
  log <- new.env()
  log$calls <- character()
  log$exprs <- character()
  queue <- restores
  local_mocked_bindings(
    run_in_study = function(expr, root) {
      if (grepl("renv::restore(", expr, fixed = TRUE)) {
        log$calls <- c(log$calls, "restore")
        out <- queue[[1L]]
        queue <<- queue[-1L]
        return(list(status = if (identical(out, "ok")) 0L else 1L,
                    output = if (identical(out, "ok")) "HVTIR_LIB=/l\n" else out))
      }
      kind <- if (grepl("renv::record(", expr, fixed = TRUE)) "record"
        else if (grepl("renv::install(", expr, fixed = TRUE)) "install"
        else "drop"
      log$calls <- c(log$calls, kind)
      log$exprs <- c(log$exprs, expr)
      list(status = 0L, output = paste0("HVTIR_RECORDED=", recorded, "\n"))
    },
    save_setup_log = function(output, root = NULL) "renv/logs/x.log",
    .env = env
  )
  log
}
compile_out <- function(pkg) {
  paste0("ERROR: compilation failed for package ‘", pkg, "’")
}

test_that("a compile failure heals by moving the pin, then restores", {
  root <- local_lock()
  log <- local_children(list(compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls, c("restore", "record", "restore"))
  expect_identical(h$healed$package, "vctrs")
  expect_identical(h$healed$from, "0.7.2")
  expect_identical(h$healed$to, "0.7.3")
  expect_identical(nrow(h$missing), 0L)
  expect_true(file.exists(file.path(root, h$backup)))
})

test_that("a package that fails again after moving is left out at once", {
  root <- local_lock()
  log <- local_children(list(compile_out("vctrs"), compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls,
                   c("restore", "record", "restore", "drop", "restore"))
  expect_identical(h$missing$package, "vctrs")
})

test_that("upgrade = FALSE leaves out an optional package without moving it", {
  root <- local_lock()
  log <- local_children(list(compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, FALSE, essential = "hvtiRutilities")
  expect_false("record" %in% log$calls)
  expect_identical(h$missing$package, "vctrs")
})

test_that("an essential failure stops with today's diagnosis", {
  root <- local_lock()
  local_children(list(compile_out("hvtiRutilities"),
                      compile_out("hvtiRutilities")))
  expect_error(
    heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
    "failed to compile"
  )
})

test_that("a missing dependency is installed at its locked version first", {
  root <- local_lock()
  dep <- paste0("ERROR: dependency ‘vctrs’ is not available ",
                "for package ‘forecast’")
  log <- local_children(list(dep, "ok"))
  heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls, c("restore", "install", "restore"))
  expect_match(log$exprs[1L], '"vctrs@0.7.2"', fixed = TRUE)
})

test_that("the same failed set twice ends healing", {
  root <- local_lock()
  dep <- paste0("ERROR: dependency ‘tseries’ is not available ",
                "for package ‘forecast’")
  log <- local_children(list(dep, dep, "ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls,
                   c("restore", "install", "restore", "drop", "restore"))
  expect_identical(h$missing$package, "forecast")
  expect_identical(h$missing$because, "tseries")
})

test_that("the round cap leaves out whatever still fails", {
  root <- local_lock()
  outs <- lapply(1:3, function(i) compile_out(paste0("p", i)))
  log <- local_children(c(outs, list("ok")))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities",
                    max_rounds = 3L)
  expect_identical(sum(log$calls == "restore"), 4L)
  expect_true("p3" %in% h$missing$package)
})

test_that("an unrecognised failure stops with today's diagnosis", {
  root <- local_lock()
  local_children(list("Error: could not resolve host"))
  expect_error(heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
               "Installing the study's packages failed")
})

test_that("a clean first restore heals nothing and backs nothing up", {
  root <- local_lock()
  log <- local_children(list("ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls, "restore")
  expect_true(is.na(h$backup))
})
```

`local_lock()` (Task B3) has no record for `p1`–`p3`. `record_specs()`
returns `NA` for them, so in the cap test each is dropped in its round rather
than moved. The test checks only that the cap ends the loop with the last
failure left out, which holds either way.

- [ ] **Step 2: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "heal")'`
Expected: FAIL, `could not find function "heal_restore"`.

- [ ] **Step 3: Implement**

Append to `R/heal.R`:

```r
#' Restore the study's lockfile, healing what fails, leaving out what cannot
#'
#' Each round restores; on failure, [plan_round()] decides what to move,
#' install first, leave out or stop on. A round that fails on the same set
#' as the last, or the last round allowed, moves and installs nothing more.
#' @param root The study root.
#' @param repos The study's repositories, or `NULL`.
#' @param upgrade As passed to [setup()].
#' @param essential Packages whose failure stops the run.
#' @param max_rounds The most healing rounds.
#' @return `list(result, raw, healed, missing, backup)`.
#' @noRd
heal_restore <- function(root, repos, upgrade, essential, max_rounds = 10L) {
  healed <- data.frame(
    package = character(), from = character(), to = character(),
    round = integer(), stringsAsFactors = FALSE
  )
  missing <- data.frame(
    package = character(), reason = character(), because = character(),
    log = character(), stringsAsFactors = FALSE
  )
  backup <- NA_character_
  previous <- NULL
  child <- function(expr, what) {
    out <- run_in_study(expr, root)
    if (out$status != 0L) {
      cli::cli_abort(c(
        "Healing the study's packages failed while {what}.",
        output_bullets(out$output),
        i = "Full output: {.file {save_setup_log(out$output, root)}}"
      ))
    }
    out
  }
  for (round in seq_len(max_rounds + 1L)) {
    raw <- run_in_study(restore_expr(root, repos), root)
    result <- raw
    result$output <- iconv(raw$output, "UTF-8", "UTF-8", sub = "?")
    if (result$status == 0L) {
      return(list(result = result, raw = raw$output, healed = healed,
                  missing = missing, backup = backup))
    }
    failures <- classify_failures(result$output)
    if (!nrow(failures) || round > max_rounds) {
      abort_stage(result, raw$output, root, upgrade)
    }
    set <- sort(failures$package)
    stuck <- identical(set, previous) || round == max_rounds
    previous <- set
    decision <- plan_round(
      failures, record_specs(failures$package, root), healed$package,
      missing$package, essential, upgrade, stuck
    )
    if (length(decision$stop)) {
      abort_stage(result, raw$output, root, upgrade)
    }
    if (is.na(backup)) backup <- backup_lock(root)
    if (length(decision$move)) {
      from <- locked_versions(names(decision$move), root)
      out <- child(record_expr(root, decision$move, repos), "moving pins")
      got <- strsplit(child_value(out$output, "HVTIR_RECORDED"), ",",
                      fixed = TRUE)[[1L]]
      to <- stats::setNames(sub("^[^:]*:", "", got), sub(":.*$", "", got))
      for (pkg in names(decision$move)) {
        healed[nrow(healed) + 1L, ] <- list(
          pkg, unname(from[pkg]), unname(to[pkg]), round
        )
      }
    }
    if (length(decision$install)) {
      version <- locked_versions(decision$install, root)
      specs <- ifelse(is.na(version), decision$install,
                      paste0(decision$install, "@", version))
      child(install_expr(root, specs, repos), "installing dependencies first")
    }
    if (nrow(decision$drop)) {
      log <- save_setup_log(raw$output, root)
      child(drop_expr(root, decision$drop$package), "leaving packages out")
      for (i in seq_len(nrow(decision$drop))) {
        missing[nrow(missing) + 1L, ] <- list(
          decision$drop$package[i], decision$drop$reason[i],
          decision$drop$because[i], log
        )
      }
    }
  }
}
```

The `round > max_rounds` branch is the run after the last healing round. If it
still fails, there is nothing left to try, and `abort_stage()` stops with the
real output.

- [ ] **Step 4: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "heal")'` and lint `R/heal.R`.
Expected: PASS and no lints. If the cap test's restore count differs, recount
against the loop above before changing either the test or the loop, and
report which you changed and why.

- [ ] **Step 5: Mutation**

Temporarily make `plan_round()` return
`list(move = character(), install = character(), drop = data.frame(package =
character(), reason = character(), because = character()), stop = failures$package)`.
Confirm the healing and degrading tests fail, then revert. Record the output.

- [ ] **Step 6: Commit**

```bash
git add R/heal.R tests/testthat/test-heal.R
git commit -m "setup: heal a failing restore round by round, leaving out what cannot heal"
```

---

### Task B5: The setup record and the log location

**Files:**
- Modify: `R/heal.R`
- Modify: `R/setup.R` (`save_setup_log()`)
- Modify: `tests/testthat/test-heal.R`

**Interfaces:**
- Produces:
  - `save_setup_log(output, root = NULL)`. With `root`, it writes under
    `renv/logs/` and returns a path relative to `root`. Without `root`, it
    keeps today's `tempdir()` behavior and returns an absolute path.
  - `write_setup_record(root, healed, missing, backup, cleanup)` writes
    `renv/hvtiR-setup.dcf` and returns its path invisibly.
  - `read_setup_record(root)` returns `list(run, healed, missing, cleanup)`
    as data.frames, or `NULL` when there is no record.

- [ ] **Step 1: Write the failing tests**

```r
test_that("save_setup_log keeps logs in the study when given its root", {
  root <- local_lock()
  rel <- save_setup_log("line one", root)
  expect_match(rel, "^renv/logs/setup-.*\\.log$")
  expect_identical(readLines(file.path(root, rel)), "line one")
  expect_true(startsWith(save_setup_log("x"), tempdir()))
})

test_that("the setup record round-trips healed, missing and cleanup", {
  root <- local_lock()
  healed <- data.frame(package = "vctrs", from = "0.7.2", to = "0.7.3",
                       round = 1L, stringsAsFactors = FALSE)
  missing <- data.frame(package = "forecast", reason = "needs tseries",
                        because = "tseries", log = "renv/logs/x.log",
                        stringsAsFactors = FALSE)
  write_setup_record(root, healed, missing, "renv/renv.lock.before-setup-1",
                     list(status = "done", left = "a/tp.x"))
  rec <- read_setup_record(root)
  expect_identical(rec$run$LockBackup, "renv/renv.lock.before-setup-1")
  expect_identical(rec$healed$Package, "vctrs")
  expect_identical(rec$healed$To, "0.7.3")
  expect_identical(rec$missing$Package, "forecast")
  expect_identical(rec$missing$Because, "tseries")
  expect_identical(rec$cleanup$Status, "done")
})

test_that("no record reads as NULL, and an empty run writes only the run", {
  root <- local_lock()
  expect_null(read_setup_record(root))
  empty <- data.frame()
  write_setup_record(root, empty, empty, NA_character_, NULL)
  rec <- read_setup_record(root)
  expect_identical(nrow(rec$missing), 0L)
  expect_identical(rec$cleanup$Status, "off")
})

test_that("an older hvtiRutilities cleanup shape still records", {
  root <- local_lock()
  write_setup_record(root, data.frame(), data.frame(), NA_character_,
                     list(deleted = "a", removed_dirs = character()))
  expect_identical(read_setup_record(root)$cleanup$Status, "done")
})
```

- [ ] **Step 2: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "heal")'`
Expected: FAIL, functions not found, and the `save_setup_log` test fails on
the unused argument.

- [ ] **Step 3: Implement**

Replace `save_setup_log()` in `R/setup.R`:

```r
save_setup_log <- function(output, root = NULL) {
  name <- paste0("setup-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".log")
  if (is.null(root)) {
    path <- file.path(tempdir(), paste0("hvtiR-", name))
  } else {
    dir.create(file.path(root, "renv", "logs"), recursive = TRUE,
               showWarnings = FALSE)
    rel <- file.path("renv", "logs", name)
    path <- file.path(root, rel)
  }
  writeBin(charToRaw(enc2native(paste0(output, collapse = "\n"))), path)
  if (is.null(root)) path else rel
}
```

Keep its roxygen, adding `@param root`. Then, in `abort_stage()`, change each
`save_setup_log(raw)` to `save_setup_log(raw, root)`. Its message then shows
the study-relative path, a file the team can open. Leave the other existing
callers unchanged.

Append to `R/heal.R`:

```r
#' Write `renv/hvtiR-setup.dcf`, the study's record of its last setup
#'
#' DCF, read with [read.dcf()], because hvtiR imports nothing to read JSON.
#' One record per line of fact, each with a `Type`.
#' @param root The study root.
#' @param healed,missing From [heal_restore()], plus any packages the install
#'   and check stages left out.
#' @param backup The lock backup's relative path, or `NA`.
#' @param cleanup `attr(, "cleanup")` from `study_setup()`, of either shape,
#'   or `NULL` when cleanup was off.
#' @return The record's path, invisibly.
#' @noRd
write_setup_record <- function(root, healed, missing, backup, cleanup) {
  field <- function(name, value) {
    if (is.null(value) || !length(value) || is.na(value[1L])) return(NULL)
    paste0(name, ": ", gsub("\n", " ", paste(value, collapse = ", ")))
  }
  block <- function(...) c(..., "")
  run <- block(
    "Type: run", field("At", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    field("User", Sys.info()[["user"]]),
    field("R", as.character(getRversion())),
    field("hvtiR", hvtir_version()),
    field("LockBackup", backup)
  )
  rows <- function(df, type, cols) {
    unlist(lapply(seq_len(NROW(df)), function(i) {
      block(paste0("Type: ", type), unlist(lapply(names(cols), function(k) {
        field(k, df[[cols[[k]]]][i])
      })))
    }))
  }
  status <- if (is.null(cleanup)) "off" else if (is.null(cleanup$status)) {
    "done"
  } else {
    cleanup$status
  }
  lines <- c(
    run,
    rows(healed, "healed",
         c(Package = "package", From = "from", To = "to", Round = "round")),
    rows(missing, "missing",
         c(Package = "package", Reason = "reason", Because = "because",
           Log = "log")),
    block("Type: cleanup", field("Status", status),
          field("Reason", cleanup$reason), field("Left", cleanup$left))
  )
  path <- file.path(root, "renv", "hvtiR-setup.dcf")
  dir.create(dirname(path), showWarnings = FALSE)
  writeLines(lines, path)
  invisible(path)
}

#' Read `renv/hvtiR-setup.dcf`
#' @param root The study root.
#' @return `list(run, healed, missing, cleanup)` of data.frames, or `NULL`.
#' @noRd
read_setup_record <- function(root) {
  path <- file.path(root, "renv", "hvtiR-setup.dcf")
  if (!file.exists(path)) return(NULL)
  all <- as.data.frame(read.dcf(path), stringsAsFactors = FALSE)
  pick <- function(type) {
    out <- all[all$Type == type, , drop = FALSE]
    out <- out[, colSums(!is.na(out)) > 0L, drop = FALSE]
    rownames(out) <- NULL
    out
  }
  list(run = pick("run"), healed = pick("healed"), missing = pick("missing"),
       cleanup = pick("cleanup"))
}
```

`hvtir_version()` is defined in `R/status.R`. Check the name before using it.
If `read.dcf` is flagged as an undeclared import, call it as
`base::read.dcf`. It is in base, not utils.

- [ ] **Step 4: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "heal|setup")'` and lint.
Expected: PASS. Existing setup tests that match "Full output:" with a
`tempdir()` path still pass: only `abort_stage()` changed, and its tests match
the label, not the path. Fix any that pinned the path, and list them.

- [ ] **Step 5: Commit**

```bash
git add R/heal.R R/setup.R tests/testthat/test-heal.R
git commit -m "setup: keep logs in the study and write a setup record"
```

---

### Task B6: Wire healing and leaving-out into setup()

**Files:**
- Modify: `R/setup.R`:
  - `setup()`;
  - the `optional_extras()` definition and roxygen, which are removed;
  - `environment_extras()` roxygen, if it mentions `optional_extras()`.
- Modify: `tests/testthat/test-setup.R` (the `local_setup()` harness and the
  three hvtiR#157 optional-extra tests)

**Interfaces:**
- Consumes:
  - `heal_restore()` (B4);
  - `write_setup_record()` and `save_setup_log(, root)` (B5);
  - `attr(status, "cleanup")` from hvtiRutilities (A1/A2), in either shape.
- Produces: `setup()` returns the status invisibly, with `attr(, "healed")`
  and `attr(, "missing")` as data.frames. When `missing` is not empty, it
  warns instead of reporting success, and still calls `open_project()`.

- [ ] **Step 1: Adapt the harness**

In `local_setup()`, the `run_in_study` mock answers a restore by matching
`"HVTIR_LOCKVER"`, and that expression now comes from `heal_restore()`. Nothing
changes for the success path. Add a parameter
`restore_outputs = NULL`, a list. When it is given, successive restore calls
pop it (`"ok"` means status 0 with the default `HVTIR_LIB`/`HVTIR_LOCKVER`
output), and record, install and drop expressions are answered with status 0
and `HVTIR_RECORDED=` echoing the specs. Record each kind in `log$steps`
(`"record"`, `"install"`, `"drop"`). Also mock
`save_setup_log = function(output, root = NULL) "renv/logs/x.log"` and
`write_setup_record = function(...) { log$record <- list(...); invisible() }`.

- [ ] **Step 2: Write the failing tests**

Append to `tests/testthat/test-setup.R`:

```r
test_that("a healed restore finishes, records the move and opens the project", {
  root <- withr::local_tempdir()
  writeLines('{"Packages": {"vctrs": {"Package": "vctrs", "Version": "0.7.2", "Source": "Repository"}}}',
             file.path(root, "renv.lock"))
  log <- local_setup(restore_outputs = list(
    "ERROR: compilation failed for package ‘vctrs’", "ok"))
  status <- setup("A study", 7L, root = root)
  expect_true(all(c("record", "open") %in% log$steps))
  expect_identical(attr(status, "healed")$package, "vctrs")
  expect_identical(nrow(attr(status, "missing")), 0L)
})

test_that("an optional package that cannot install warns and still opens", {
  root <- withr::local_tempdir()
  log <- local_setup(pak_error = NULL)
  local_mocked_bindings(pak_install_lib = function(specs, lib, repos = NULL) {
    if (identical(specs, install_specs("survminer"))) stop("compile failed")
    invisible(NULL)
  })
  expect_warning(status <- setup("A study", 7L, root = root),
                 "set up without 1 package")
  expect_identical(attr(status, "missing")$package, "survminer")
  expect_true("open" %in% log$steps)
})

test_that("a family member that cannot install still stops setup", {
  root <- withr::local_tempdir()
  log <- local_setup(pak_error = "member build failed")
  expect_error(setup("A study", 7L, root = root),
               "Installing the study's packages failed")
  expect_false("open" %in% log$steps)
})

test_that("a missing dependency of an optional package leaves it out", {
  root <- withr::local_tempdir()
  log <- local_setup(gone = data.frame(package = "forecast",
                                       missing = "tseries"))
  expect_warning(status <- setup("A study", 7L, root = root),
                 "forecast")
  expect_identical(attr(status, "missing")$because, "tseries")
})

test_that("a family member missing a dependency still stops", {
  root <- withr::local_tempdir()
  log <- local_setup(gone = data.frame(package = "hvtiRutilities",
                                       missing = "yaml"))
  expect_error(setup("A study", 7L, root = root), "missing dependencies")
})

test_that("every run writes the setup record, with the cleanup it was given", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  expect_false(is.null(log$record))
})
```

Then rewrite the three hvtiR#157 tests ("an optional extra that fails to install
warns, and setup goes on", "the optional-extra warning carries pak's message",
"a failure installing the other packages still stops setup") against the
general rule:

- an arrow failure now produces the general warning naming `arrow`;
- the general warning or the record carries pak's message (the record's
  `reason` holds its first line);
- a failure of a family member still stops.

Keep their names recognizable, and say in the report how each was rewritten.

- [ ] **Step 3: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: the new tests FAIL. `setup()` still aborts at the restore, has no
`missing` attribute, and stops on `gone`.

- [ ] **Step 4: Implement** in `setup()`:

1. Directly after `utilities_fn("study_declare")(packages, root = root)`, add
   `essential <- c("hvtiR", members()$package)`.
2. Replace

```r
  first <- run_in_study(restore_expr(root, repos), root)
  first_raw <- first$output
  first$output <- iconv(first_raw, "UTF-8", "UTF-8", sub = "?")
  abort_stage(first, first_raw, root, upgrade)
```

with

```r
  heal <- heal_restore(root, repos, upgrade, essential)
  first <- heal$result
  first_raw <- heal$raw
  missing <- heal$missing
```

3. Replace the install block from `optional <- intersect(wanted,
   optional_extras())` through the end of the `for (pkg in optional)` loop
   with:

```r
  family_wanted <- intersect(wanted, family)
  others <- setdiff(wanted, family)
  add <- install_specs(family_wanted)
  if (length(add)) {
    tryCatch(
      pak_install_lib(add, project_lib, repos),
      error = function(e) {
        msg <- conditionMessage(e)
        auth <- grepl("authentication credentials", msg, fixed = TRUE)
        cli::cli_abort(c(
          "Installing the study's packages failed.",
          if (auth) c("A GitHub token is needed.", github_credentials_hint()),
          output_bullets(msg)
        ))
      }
    )
  }
  # Everything outside the family may be left out: one call first, then one
  # at a time so a single failure leaves out only itself.
  if (length(others)) {
    together <- tryCatch(
      {
        pak_install_lib(install_specs(others), project_lib, repos)
        TRUE
      },
      error = function(e) FALSE
    )
    if (!together) {
      for (pkg in others) {
        tryCatch(
          pak_install_lib(install_specs(pkg), project_lib, repos),
          error = function(e) {
            msg <- conditionMessage(e)
            # pak's staging folder, left by a failed install, trips the
            # snapshot.
            staging <- intersect(library_debris(project_lib), "_cache")
            unlink(file.path(project_lib, staging), recursive = TRUE)
            missing[nrow(missing) + 1L, ] <<- list(
              pkg, strsplit(msg, "\n", fixed = TRUE)[[1L]][1L], NA_character_,
              save_setup_log(msg, root)
            )
          }
        )
      }
    }
  }
```

   Use `<<-` only if `missing` is in the enclosing function's frame and lintr
   accepts it. Otherwise collect failures from a `vapply` or `for` loop that
   returns the error message, and append afterwards. Report which you used.
4. Replace the `gone` block after `unresolved_imports()` with:

```r
  if (nrow(gone)) {
    stuck <- gone[gone$package %in% essential, , drop = FALSE]
    if (nrow(stuck)) {
      bullets <- paste(stuck$package, "needs", stuck$missing)
      names(bullets) <- rep("x", nrow(stuck))
      cli::cli_abort(c(
        "Packages in the study's library are missing dependencies:",
        bullets
      ))
    }
    for (i in seq_len(nrow(gone))) {
      missing[nrow(missing) + 1L, ] <- list(
        gone$package[i], paste("needs", gone$missing[i]), gone$missing[i],
        NA_character_
      )
    }
  }
```

5. Replace `cli::cli_alert_success("The study's environment is set up.")`
   with:

```r
  write_setup_record(root, heal$healed, missing, heal$backup,
                     attr(status, "cleanup"))
  if (nrow(heal$healed)) {
    moves <- paste0(heal$healed$package, " ", heal$healed$from, " -> ",
                    heal$healed$to, " (round ", heal$healed$round, ")")
    cli::cli_alert_info(paste(
      "Moved {nrow(heal$healed)} pin{?s} that would not build under this R;",
      "the old lock is {.file {heal$backup}}."
    ))
    cli::cli_bullets(stats::setNames(moves, rep("*", length(moves))))
  }
  if (nrow(missing)) {
    cli::cli_warn(c(
      paste(
        "The study is set up without {nrow(missing)} package{?s}:",
        "{.pkg {missing$package}}."
      ),
      stats::setNames(
        paste0(missing$package, ": ", missing$reason),
        rep("x", nrow(missing))
      ),
      i = "Jobs that load them stop until they install.",
      i = paste(
        "Rerun {.fn hvtiR::setup} to try them again; details in",
        "{.file renv/hvtiR-setup.dcf}."
      )
    ))
  } else {
    cli::cli_alert_success("The study's environment is set up.")
  }
  attr(status, "healed") <- heal$healed
  attr(status, "missing") <- missing
```

   This goes before `open_project(root)`. Escape `{`/`}` in `reason` with the
   same `gsub` pattern `abort_stage()` uses, because a reason is untrusted
   output.
6. Delete `optional_extras()` and its roxygen. Grep for remaining uses with
   `grep -rn optional_extras R tests` and remove or rewrite each one.

- [ ] **Step 5: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "setup|heal")'` and lint `R/`.
Expected: FAIL 0, and WARN no higher than before. The pre-existing
`hvtir_pwned` warning remains, and any new warning must be captured by an
`expect_warning()`.

- [ ] **Step 6: Mutation**

Make `heal_restore()` call `abort_stage()` on any failure, as today. Confirm
"a healed restore finishes…" fails. Revert. Then make the per-package install
loop rethrow instead of recording. Confirm "an optional package that cannot
install…" fails. Revert. Record both.

- [ ] **Step 7: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R
git commit -m "setup: heal the restore, leave out optional packages, finish with a usable study"
```

---

### Task B7: doctor() reports the record; docs, news and gates

**Files:**
- Modify: `R/status.R` (`doctor()`)
- Modify: `tests/testthat/test-doctor.R`
- Modify: `R/setup.R` (`setup()` roxygen)
- Modify: `man/setup.Rd`, `man/doctor.Rd` (regenerated)
- Modify: `vignettes/study-environment.qmd` ("Common problems" table)
- Create: `news/feat-robust-setup.md`

- [ ] **Step 1: Write the failing doctor tests**

```r
test_that("doctor lists packages the last setup left out", {
  root <- withr::local_tempdir()
  file.create(file.path(root, "_study.yml"))
  write_setup_record(
    root, data.frame(),
    data.frame(package = "forecast", reason = "needs tseries",
               because = "tseries", log = "renv/logs/x.log",
               stringsAsFactors = FALSE),
    NA_character_, NULL
  )
  withr::local_dir(root)
  out <- paste(capture.output(doctor(remote = FALSE), type = "message"),
               collapse = "\n")
  expect_match(out, "forecast")
  expect_match(out, "needs tseries")
})

test_that("doctor says nothing about setup with no record", {
  withr::local_dir(withr::local_tempdir())
  out <- paste(capture.output(doctor(remote = FALSE), type = "message"),
               collapse = "\n")
  expect_no_match(out, "left out")
})
```

First check how `test-doctor.R` already captures `doctor()` output, and use
the same method in place of `capture.output(..., type = "message")` if it
differs.

- [ ] **Step 2: Run them and see them fail, then implement**

In `doctor()`, after the renv state block inside `cli::cli_fmt({ ... })`, add:

```r
    study <- enclosing_study()
    record <- if (is.null(study)) NULL else read_setup_record(study)
    if (!is.null(record) && nrow(record$missing)) {
      cli::cli_h2("Study setup")
      cli::cli_alert_warning(paste(
        "The last {.fn setup} ({record$run$At}) left out",
        "{nrow(record$missing)} package{?s}; jobs that load them stop."
      ))
      for (i in seq_len(nrow(record$missing))) {
        cli::cli_alert_danger(paste0(
          "{.pkg ", record$missing$Package[i], "}: ",
          gsub("\\}", "}}", gsub("\\{", "{{", record$missing$Reason[i]))
        ))
      }
      cli::cli_alert_info("Rerun {.fn hvtiR::setup} to try them again.")
    }
```

Run: `Rscript -e 'devtools::test(filter = "doctor")'`
Expected: PASS.

- [ ] **Step 3: Roxygen for setup()**

Add one paragraph after the paragraph on renv's explicit mode:

```r
#' When an install fails, `setup()` heals what it safely can and leaves out
#' what it cannot. A package whose locked version will not compile under
#' this R moves to the newest version the study's repositories serve (only
#' with `upgrade = TRUE`), and a missing dependency is installed first; it
#' retries up to ten rounds. A package outside the family that still fails is
#' left out of `renv.lock`, stays declared, and is listed in
#' `renv/hvtiR-setup.dcf`; `setup()` then finishes, warns, and opens the
#' project, and a rerun tries it again. A family member that cannot install
#' still stops `setup()`. `renv.lock` is copied to
#' `renv/renv.lock.before-setup-<time>` before healing changes it.
```

Also add to `@return`: "with attributes `healed` and `missing`, data frames
of the pins moved and the packages left out." Run
`Rscript -e 'devtools::document()'` and revert any `RoxygenNote` bump.

- [ ] **Step 4: Troubleshooting row**

In `vignettes/study-environment.qmd` "Common problems", add the row

```
| `setup()` warns that the study is set up without some packages | They would not install. Jobs that load them stop. `hvtiR::doctor()` lists them and why; rerun `hvtiR::setup()` to try again, or install one by hand in the study and run `renv::snapshot()` |
```

- [ ] **Step 5: News fragment** `news/feat-robust-setup.md`:

```markdown
* `setup()` no longer stops when a package will not install. A locked version
  that will not compile under this R moves to the newest version the study's
  repositories serve (with `upgrade = TRUE`, the default), and a missing
  dependency is installed first, for up to ten rounds. A package outside the
  family that still fails is left out of `renv.lock`, listed in
  `renv/hvtiR-setup.dcf`, and named in a warning; the study is set up and the
  project opens. A rerun tries it again. A family member that cannot install
  still stops `setup()`.
* `setup()` copies `renv.lock` to `renv/renv.lock.before-setup-<time>` before
  healing changes it, and keeps its logs in `renv/logs/`.
* `doctor()` lists the packages the last `setup()` left out, and why.
```

- [ ] **Step 6: Gates**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'lintr::lint_package()'
Rscript -e 'devtools::check()'
```

Expected: FAIL 0, WARN only the pre-existing one, lint clean, check 0/0/0.
If check loads a stale system-library hvtiRutilities, say so. The folder-list
test already guards that case.

- [ ] **Step 7: Commit**

```bash
git add R/status.R R/setup.R man/setup.Rd man/doctor.Rd \
  tests/testthat/test-doctor.R vignettes/study-environment.qmd \
  news/feat-robust-setup.md
git commit -m "setup: document healing, leaving out, and doctor's report"
```

---

### Task B8: Acceptance on lri (John runs it)

No code changes. The controller writes these commands into the PR body. John
runs them on lri with **R 4.6.1** and the PR branch installed. Install it on
lri with `pak::pak("ehrlinger/hvtiR@feat/robust-setup")`.

```bash
mkdir -p /studies/general/_development/robust-setup-check
cp <the Hsich R 4.5.1 renv.lock from before 2026-10-29> /studies/general/_development/robust-setup-check/renv.lock
```

The pre-heal lock may survive as a backup in the study's `renv/` folder or in
its history. John knows where it is. If none survives, use any R 4.5-era lock
that pins `vctrs` 0.7.2.

```r
hvtiR::setup(
  study = "Robust setup check", study_tracker_id = 1L,
  root = "/studies/general/_development/robust-setup-check",
  adopt = TRUE, cleanup = FALSE
)
```

**Pass when all of these hold:**
- it finishes and opens the project, with no manual `renv::record()`;
- `renv/hvtiR-setup.dcf` lists the moved pins (vctrs among them) under
  `healed`;
- anything still failing is listed under `missing`, with a reason;
- `renv/renv.lock.before-setup-*` equals the copied lock;
- `hvtiR::doctor()` in that project lists the same `missing`.

Delete the scratch study afterwards.

---

### Task B9: Review and PR

- [ ] **Step 1:** Run the final review of the whole branch, with the Minor
  findings from the per-task reviews.
- [ ] **Step 2:** Push and open the PR against `main`. The body carries:
  - the Task B8 commands;
  - the Part A dependency: "needs hvtiRutilities ≥ <Part A release> for the
    cleanup warnings; `UTILITIES_FLOOR` moves in hvtiR's bump";
  - the plan's three deviations from the spec;
  - that the review stood in for Copilot if its quota is still out.
- [ ] **Step 3:** Leave the version bump, the floor move and the merge to John.
