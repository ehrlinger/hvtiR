# Project-aware `setup()` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When `hvtiR::setup()` is run with no `root`, no `_study.yml` above the
working directory and the working directory is an RStudio project root, it
offers to adopt that folder as the study.

**Architecture:** Implements
[2026-11-05-setup-adopt-project-design.md](2026-11-05-setup-adopt-project-design.md).
All changes are in `R/setup.R`. A new branch at the top of `setup()` resolves the
candidate, refuses folders that are not study roots, confirms the adoption (by
prompt, by `adopt = TRUE`, or by a stop that prints the call when
non-interactive), and then sets `root` and `adopt = TRUE` before
`guard_session()` runs. The command string `guard_session()` builds becomes a
helper, `setup_command()`, so that both stops quote the call the same way.

**Tech Stack:** R, cli, rstudioapi (already in Imports), testthat 3 with
`local_mocked_bindings()`, withr.

## Global Constraints

- Work in the worktree `~/Documents/GitHub/hvtiR-adopt-project`. Create the
  branch `feat/setup-adopt-project` from `docs/setup-adopt-project-design`
  (the spec and this plan ride along in one PR). Never commit to `main`.
- Lines ≤ 80 characters: hvtiR has no `.lintr`, so lintr's defaults apply.
- Roxygen is markdown (`Roxygen: list(markdown = TRUE)`): backticks are fine.
  Every new internal helper gets `@noRd`.
- Do not edit `vignettes/start-here.qmd`. The session that owns hvtiR PR #174
  (`docs/quick-start-172-173`) is editing it, and the quick-start wording for
  this feature has been sent there.
- Do not bump `Version:` and do not edit `NEWS.md`. Write the entry to
  `news/feat-setup-adopt-project.md` (bullets only, no heading).
- `git add` only the named files, never `-A`: a failing testthat run writes
  `tests/testthat/_problems/`.
- Run the tests from the worktree:
  `Rscript -e 'devtools::test(filter = "setup")'`. This is a package repo, so
  running on the Mac is allowed.
- The default prompt answer is **No**. `setup()` never adopts in a
  non-interactive session unless `adopt = TRUE` is passed.

---

### Task 1: Find and vet the candidate folder

**Files:**
- Modify: `R/setup.R` (new helpers placed directly above `abort_no_study()`)
- Test: `tests/testthat/test-setup.R` (append at the end)

**Interfaces:**
- Produces:
  - `STUDY_FOLDERS`, a named character vector of the seven study folders.
  - `active_project()` returns the RStudio project path or `NULL`.
  - `project_candidate(dir = getwd())` returns the normalized `dir` when it is a
    project root, otherwise `NULL`.
  - `refuse_candidate(candidate)` returns `candidate` invisibly, or aborts with
    class `hvtiR_adopt_refused`.

- [ ] **Step 1: Create the branch**

```bash
cd ~/Documents/GitHub/hvtiR-adopt-project
git checkout -b feat/setup-adopt-project
```

- [ ] **Step 2: Write the failing tests**

Append to `tests/testthat/test-setup.R`:

```r
test_that("a folder holding a .Rproj is a project candidate", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "study.Rproj"))
  expect_identical(
    project_candidate(dir), normalizePath(dir, winslash = "/")
  )
})

test_that("RStudio's active project is a candidate without a .Rproj", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(active_project = function() dir)
  expect_identical(
    project_candidate(dir), normalizePath(dir, winslash = "/")
  )
})

test_that("a plain folder, or one below the project, is no candidate", {
  dir <- withr::local_tempdir()
  sub <- file.path(dir, "sub")
  dir.create(sub)
  file.create(file.path(dir, "study.Rproj"))
  local_mocked_bindings(active_project = function() dir)
  expect_null(project_candidate(sub))
})

test_that("a study subfolder is refused, numbered or bare", {
  for (name in c("30_analyses", "analyses")) {
    dir <- file.path(withr::local_tempdir(), name)
    dir.create(dir)
    expect_error(refuse_candidate(dir), class = "hvtiR_adopt_refused")
  }
})

test_that("a package DESCRIPTION is refused, a study's is not", {
  dir <- withr::local_tempdir()
  desc <- file.path(dir, "DESCRIPTION")
  writeLines(c("Package: x", "Version: 1.0.0"), desc)
  expect_error(refuse_candidate(dir), class = "hvtiR_adopt_refused")
  writeLines(c("Type: Project", "Depends: hvtiR"), desc)
  expect_identical(refuse_candidate(dir), dir)
})

test_that("the study folder list matches hvtiRutilities", {
  skip_if_not_installed("hvtiRutilities")
  expect_identical(
    STUDY_FOLDERS,
    getFromNamespace(".study_folders", "hvtiRutilities")()
  )
})
```

`getFromNamespace()` rather than `:::` keeps `R CMD check` from noting an
internal call.

- [ ] **Step 3: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: FAIL, `could not find function "project_candidate"` (and likewise
for `refuse_candidate` and `STUDY_FOLDERS`).

- [ ] **Step 4: Implement**

Insert into `R/setup.R` directly above the `#' Stop because \`setup()\` has no
study to write to` block:

```r
#' A study's folders, numbered and bare
#'
#' A copy of the internal `hvtiRutilities:::.study_folders()`; a test fails
#' when the two differ.
#' @noRd
STUDY_FOLDERS <- c(
  datasets = "00_datasets", descriptive = "10_descriptive",
  distributions = "20_distributions", analyses = "30_analyses",
  graphs = "40_graphs", documents = "50_documents",
  estimates = "90_estimates"
)

#' The RStudio project open in this session
#' @return A path, or `NULL` outside RStudio or with no project open.
#' @noRd
active_project <- function() {
  if (!rstudio_available()) return(NULL)
  tryCatch(rstudioapi::getActiveProject(), error = function(e) NULL)
}

#' The working directory, when it is a project root `setup()` may adopt
#'
#' Only `dir` itself is looked at: a project above it is not this
#' session's project.
#' @param dir The folder to test.
#' @return `dir`, normalized, or `NULL`.
#' @noRd
project_candidate <- function(dir = getwd()) {
  dir <- normalizePath(dir, winslash = "/", mustWork = TRUE)
  rproj <- list.files(dir, pattern = "[.]Rproj$", all.files = TRUE)
  if (length(rproj)) return(dir)
  active <- active_project()
  if (!is.null(active) &&
        identical(normalizePath(active, winslash = "/", mustWork = FALSE),
                  dir)) {
    return(dir)
  }
  NULL
}

#' Stop when a candidate folder cannot be a study root
#' @param candidate The folder `project_candidate()` returned.
#' @return `candidate`, invisibly.
#' @noRd
refuse_candidate <- function(candidate) {
  name <- basename(candidate)
  if (name %in% c(names(STUDY_FOLDERS), STUDY_FOLDERS)) {
    cli::cli_abort(c(
      "{.path {candidate}} is a study's {.file {name}} folder, not a study.",
      i = paste(
        "Open {.path {dirname(candidate)}} as the project instead, then",
        "run {.fn setup} again."
      )
    ), class = "hvtiR_adopt_refused", call = NULL)
  }
  desc <- file.path(candidate, "DESCRIPTION")
  if (file.exists(desc)) {
    type <- tryCatch(
      unname(read.dcf(desc, fields = "Type")[1L, 1L]),
      error = function(e) NA_character_
    )
    if (!identical(type, "Project")) {
      cli::cli_abort(c(
        "{.path {candidate}} holds a package {.file DESCRIPTION}, not a study.",
        i = "Pass {.arg root} to name the study folder."
      ), class = "hvtiR_adopt_refused", call = NULL)
    }
  }
  invisible(candidate)
}
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: the six new tests PASS, and every existing setup test still passes.
The last test SKIPs only if hvtiRutilities is not installed; if it skips,
install hvtiRutilities and rerun, since a skip here means the copy is unchecked.

- [ ] **Step 6: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R
git commit -m "setup: find and vet a project folder to adopt"
```

---

### Task 2: Extract `setup_command()` from `guard_session()`

This is a pure refactor, needed so that Task 3's non-interactive stop quotes the
call exactly as the guard does.

**Files:**
- Modify: `R/setup.R` (`guard_session()`, about lines 1085–1135)
- Test: `tests/testthat/test-setup.R`

**Interfaces:**
- Produces: `setup_command(root, study, study_tracker_id, adopt = FALSE,
  workspace_prefs = TRUE, upgrade = TRUE, dots = list())`, which returns
  `character(1)`, a deparsed `hvtiR::setup(...)` call.

- [ ] **Step 1: Write the failing test**

```r
test_that("setup_command names every formal once dots carry anything", {
  expect_identical(
    setup_command("/s", "A", 7L),
    'hvtiR::setup(root = "/s", study = "A", study_tracker_id = 7L)'
  )
  expect_identical(
    setup_command("/s", "A", 7L, adopt = TRUE),
    paste0('hvtiR::setup(root = "/s", study = "A", study_tracker_id = 7L, ',
           "adopt = TRUE)")
  )
  expect_match(
    setup_command("/s", "A", 7L, dots = list(cleanup = FALSE)),
    "adopt = FALSE, workspace_prefs = TRUE, upgrade = TRUE, cleanup = FALSE",
    fixed = TRUE
  )
})
```

- [ ] **Step 2: Run it and see it fail**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: FAIL, `could not find function "setup_command"`.

- [ ] **Step 3: Implement**

Add above `guard_session()`:

```r
#' The `setup()` call to quote back in a stop
#'
#' Every formal is named once `dots` carries anything: one left off would
#' take an unnamed argument by position, or a short name by partial matching.
#' @param root,study,study_tracker_id,adopt,workspace_prefs,upgrade As for
#'   [setup()].
#' @param dots `list(...)` from [setup()].
#' @return The call, deparsed.
#' @noRd
setup_command <- function(root, study, study_tracker_id, adopt = FALSE,
                          workspace_prefs = TRUE, upgrade = TRUE,
                          dots = list()) {
  all_formals <- length(dots) > 0L
  deparse1(as.call(c(
    list(quote(hvtiR::setup)),
    list(root = root, study = study, study_tracker_id = study_tracker_id),
    if (all_formals || isTRUE(adopt)) list(adopt = adopt),
    if (all_formals || isFALSE(workspace_prefs)) {
      list(workspace_prefs = workspace_prefs)
    },
    if (all_formals || isFALSE(upgrade)) list(upgrade = upgrade),
    dots
  )))
}
```

In `guard_session()`, replace the block from `# Name every formal when` through
the closing `)))` of `cmd <- deparse1(...)` with:

```r
  # Read by cli's glue below, which lintr cannot see.
  # nolint next: object_usage_linter.
  cmd <- setup_command(
    target, study, study_tracker_id, adopt, workspace_prefs, upgrade, dots
  )
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: PASS, including the existing guard tests ("setup refuses to run from
inside the study's own library" and the `fix/setup-guard-carries-dots`
tests), which pin the command the guard prints.

- [ ] **Step 5: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R
git commit -m "setup: build the quoted setup() call in one helper"
```

---

### Task 3: Confirm the adoption and wire it into `setup()`

**Files:**
- Modify: `R/setup.R` (new helpers after `refuse_candidate()`, and the body of
  `setup()` just before `guard_session(`)
- Test: `tests/testthat/test-setup.R`

**Interfaces:**
- Consumes: `project_candidate()`, `refuse_candidate()` (Task 1),
  `setup_command()` (Task 2), and the existing `enclosing_study()`,
  `abort_no_study()`.
- Produces:
  - `is_interactive()`, a seam over `interactive()`.
  - `ask_adopt_project(question)`, a seam over
    `utils::askYesNo(question, default = FALSE)`.
  - `adopt_project(candidate, study, study_tracker_id, adopt, workspace_prefs,
    upgrade, dots)`, which returns `candidate` or aborts with class
    `hvtiR_adopt_declined` or `hvtiR_adopt_unconfirmed`. The unconfirmed
    condition carries a field `command`.

- [ ] **Step 1: Write the failing tests**

These use the file's existing `local_setup()` harness. It mocks
`utilities_fn()` (recording `log$setup_args`), `cheap_study_root()`,
`renv_state()` and `set_workspace_prefs()` (logged as step `"prefs"`).

```r
local_project <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file.create(file.path(dir, "study.Rproj"))
  withr::local_dir(dir, .local_envir = env)
  normalizePath(dir, winslash = "/")
}

test_that("in a project with no study, Yes adopts the project folder", {
  dir <- local_project()
  log <- local_setup()
  asked <- NULL
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) {
      asked <<- question
      TRUE
    }
  )
  setup("A study", 7L)
  expect_identical(
    normalizePath(log$setup_args$root, winslash = "/"), dir
  )
  expect_true(log$setup_args$adopt)
  expect_match(asked, "tp.*", fixed = TRUE)
  expect_match(asked, "Study Tracker 7", fixed = TRUE)
})

test_that("No leaves everything as it was, RStudio preferences too", {
  local_project()
  log <- local_setup()
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) FALSE
  )
  expect_error(setup("A study", 7L), class = "hvtiR_adopt_declined")
  expect_identical(log$steps, character(0))
})

test_that("a cancelled prompt counts as No", {
  local_project()
  log <- local_setup()
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) NA
  )
  expect_error(setup("A study", 7L), class = "hvtiR_adopt_declined")
})

test_that("cleanup = FALSE drops the deletion warning from the prompt", {
  local_project()
  local_setup()
  asked <- NULL
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) {
      asked <<- question
      TRUE
    }
  )
  setup("A study", 7L, cleanup = FALSE)
  expect_no_match(asked, "tp.*", fixed = TRUE)
})

test_that("adopt = TRUE adopts the project folder without asking", {
  dir <- local_project()
  log <- local_setup()
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) stop("asked")
  )
  expect_message(setup("A study", 7L, adopt = TRUE), "adopting")
  expect_identical(
    normalizePath(log$setup_args$root, winslash = "/"), dir
  )
})

test_that("non-interactive, it stops and quotes the adopt call", {
  dir <- local_project()
  log <- local_setup()
  local_mocked_bindings(is_interactive = function() FALSE)
  err <- expect_error(
    setup("A study", 7L), class = "hvtiR_adopt_unconfirmed"
  )
  expect_identical(
    err$command,
    setup_command(dir, "A study", 7L, adopt = TRUE)
  )
  expect_identical(log$steps, character(0))
})

test_that("a refused folder stops before the prompt", {
  dir <- file.path(withr::local_tempdir(), "30_analyses")
  dir.create(dir)
  file.create(file.path(dir, "study.Rproj"))
  withr::local_dir(dir)
  local_setup()
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) stop("asked")
  )
  expect_error(setup("A study", 7L), class = "hvtiR_adopt_refused")
})

test_that("an enclosing study wins over a project inside it", {
  parent <- withr::local_tempdir()
  file.create(file.path(parent, "_study.yml"))
  child <- file.path(parent, "inner")
  dir.create(child)
  file.create(file.path(child, "inner.Rproj"))
  withr::local_dir(child)
  local_setup(root_error = "took the study branch")
  local_mocked_bindings(
    is_interactive = function() TRUE,
    ask_adopt_project = function(question) stop("asked")
  )
  expect_error(setup("A study", 7L), "took the study branch")
})

test_that("no project and no study still stops with no target", {
  withr::local_dir(withr::local_tempdir())
  local_setup()
  expect_error(setup("A study", 7L), "New Project")
})
```

`local_setup()` mocks `study_root` to `stop(root_error)`. In the
enclosing-study test, the error coming back means `setup()` took the existing
`study_root_or_abort()` branch and never reached the prompt, which would have
raised `"asked"`. `study_root_or_abort()` rewrites only the exact
`"no _study.yml found"` message, so the custom text comes through unchanged.

- [ ] **Step 2: Run them and see them fail**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: FAIL. The adopt tests get `abort_no_study()`'s error instead of
adopting, and the `"New Project"` test fails on the old wording.

- [ ] **Step 3: Implement the helpers**

Add to `R/setup.R` after `refuse_candidate()`:

```r
#' `interactive()`, as a seam the tests replace
#' @noRd
is_interactive <- function() interactive()

#' Ask whether to adopt the project folder, defaulting to No
#' @param question The prompt.
#' @return `TRUE`, `FALSE` or `NA` (cancelled).
#' @noRd
ask_adopt_project <- function(question) {
  utils::askYesNo(question, default = FALSE)
}

#' Confirm adopting the project folder as the study
#'
#' `adopt = TRUE` is the caller's confirmation; otherwise an interactive
#' session is asked and a non-interactive one stops, quoting the call.
#' @param candidate The folder `project_candidate()` returned.
#' @param study,study_tracker_id,adopt,workspace_prefs,upgrade As passed to
#'   [setup()].
#' @param dots `list(...)` from [setup()].
#' @return `candidate`.
#' @noRd
adopt_project <- function(candidate, study, study_tracker_id, adopt,
                          workspace_prefs, upgrade, dots) {
  refuse_candidate(candidate)
  if (isTRUE(adopt)) {
    cli::cli_alert_info(paste(
      "No {.file _study.yml} here; adopting the project folder",
      "{.path {candidate}}."
    ))
    return(candidate)
  }
  if (!is_interactive()) {
    cmd <- setup_command(
      candidate, study, study_tracker_id, TRUE, workspace_prefs, upgrade, dots
    )
    cli::cli_abort(c(
      paste(
        "{.path {candidate}} has no {.file _study.yml}, and {.fn setup}",
        "adopts a folder only when asked."
      ),
      i = "To adopt it, run: {.code {cmd}}"
    ), class = "hvtiR_adopt_unconfirmed", command = cmd, call = NULL)
  }
  question <- paste0(
    candidate, " has no _study.yml. Adopt it as study \"", study,
    "\" (Study Tracker ", study_tracker_id, ")?",
    if (!isFALSE(dots[["cleanup"]])) {
      paste(
        " Adopting deletes the tp.* files, binder.summaries.doc and exact",
        "template copies it holds; pass cleanup = FALSE to keep them."
      )
    }
  )
  if (!isTRUE(ask_adopt_project(question))) {
    cli::cli_abort(
      "Not adopted. Nothing was changed.",
      class = "hvtiR_adopt_declined", call = NULL
    )
  }
  candidate
}
```

`dots[["cleanup"]]` is used rather than `dots$cleanup` because `$` partially
matches list names.

- [ ] **Step 4: Wire it into `setup()` and reword `abort_no_study()`**

In `setup()`, directly above `guard_session(`, insert:

```r
  # The default path: a legacy study opened as its own RStudio project.
  # Resolved before the guard, so the guard and its quoted call name it.
  if (is.null(root) && is.null(enclosing_study())) {
    candidate <- project_candidate()
    if (is.null(candidate)) abort_no_study()
    root <- adopt_project(
      candidate, study, study_tracker_id, adopt, workspace_prefs, upgrade,
      list(...)
    )
    adopt <- TRUE
  }
```

Replace the body of `abort_no_study()` with:

```r
abort_no_study <- function() {
  cli::cli_abort(c(
    "No study encloses {.path {getwd()}}, so {.fn setup} has no target.",
    i = paste(
      "Open the study's folder as an RStudio project (File > New Project >",
      "Existing Directory) and run {.fn setup} there."
    ),
    i = "Or pass {.arg root}, the directory to set the study up in."
  ), call = NULL)
}
```

The existing `if (is.null(enclosing_study())) abort_no_study()` inside
`if (is.null(root))` further down stays. It is now reached only when a study
does enclose the working directory, so it never fires, but removing it is not
part of this change.

- [ ] **Step 5: Run the tests and see them pass**

Run: `Rscript -e 'devtools::test(filter = "setup")'`
Expected: every new test PASSES, and every existing setup and setup-e2e test
still passes.

- [ ] **Step 6: Prove the tests by mutation**

Temporarily change the first line of `project_candidate()`'s body to
`return(NULL)`, then rerun `Rscript -e 'devtools::test(filter = "setup")'`.
Expected: "Yes adopts", "No leaves everything", "adopt = TRUE adopts" and
"non-interactive" all FAIL. Revert the mutation with
`git checkout -p R/setup.R`, or by editing, and confirm the tests are green
again.

- [ ] **Step 7: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R
git commit -m "setup: offer to adopt the RStudio project folder as the study"
```

---

### Task 4: Documentation, news and the gates

**Files:**
- Modify: `R/setup.R` (the roxygen block above `setup <- function`)
- Modify: `man/setup.Rd` (regenerated, never hand-edited)
- Modify: `README.md` ("Set up a study", about lines 40–60)
- Modify: `vignettes/study-environment.qmd` ("Common problems" table, about line
  149)
- Create: `news/feat-setup-adopt-project.md`

- [ ] **Step 1: Roxygen for `setup()`**

Insert this paragraph after the first paragraph of the roxygen block (the one
ending "restarts into the project."):

```r
#' The usual start is a legacy study opened as its own RStudio project
#' (File > New Project > Existing Directory): run
#' `setup(study, study_tracker_id)` in that project's console. With no
#' `_study.yml` there, `setup()` asks whether to adopt the project folder
#' (the default answer is No), and adopting cleans up template copies unless
#' `cleanup = FALSE` is passed. It refuses a project opened at one of a
#' study's folders, such as `30_analyses`, or at a package. A
#' non-interactive session never adopts unasked: it stops and prints the
#' `setup(root = ..., adopt = TRUE)` call to run. The step-by-step flow,
#' with where to type each command, is in `vignette("start-here")`.
#'
```

Confirm the article name before committing:
`grep -n "start-here" _pkgdown.yml vignettes/start-here.qmd`.

Replace the paragraph beginning "`setup()` replaces packages in the study's
library" with:

```r
#' Once the study's renv is active in a session, `setup()` replaces packages
#' that session has loaded, so rerun it from a session started outside the
#' project, passing `root`. From inside an active project it stops before
#' installing anything, and names the command to run.
```

Replace `@param root` with:

```r
#' @param root The study root, where `setup()` writes. By default the study
#'   enclosing the working directory; with none, the RStudio project folder
#'   the session is in, once its adoption is confirmed. Outside both,
#'   `setup()` stops and asks for it, so a new study always names its
#'   directory.
```

Then run: `Rscript -e 'devtools::document()'`
Expected: `man/setup.Rd` is updated, and `NAMESPACE` is unchanged (nothing new
is exported).

- [ ] **Step 2: README**

Replace the code block and the first sentence of the paragraph under
"### Set up a study" so it reads:

````markdown
Open the study's folder as an RStudio project (File > New Project > Existing
Directory), then in that project's console:

```r
install.packages("pak")
pak::pak("ehrlinger/hvtiR")
hvtiR::setup(
  study = "EDIT: the Study Tracker title",
  study_tracker_id = 0L,  # EDIT: the Study Tracker ID
  identity_source = "manual"  # you typed the identity; the default records it as verified
)
```

With no `_study.yml` there, `setup()` asks whether to adopt the folder; the
default answer is No. Run this once per study, before anything else. Once the
study's renv is active, rerun it from an R session started outside the
project, passing `root =`: from inside it stops before installing anything and
names the command to run, because it replaces packages that session has loaded.
````

Leave the rest of that paragraph unchanged, from "It also stops the study
using renv's per-user cache" on.

- [ ] **Step 3: The study-environment troubleshooting row**

Replace the row

```
| `setup()` stops before installing and prints a command | You ran it inside the project. Close the project, then run a command with the same arguments from outside it |
```

with

```
| `setup()` stops before installing and prints a command | You ran it inside a project whose renv is active. Close the project, then run the printed command from outside it |
| `setup()` says no study encloses the folder | Open the study's folder itself as the RStudio project, not one of its subfolders, and run `setup()` there; or pass `root` |
```

- [ ] **Step 4: News fragment**

Create `news/feat-setup-adopt-project.md`:

```markdown
* `setup()` run inside a legacy study's own RStudio project, with no
  `_study.yml` above it, now offers to adopt the project folder (the default
  answer is No) instead of stopping. It refuses a project opened at a study
  folder such as `30_analyses`, or at a package, and a non-interactive
  session stops and prints the `setup(root = ..., adopt = TRUE)` call. This
  is now the usual way to start a study.
```

- [ ] **Step 5: Run the gates**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'lintr::lint_package()'
Rscript -e 'devtools::check()'
```

Expected: tests pass with `FAIL 0`; read the `SKIP` count and explain any skip
the change added. Lint is clean. Check is 0 errors, 0 warnings, 0 notes. If
lint flags the `nolint` placement in `guard_session()`, move the comment to
sit directly above the line lint names.

- [ ] **Step 6: Commit**

```bash
git add R/setup.R man/setup.Rd README.md vignettes/study-environment.qmd \
  news/feat-setup-adopt-project.md
git commit -m "setup: document adopting a study from its own project"
```

---

### Task 5: Review and open the PR

- [ ] **Step 1:** Run the local `/code-review` on the branch. Copilot review
  credits may be exhausted, so measure them: see hvtiR `AGENTS.md`.
- [ ] **Step 2:** Push and open the PR against `main`, and say in the body that
  `/code-review` stood in for the bot if it did. Link the spec and the
  quick-start hand-off to PR #174.
- [ ] **Step 3:** Leave the version bump and the merge to John.
- [ ] **Step 4:** When the PR merges, message the session that owns hvtiR #174,
  `local_031bf01b-9438-4f9d-abc1-aa84abb37b55` ("Biostats Teams training"),
  with the PR number. It is holding its "Set up the study" rewrite of
  `vignettes/start-here.qmd` until then, and will check its text against the
  merged code.
