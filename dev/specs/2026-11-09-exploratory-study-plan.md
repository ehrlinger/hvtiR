# Exploratory Studies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an analyst set up an exploration off a registered study without
a Study Tracker ID of its own. The exploration is identified by `derived_from`
and a `provisional_id`. It checkpoints locally, and `study_promote()`
registers it later.

**Architecture:** Most of the change is in hvtiRutilities. One helper,
`.study_identity_state()`, classifies a `_study.yml` as `registered`,
`provisional`, `promoted` or `legacy`. `study_config()`, `study_setup()`,
`.cp_study()` and `study_status()` all branch on it. In hvtiR, `setup()` gains
`derived_from` and forwards it through the `...` it already passes to
`study_setup()`. qhsprograms follows in its own plan (Part C).

**Tech Stack:** R (>= 4.4.0), testthat 3e with `local_mocked_bindings()`,
`yaml`, `uuid` (already in hvtiRutilities `Imports`), roxygen2.

Spec: [`2026-11-09-exploratory-study-design.md`](2026-11-09-exploratory-study-design.md).

## Global Constraints

- Release order: hvtiRutilities merges and is versioned **first**. hvtiR's
  `UTILITIES_FLOOR` moves to that version in hvtiR's own PR, never before the
  version is on hvtiRutilities `main`.
- Versions are straight three digits, and only the patch digit moves. A PR does
  **not** touch `Version:` or `NEWS.md`. It adds `news/<branch>.md`, with `/`
  in the branch name replaced by `-`.
- Every existing positional call keeps working: `setup("t", 7L, root = r)` and
  `study_setup(root, "t", 42L)`. New arguments go **last** in the formals.
- hvtiRutilities roxygen uses **Rd markup** (`\code{}`). hvtiR roxygen uses
  **markdown**.
- hvtiR runs lintr's defaults, so lines are at most 80 characters.
  hvtiRutilities has its own `.lintr`.
- hvtiR installation behaviour is tested only through the mocked seam. Never run
  `hvtiR::install()` or a live `setup()`.
- Definition of done in each repo:
  - `devtools::test()` passes.
  - `devtools::check()` is 0 errors, 0 warnings, 0 notes.
  - The output of `devtools::document()` is committed.
- `provisional_id` format: `x<parent>-<first 8 chars of workspace_id>`. It is
  written once and never recomputed.
- The outbox hold reason for a provisional study is the exact string
  `"provisional"`.

## File map

| Repo | File | Responsibility |
|---|---|---|
| hvtiRutilities | `R/study_identity_state.R` (create) | `.study_identity_state()`, `.study_provisional_id()`, `.study_check_id()` |
| hvtiRutilities | `R/study_config.R` (modify `.study_validate_identity`) | reject a mix of exploration and registration fields |
| hvtiRutilities | `R/study_setup.R` (modify) | `derived_from`; write the provisional block |
| hvtiRutilities | `R/checkpoint_study.R`, `R/checkpoint_deliver.R`, `R/study_checkpoint.R`, `R/study_close.R` (modify) | a provisional study checkpoints locally |
| hvtiRutilities | `R/study_status.R` (modify) | EXPLORATORY row, setup advice |
| hvtiRutilities | `R/study_promote.R` (create) | `study_promote()` |
| hvtiR | `R/setup.R` (modify) | `derived_from`, validation, quoting |
| hvtiR | `vignettes/start-here.qmd` (modify) | the exploration section |

---

## Part A: hvtiRutilities

Work in a worktree on branch `feat/exploratory-study`, cut from `origin/main`:

```bash
cd ~/Documents/GitHub/hvtiRutilities && git fetch origin && git worktree add ../hvtiRutilities-explore -b feat/exploratory-study origin/main
```

### Task A1: Identity state and its validation

**Files:**
- Create: `R/study_identity_state.R`
- Modify: `R/study_config.R` (`.study_validate_identity`, near line 114)
- Test: `tests/testthat/test-study_identity_state.R` (create)

**Interfaces:**
- Produces:
  - `.study_identity_state(raw)`: takes the list read from `_study.yml` and
    returns `"registered"`, `"provisional"`, `"promoted"` or `"legacy"`, or
    `NA_character_` for an invalid mix.
  - `.study_provisional_id(parent, workspace_id)`: takes an integer and a UUID
    string and returns a string such as `"x1234-3f9a2c1b"`.
  - `.study_check_id(x, name, caller)`: returns an integer, or stops with
    `"<caller>(): <name> must be one positive integer"`.

- [ ] **Step 1: Write the failing tests**

```r
# tests/testthat/test-study_identity_state.R
test_that("identity state classifies the four valid shapes", {
  expect_identical(.study_identity_state(list(study_tracker_id = 7L)),
                   "registered")
  expect_identical(.study_identity_state(
    list(derived_from = 7L, provisional_id = "x7-3f9a2c1b")), "provisional")
  expect_identical(.study_identity_state(
    list(derived_from = 7L, study_tracker_id = 9L)), "promoted")
  expect_identical(.study_identity_state(list(study = "S")), "legacy")
})

test_that("identity state is NA for a mix of the two shapes", {
  na <- NA_character_
  expect_identical(.study_identity_state(list(provisional_id = "x7-a")), na)
  expect_identical(.study_identity_state(list(derived_from = 7L)), na)
  expect_identical(.study_identity_state(list(
    derived_from = 7L, provisional_id = "x7-a", study_tracker_id = 9L)), na)
  expect_identical(.study_identity_state(
    list(derived_from = "seven", provisional_id = "x7-a")), na)
  expect_identical(.study_identity_state(
    list(derived_from = 7L, provisional_id = 5L)), na)
})

test_that("a provisional id is x, the parent and 8 workspace characters", {
  expect_identical(
    .study_provisional_id(1234L, "3f9a2c1b-7d4e-4a10-9b2f-0c8e5d6a7b31"),
    "x1234-3f9a2c1b"
  )
})

test_that(".study_check_id accepts one positive integer only", {
  expect_identical(.study_check_id(42L, "derived_from", "f"), 42L)
  expect_identical(.study_check_id(42, "derived_from", "f"), 42L)
  for (bad in list(0L, -1L, 4.2, "42", c(1L, 2L), NA_integer_)) {
    expect_error(.study_check_id(bad, "derived_from", "f"),
                 "f\\(\\): derived_from must be one positive integer")
  }
})

test_that("study_config refuses a mixed identity and names the fields", {
  root <- withr::local_tempdir()
  yaml::write_yaml(list(study = "S", derived_from = 7L,
                        provisional_id = "x7-3f9a2c1b", study_tracker_id = 9L),
                   file.path(root, "_study.yml"))
  expect_error(study_config(root, require_data = FALSE),
               "study_tracker_id, derived_from, provisional_id")
})

test_that("study_config accepts provisional, promoted and legacy files", {
  for (cfg in list(
    list(study = "S", derived_from = 7L, provisional_id = "x7-3f9a2c1b"),
    list(study = "S", derived_from = 7L, study_tracker_id = 9L),
    list(study = "S")
  )) {
    root <- withr::local_tempdir()
    yaml::write_yaml(cfg, file.path(root, "_study.yml"))
    expect_no_error(study_config(root, require_data = FALSE))
  }
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "study_identity_state")'`
Expected: FAIL with `could not find function ".study_identity_state"`.

- [ ] **Step 3: Implement**

```r
# R/study_identity_state.R
# The four shapes a _study.yml identity can take (spec 2026-11-09). An
# exploration of a registered study has derived_from (the parent's Study
# Tracker ID) and provisional_id but no study_tracker_id until
# study_promote() writes one; a promoted one keeps derived_from as lineage.
# A file with none of the three keys is legacy and keeps today's handling.
.study_identity_state <- function(raw) {
  has <- function(k) !is.null(raw[[k]])
  if (!has("derived_from") && !has("provisional_id")) {
    return(if (has("study_tracker_id")) "registered" else "legacy")
  }
  if (!has("derived_from") || !.study_whole_id(raw$derived_from)) {
    return(NA_character_)
  }
  if (has("provisional_id") && !has("study_tracker_id")) {
    id <- raw$provisional_id
    ok <- is.character(id) && length(id) == 1L && !is.na(id) && nzchar(id)
    return(if (ok) "provisional" else NA_character_)
  }
  if (!has("provisional_id") && has("study_tracker_id")) return("promoted")
  NA_character_
}

# Written once by study_setup(); never recomputed from workspace_id later.
.study_provisional_id <- function(parent, workspace_id) {
  paste0("x", parent, "-", substr(workspace_id, 1L, 8L))
}

# One positive whole number, as an integer. .study_whole_id() is checked
# before coercion, which would truncate 4.2 to 4.
.study_check_id <- function(x, name, caller) {
  if (!.study_whole_id(x)) {
    stop(caller, "(): ", name, " must be one positive integer", call. = FALSE)
  }
  as.integer(x)
}
```

In `R/study_config.R`, at the end of `.study_validate_identity()` and just
before `invisible(raw)`, add:

```r
  if (is.na(.study_identity_state(raw))) {
    keys <- intersect(c("study_tracker_id", "derived_from", "provisional_id"),
                      names(raw))
    stop("study_config(): ", found, " has ", paste(keys, collapse = ", "),
         ", which is neither an exploration (derived_from and ",
         "provisional_id) nor a promoted study (derived_from and ",
         "study_tracker_id)", call. = FALSE)
  }
```

- [ ] **Step 4: Run the new tests and the existing config tests to confirm they pass**

Run: `Rscript -e 'devtools::test(filter = "study_identity_state|study_config")'`
Expected: all PASS. The existing tests in `test-study_config.R` are unchanged.

- [ ] **Step 5: Commit**

```bash
git add R/study_identity_state.R R/study_config.R tests/testthat/test-study_identity_state.R
git commit -m "feat: classify _study.yml identity as registered, provisional, promoted or legacy"
```

### Task A2: `study_setup(derived_from = )`

**Files:**
- Modify: `R/study_setup.R`. The changes are to:
  - the signature (line 552)
  - the ID check (lines 574-579)
  - the `identity_exists` branch (lines 617-635)
  - the `identity` list (lines 696-709)
  - the roxygen `@param` block
- Test: `tests/testthat/test-study_setup.R` (append)

**Interfaces:**
- Consumes: `.study_check_id()`, `.study_identity_state()` and
  `.study_provisional_id()` from A1.
- Produces:
  `study_setup(root, study, study_tracker_id = NULL, ..., r_upgrade = FALSE, derived_from = NULL)`.
  A provisional study's `_study.yml` holds `derived_from` (integer),
  `provisional_id` and `workspace_id` (UUID), and has no `study_tracker_id` key.

- [ ] **Step 1: Write the failing tests**

```r
test_that("study_setup(derived_from) writes a provisional identity", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, study = "Lactate exploration", derived_from = 1234L,
              renv = FALSE)
  raw <- yaml::read_yaml(file.path(root, "_study.yml"))
  expect_false("study_tracker_id" %in% names(raw))
  expect_identical(raw$derived_from, 1234L)
  expect_match(raw$workspace_id, "^[0-9a-f]{8}-")
  expect_identical(raw$provisional_id,
                   paste0("x1234-", substr(raw$workspace_id, 1, 8)))
  expect_identical(.study_identity_state(raw), "provisional")
  expect_true(dir.exists(file.path(root, "30_analyses")))
})

test_that("study_setup needs exactly one of the two IDs", {
  root <- file.path(withr::local_tempdir(), "s")
  msg <- "exactly one of study_tracker_id .* or derived_from"
  expect_error(study_setup(root, "S", renv = FALSE), msg)
  expect_error(study_setup(root, "S", 7L, derived_from = 8L, renv = FALSE),
               msg)
  expect_error(study_setup(root, "S", derived_from = 0L, renv = FALSE),
               "derived_from must be one positive integer")
})

test_that("a rerun keeps the provisional id", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  first <- yaml::read_yaml(file.path(root, "_study.yml"))$provisional_id
  study_setup(root, "S", derived_from = 12L, adopt = TRUE, cleanup = FALSE,
              renv = FALSE)
  expect_identical(
    yaml::read_yaml(file.path(root, "_study.yml"))$provisional_id, first
  )
})

test_that("a Tracker ID on a provisional study points to study_promote", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  expect_error(
    study_setup(root, "S", 99L, adopt = TRUE, cleanup = FALSE, renv = FALSE),
    "study_promote\\(99L\\)"
  )
})

test_that("derived_from on a registered study, or another parent, stops", {
  root <- file.path(withr::local_tempdir(), "s")
  study_setup(root, "S", 7L, renv = FALSE)
  expect_error(study_setup(root, "S", derived_from = 7L, adopt = TRUE,
                           cleanup = FALSE, renv = FALSE),
               "not an exploration of ST 7")
  root2 <- file.path(withr::local_tempdir(), "x")
  study_setup(root2, "S", derived_from = 12L, renv = FALSE)
  expect_error(study_setup(root2, "S", derived_from = 13L, adopt = TRUE,
                           cleanup = FALSE, renv = FALSE),
               "not an exploration of ST 13")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "^study_setup$")'`
Expected: the new tests FAIL with `unused argument (derived_from = 1234)`.

- [ ] **Step 3: Implement**

Signature: give `study_tracker_id` a `NULL` default and append `derived_from`.

```r
study_setup <- function(root = NULL, study, study_tracker_id = NULL,
                        umbrella = NULL, owner = NULL,
                        irb_number = NULL, cvir_no = NULL,
                        study_creation_date = NULL, adopt = FALSE,
                        identity_source = c("tracker", "manual"),
                        cleanup = adopt, renv = TRUE,
                        template_dir = "/programs/development/template",
                        r_upgrade = FALSE, derived_from = NULL) {
```

Replace the `tracker <- …` block at lines 574-579 with:

```r
  if (is.null(study_tracker_id) == is.null(derived_from)) {
    stop("study_setup(): give exactly one of study_tracker_id (a registered ",
         "study) or derived_from (an exploration of one)", call. = FALSE)
  }
  tracker <- if (!is.null(study_tracker_id)) {
    .study_check_id(study_tracker_id, "study_tracker_id", "study_setup")
  }
  parent <- if (!is.null(derived_from)) {
    .study_check_id(derived_from, "derived_from", "study_setup")
  }
```

⚠️ `.study_check_id(42.0)` accepts a whole double. The old check accepted only
values whose `as.character()` round-trips. Both still reject `"42"` and `42.5`,
so the existing tests for `study_tracker_id must be one positive integer` should
still pass. Step 4 runs them to confirm.

Replace the `if (identity_exists) { … }` block at lines 617-635 with:

```r
  if (identity_exists) {
    existing <- .read_study_yml(yml, "study_setup")
    state <- .study_identity_state(existing)
    if (!is.null(parent)) {
      if (!identical(state, "provisional") ||
            !identical(as.integer(existing$derived_from), parent)) {
        stop("study_setup(): ", yml, " is not an exploration of ST ", parent,
             call. = FALSE)
      }
    } else if (identical(state, "provisional")) {
      stop("study_setup(): ", yml, " is an exploration of ST ",
           existing$derived_from, " with no Study Tracker ID of its own; ",
           "register it with study_promote(", tracker, "L)", call. = FALSE)
    } else {
      existing_tracker <- suppressWarnings(
        as.integer(existing$study_tracker_id)
      )
      if (length(existing_tracker) != 1L || is.na(existing_tracker)) {
        stop("study_setup(): existing _study.yml has no Study Tracker ID",
             call. = FALSE)
      }
      if (!identical(existing_tracker, tracker)) {
        stop("study_setup(): _study.yml already exists for Study Tracker ID ",
             existing_tracker, call. = FALSE)
      }
    }
    if (!adopt && !(.study_interactive() && isTRUE(.study_ask_adopt(root)))) {
      stop("study_setup(): ", root, " is already set up as a study; use adopt = TRUE ",
           "to fill in what it is missing", call. = FALSE)
    }
    adopt <- TRUE
  }
```

After the `identity <- list(…)` assignment, add the block below. A provisional
identity has no `study_tracker_id` key at all, rather than a `~` value.

```r
  if (!is.null(parent)) {
    workspace <- uuid::UUIDgenerate()
    identity <- append(
      identity[names(identity) != "study_tracker_id"],
      list(derived_from = parent,
           provisional_id = .study_provisional_id(parent, workspace),
           workspace_id = workspace),
      after = 1L
    )
  }
```

Roxygen: change `@param study_tracker_id` to "The Study Tracker ID, an
integer. Give this or \code{derived_from}, not both." Then add:

```r
#' @param derived_from For an exploration of a registered study that has no
#'   Study Tracker record of its own: the parent's Study Tracker ID. The study
#'   gets a \code{provisional_id} and checkpoints locally until
#'   \code{\link{study_promote}} gives it its own ID.
```

- [ ] **Step 4: Run all the setup tests**

Run: `Rscript -e 'devtools::test(filter = "study_setup|study-setup")'`
Expected: all PASS, old and new.

- [ ] **Step 5: Commit**

```bash
git add R/study_setup.R tests/testthat/test-study_setup.R
git commit -m "feat: study_setup(derived_from =) sets up a provisional exploration"
```

### Task A3: Provisional checkpoints stay local

**Files:**
- Modify: `R/checkpoint_study.R` (`.cp_study`, lines 37-56)
- Modify: `R/checkpoint_deliver.R` (`.cp_deliver`: the `reason <-` chain and
  the message branch, near lines 266-295)
- Modify: `R/study_checkpoint.R` (line 285, and `study_checkpoint_push` at
  line 417)
- Modify: `R/study_close.R` (lines 275 and 323)
- Test: `tests/testthat/test-checkpoint_study.R`,
  `tests/testthat/test-study_checkpoint.R` (append)

**Interfaces:**
- Consumes: `.study_identity_state()`.
- Produces:
  - `.cp_study()` returns two new elements, `provisional` (logical) and
    `provisional_id` (string or `NULL`). `st_id` is `NULL` when the study is
    provisional.
  - Log entries carry `st_id = .cp_or(study$st_id, study$provisional_id)`.
    The only consumer of `st_id` is the commit-message header at
    `R/study_checkpoint.R:9`, so a string is safe.
  - The outbox reason for held entries is `"provisional"`.

- [ ] **Step 1: Write the failing tests**

Append to `test-checkpoint_study.R`:

```r
test_that("a provisional study reads with no st_id", {
  root <- withr::local_tempdir()
  yaml::write_yaml(list(study = "S", derived_from = 12L,
                        provisional_id = "x12-3f9a2c1b",
                        workspace_id = "3f9a2c1b-0000"),
                   file.path(root, "_study.yml"))
  s <- .cp_study(root, "f")
  expect_null(s$st_id)
  expect_true(s$provisional)
  expect_identical(s$provisional_id, "x12-3f9a2c1b")
  expect_identical(s$workspace_id, "3f9a2c1b-0000")
})

test_that("a registered study is not provisional", {
  root <- withr::local_tempdir()
  yaml::write_yaml(list(study = "S", study_tracker_id = 5L),
                   file.path(root, "_study.yml"))
  expect_false(.cp_study(root, "f")$provisional)
})
```

Append to `test-study_checkpoint.R`. Before writing it, open the first test in
that file and copy exactly how it builds a checkpointable study, including the
`.checkpoint/` setup and a manual-trigger kind. The body below assumes the
fixtures `skip_if_no_git()`, `local_git_env()` and `set_study_keys()` from
`helper-checkpoint.R`. Replace `KIND` with the manual-trigger kind that first
test uses. Do not invent a kind; `.cp_kinds()` rejects unknown ones.

```r
test_that("a provisional study checkpoints locally and holds the push", {
  skip_if_no_git()
  local_git_env()
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  set_study_keys(root, checkpoint = list(remote = "https://example.org/x.git"))
  res <- study_checkpoint(KIND, root = root)
  expect_identical(res$delivery$git, "pending")
  expect_identical(res$delivery$reason, "provisional")
  log <- yaml::read_yaml(file.path(root, ".checkpoint", "log.yml"))
  expect_match(log[[length(log)]]$st_id, "^x12-")
  expect_error(study_checkpoint_push(root), "study_promote")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "checkpoint_study|study_checkpoint")'`
Expected: FAIL. `.cp_study` stops with "no valid st_id or study_tracker_id".

- [ ] **Step 3: Implement**

In `.cp_study()`, replace the `st <- …` line and the `if (…) stop(…)` lines
with:

```r
  provisional <- identical(.study_identity_state(raw), "provisional")
  st <- NULL
  if (!provisional) {
    st <- suppressWarnings(as.integer(.cp_or(raw$st_id, raw$study_tracker_id)))
    if (length(st) != 1L || is.na(st) || st < 1L) {
      stop(caller, "(): _study.yml has no valid st_id or study_tracker_id",
           call. = FALSE)
    }
  }
```

Add these two elements to the returned `list(…)`:

```r
    provisional = provisional,
    provisional_id = raw$provisional_id,
```

In `.cp_deliver()`, make the provisional reason the first branch:

```r
  reason <- if (isTRUE(study$provisional)) {
    "provisional"
  } else if (!study$verified) {
    "identity unverified"
  } else if (is.null(study$remote)) {
```

In the message branch below it, add a sibling ahead of the
`identity unverified` branch:

```r
  if (identical(reason, "provisional")) {
    message(length(pending), " checkpoint(s) saved locally and not pushed: ",
            "this exploration has no Study Tracker ID yet. Run ",
            "study_promote(<id>) once it is registered.")
  } else if (identical(reason, "identity unverified")) {
```

In `study_checkpoint()` at line 285, and in `study_close.R` at lines 275 and
323, change `st_id = study$st_id` to:

```r
st_id = .cp_or(study$st_id, study$provisional_id),
```

In `study_checkpoint_push()`, after `study <- .cp_study(...)`, add:

```r
  if (isTRUE(study$provisional)) {
    stop("study_checkpoint_push(): this exploration (", study$provisional_id,
         ") has no Study Tracker ID; register it with study_promote() first",
         call. = FALSE)
  }
```

Add this sentence to the roxygen `@description` of both `study_checkpoint` and
`study_checkpoint_push`: "An exploration set up with \code{derived_from} is
committed and tagged locally and pushed only after
\code{\link{study_promote}}."

- [ ] **Step 4: Run all the checkpoint and close tests**

Run: `Rscript -e 'devtools::test(filter = "checkpoint|study_close")'`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add R/checkpoint_study.R R/checkpoint_deliver.R R/study_checkpoint.R R/study_close.R tests/testthat/test-checkpoint_study.R tests/testthat/test-study_checkpoint.R
git commit -m "feat: an exploration checkpoints locally until it is promoted"
```

### Task A4: `study_status()` reports an exploration

**Files:**
- Modify: `R/study_status.R` (the `row_yml` assignment near line 409, and the
  `renv.lock` MISSING branch near lines 425-447)
- Test: `tests/testthat/test-study_status.R` (append)

**Interfaces:**
- Consumes: `.study_identity_state()`.
- Produces: for a provisional study, the `_study.yml` row's status is
  `EXPLORATORY`. The setup advice quotes `derived_from = <n>L`.

- [ ] **Step 1: Write the failing test**

Read the first test in `test-study_status.R` and use the same row-access idiom
(its column names). The version below assumes the columns are `item`, `status`
and `detail`.

```r
test_that("study_status reports an exploration and its setup command", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  st <- study_status(root)
  yml <- st[st$item == "_study.yml", ]
  expect_identical(yml$status, "EXPLORATORY")
  expect_match(yml$detail, "derived from ST 12, provisional ID x12-")
  lock <- st[st$item == "renv.lock", ]
  expect_match(lock$detail, "derived_from = 12L", fixed = TRUE)
  expect_no_match(lock$detail, "Add the line study_tracker_id")
})
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `Rscript -e 'devtools::test(filter = "study_status")'`
Expected: FAIL, because the status is `OK` rather than `EXPLORATORY`.

- [ ] **Step 3: Implement**

Put a provisional branch first in the `row_yml <- if (…)` chain:

```r
      row_yml <- if (identical(.study_identity_state(cfg), "provisional")) {
        .status_row("_study.yml", "EXPLORATORY",
                    paste0("study: ", cfg$study, "; derived from ST ",
                           cfg$derived_from, ", provisional ID ",
                           cfg$provisional_id, "; register it with ",
                           "study_promote(<id>)"))
      } else if (isFALSE(cfg$identity_verified)) {
```

In the `renv.lock` MISSING branch, change the opening lines to:

```r
    id <- cfg$study_tracker_id
    provisional <- !is.null(cfg) &&
      identical(.study_identity_state(cfg), "provisional")
    if (!is.null(cfg) && !provisional && !(length(id) == 1L && !is.na(id))) {
```

and in its `else` branch:

```r
      setup_call <- if (is.null(cfg)) {
        "hvtiR::setup()"
      } else {
        sprintf("hvtiR::setup(study = %s, %s = %dL, root = %s, adopt = TRUE)",
                encodeString(cfg$study, quote = "\""),
                if (provisional) "derived_from" else "study_tracker_id",
                as.integer(if (provisional) cfg$derived_from else id),
                encodeString(root, quote = "\""))
      }
```

⚠️ Before committing, grep `R/study_status.R` and `print.study_status` for the
status vocabulary (for example `"UNVERIFIED"`). If a whitelist or a severity
map exists, add `EXPLORATORY` to it with the same severity as `OK`. An unknown
status must not count as a failure.

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `Rscript -e 'devtools::test(filter = "study_status")'`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add R/study_status.R tests/testthat/test-study_status.R
git commit -m "feat: study_status reports an exploration and its setup command"
```

### Task A5: `study_promote()`

**Files:**
- Create: `R/study_promote.R`
- Modify: `_pkgdown.yml` (add `study_promote` after `study_update_identity`,
  near line 139)
- Test: `tests/testthat/test-study_promote.R` (create)

**Interfaces:**
- Consumes: `.study_identity_state()`, `.study_check_id()`,
  `.read_study_yml()`, `.study_write_atomic()`, `study_config()` and
  `.cp_log_read()`.
- Produces: an exported `study_promote(study_tracker_id, start = ".")`. It
  returns, invisibly, the count (an integer) of outbox entries held as
  `"provisional"`, which `study_checkpoint_push()` will now send.

- [ ] **Step 1: Write the failing tests**

```r
# tests/testthat/test-study_promote.R
test_that("study_promote makes a provisional study promoted", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  ws <- yaml::read_yaml(file.path(root, "_study.yml"))$workspace_id
  expect_identical(study_promote(345L, start = root), 0L)
  raw <- yaml::read_yaml(file.path(root, "_study.yml"))
  expect_identical(raw$study_tracker_id, 345L)
  expect_identical(raw$derived_from, 12L)
  expect_identical(raw$workspace_id, ws)
  expect_null(raw$provisional_id)
  expect_identical(.study_identity_state(raw), "promoted")
})

test_that("study_promote refuses a study that is not provisional", {
  root <- file.path(withr::local_tempdir(), "s")
  study_setup(root, "S", 7L, renv = FALSE)
  expect_error(study_promote(9L, start = root),
               "already has Study Tracker ID 7")
})

test_that("study_promote refuses a bad ID", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  expect_error(study_promote("345", start = root),
               "study_tracker_id must be one positive integer")
})

test_that("promoting to the parent's own ID warns", {
  root <- file.path(withr::local_tempdir(), "explore")
  study_setup(root, "S", derived_from = 12L, renv = FALSE)
  expect_warning(study_promote(12L, start = root), "the parent's own ID")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "study_promote")'`
Expected: FAIL with `could not find function "study_promote"`.

- [ ] **Step 3: Implement**

⚠️ First confirm that `study_config()` returns a `file` element.
`study_update_identity()` uses `cfg$file`, so it should. Also confirm that
`.cp_log_read(root)` returns `list()` when `.checkpoint/log.yml` is absent. If
it errors instead, wrap the `held` computation in
`if (file.exists(file.path(root, ".checkpoint", "log.yml")))`, and use `0L`
otherwise.

```r
# R/study_promote.R
#' Give an exploration its own Study Tracker ID
#'
#' @description
#' An exploration set up with \code{study_setup(derived_from = )} has a
#' \code{provisional_id} and no Study Tracker ID of its own. Once the Tracker
#' has registered it, \code{study_promote()} writes that ID into
#' \code{_study.yml} and removes \code{provisional_id}. \code{derived_from}
#' and \code{workspace_id} stay, so the lineage to the parent study is kept.
#' Checkpoints held locally while the study was provisional are pushed by the
#' next \code{\link{study_checkpoint_push}}; their tags are unchanged.
#'
#' @param study_tracker_id The study's new Study Tracker ID, one positive
#'   integer.
#' @param start A directory in the study. The study is found as by
#'   \code{\link{study_config}}.
#' @return The number of checkpoints held for promotion, invisibly.
#' @seealso \code{\link{study_setup}}, \code{\link{study_update_identity}}
#' @examples
#' root <- file.path(tempdir(), "promote-example")
#' invisible(study_setup(root, study = "Example exploration",
#'                       derived_from = 1L, renv = FALSE))
#' study_promote(2L, start = root)
#' unlink(root, recursive = TRUE)
#' @export
study_promote <- function(study_tracker_id, start = ".") {
  id <- .study_check_id(study_tracker_id, "study_tracker_id", "study_promote")
  cfg <- study_config(start, require_data = FALSE)
  raw <- .read_study_yml(cfg$file, "study_promote")
  if (!identical(.study_identity_state(raw), "provisional")) {
    stop("study_promote(): ", cfg$file, " already has Study Tracker ID ",
         raw$study_tracker_id, call. = FALSE)
  }
  if (identical(id, as.integer(raw$derived_from))) {
    warning("study_promote(): ", id, " is the parent's own ID; the ",
            "exploration's checkpoints will be filed under the parent study",
            call. = FALSE)
  }
  raw <- append(raw[names(raw) != "provisional_id"],
                list(study_tracker_id = id), after = 1L)
  .study_write_atomic(raw, cfg$file)
  root <- dirname(cfg$file)
  held <- sum(vapply(.cp_log_read(root), function(e) {
    identical(e$delivery$reason, "provisional")
  }, logical(1)))
  invisible(as.integer(held))
}
```

- [ ] **Step 4: Document, then run the tests and examples**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "study_promote")'`
Expected:
- `NAMESPACE` gains `export(study_promote)`.
- `man/study_promote.Rd` is written.
- The tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/study_promote.R _pkgdown.yml NAMESPACE man/ tests/testthat/test-study_promote.R
git commit -m "feat: study_promote() gives an exploration its Study Tracker ID"
```

### Task A6: News fragment, full gates, PR

- [ ] **Step 1: Write the fragment** `news/feat-exploratory-study.md`. It holds
  bullets only, with no heading.

```markdown
* `study_setup()` gains `derived_from`, for an exploration of a registered study that has no Study Tracker record of its own. It writes `derived_from`, a `provisional_id` and a `workspace_id` to `_study.yml`, and no `study_tracker_id`. `study_tracker_id` now defaults to `NULL`, and exactly one of the two is required.
* New `study_promote()` writes an exploration's Study Tracker ID once the Tracker has registered it, and keeps `derived_from` as lineage.
* An exploration's checkpoints and closures are committed and tagged locally and held in the outbox with reason `provisional`. `study_checkpoint_push()` refuses an exploration until it is promoted. `study_status()` reports it as `EXPLORATORY`.
```

- [ ] **Step 2: Run the full gates**

Run: `Rscript -e 'devtools::document(); devtools::test(); devtools::check(); lintr::lint_package()'`
Expected:
- The tests pass.
- The check is 0 errors, 0 warnings, 0 notes.
- lintr reports no lints.
- `git status` shows no diff in `man/` or `NAMESPACE`.

- [ ] **Step 3: Commit, push, open the PR**

```bash
git add news/feat-exploratory-study.md && git commit -m "news: exploratory studies"
```

```bash
git push -u origin feat/exploratory-study
```

```bash
gh pr create --title "feat: exploratory studies derived from a registered study" --body "Implements Part A of dev/specs/2026-11-09-exploratory-study-plan.md in ehrlinger/hvtiR."
```

After the merge, John versions hvtiRutilities to the next patch (expected
`1.5.22`) with `news.py collect`, then tags it. Part B waits until that version
is on `main`.

---

## Part B: hvtiR

Start only after Part A's version is on hvtiRutilities `main`. Branch
`feat/setup-derived-from` from `origin/main`.

### Task B1: `setup(derived_from = )`

**Files:**
- Modify: `R/setup.R`. The changes are to:
  - `UTILITIES_FLOOR` (line 59)
  - the question text in `adopt_project()` (lines 1274-1313)
  - `setup_command()` (lines 1350-1364), so it drops a `NULL` ID
  - `setup()`: the signature (line 1538), the validation, threading `dots`,
    and the `study_setup` call (near line 1645)
  - the roxygen `@param` entries
- Test: `tests/testthat/test-setup.R` (append)

**Interfaces:**
- Consumes: `hvtiRutilities::study_setup(..., derived_from = )` from Part A.
- Produces:
  `setup(study, study_tracker_id = NULL, root = NULL, adopt = FALSE, upgrade = TRUE, workspace_prefs = TRUE, derived_from = NULL, ...)`.

- [ ] **Step 1: Write the failing tests** with the existing `local_setup()`
  harness. `setup()` makes two `pak_lib` calls: the family first, then the
  extras (see the test near line 213).

```r
test_that("setup passes derived_from to study_setup and no tracker ID", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("An exploration", root = root, derived_from = 12L)
  expect_identical(log$setup_args$derived_from, 12L)
  expect_null(log$setup_args$study_tracker_id)
})

test_that("setup needs exactly one ID, before anything runs", {
  root <- withr::local_tempdir()
  log <- local_setup()
  msg <- "exactly one of"
  expect_error(setup("S", root = root), msg)
  expect_error(setup("S", 7L, root = root, derived_from = 12L), msg)
  expect_identical(log$steps, character(0))
})

test_that("an exploration installs the whole family in one pak call", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("S", root = root, derived_from = 12L)
  expect_length(log$pak_lib, 2L)
  family <- install_specs(c("hvtiR", members()$package))
  expect_true(all(family %in% log$pak_lib[[1L]]$specs))
})

test_that("the quoted command names derived_from and drops the NULL ID", {
  cmd <- setup_command("/s", "A", NULL, dots = list(derived_from = 12L))
  expect_match(cmd, "derived_from = 12L", fixed = TRUE)
  expect_no_match(cmd, "study_tracker_id")
  expect_identical(
    setup_command("/s", "A", 7L),
    'hvtiR::setup(root = "/s", study = "A", study_tracker_id = 7L)'
  )
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "^setup$")'`
Expected: FAIL. `setup("An exploration", root = …)` errors because
`study_tracker_id` is missing.

- [ ] **Step 3: Implement**

Signature: `derived_from` goes last, before `...`.

```r
setup <- function(study, study_tracker_id = NULL, root = NULL, adopt = FALSE,
                  upgrade = TRUE, workspace_prefs = TRUE,
                  derived_from = NULL, ...) {
```

At the top of the body, after the R-version check, validate the two IDs and
fold `derived_from` into `dots`, so that every existing path that takes
`list(...)` carries it:

```r
  if (is.null(study_tracker_id) == is.null(derived_from)) {
    cli::cli_abort(paste(
      "Give exactly one of {.arg study_tracker_id} (a registered study)",
      "or {.arg derived_from} (an exploration of one)."
    ))
  }
  dots <- list(...)
  if (!is.null(derived_from)) dots$derived_from <- derived_from
```

Then replace each `list(...)` in `setup()`'s body with `dots`: the
`"renv" %in% names(…)` check, `adopt_project(…)` and `guard_session(…)`.
Replace the `study_setup` call with:

```r
  status <- do.call(utilities_fn("study_setup"), c(
    list(root = root, study = study, study_tracker_id = study_tracker_id,
         adopt = adopt, renv = TRUE),
    dots
  ))
```

In `setup_command()`, replace the
`list(root = root, study = study, study_tracker_id = study_tracker_id)` line
with:

```r
    Filter(Negate(is.null),
           list(root = root, study = study,
                study_tracker_id = study_tracker_id)),
```

In `adopt_project()`, build the identity clause of the question from `dots`:

```r
  ident <- if (is.null(study_tracker_id)) {
    paste0("exploration of ST ", dots[["derived_from"]])
  } else {
    paste0("Study Tracker ", study_tracker_id)
  }
  question <- paste0(
    candidate, " has no _study.yml. Adopt it as study \"", study,
    "\" (", ident, ")?",
```

Move `UTILITIES_FLOOR` to Part A's released version (expected `"1.5.22"`).
Update its comment to name the release that carries `derived_from`.

Roxygen: change `@param study_tracker_id` to "The Study Tracker ID, an
integer. Give this or `derived_from`, not both." Then add:

```r
#' @param derived_from For an exploration of a registered study with no
#'   Study Tracker record of its own, the parent's Study Tracker ID. The study
#'   gets a provisional ID and checkpoints locally until
#'   `hvtiRutilities::study_promote()` gives it its own.
```

- [ ] **Step 4: Run the setup and install tests**

Run: `Rscript -e 'devtools::test(filter = "setup|install")'`
Expected: all PASS, including the existing one-call `pak` test and every
existing `setup_command` expectation.

- [ ] **Step 5: Commit**

```bash
git add R/setup.R tests/testthat/test-setup.R
git commit -m "feat: setup(derived_from =) for an exploration of a registered study"
```

### Task B2: Vignette, news, gates, PR

- [ ] **Step 1:** In `vignettes/start-here.qmd`, after the section on a new
  study, add `## An exploration of a registered study`. Write one short
  paragraph in the house voice (`ehrlinger-writing`), followed by:

```r
hvtiR::setup(
  study = "Lactate trajectories (exploration)",
  derived_from = 1234L,
  root = "/studies/<area>/lactate-explore"
)
# once the Tracker registers it:
hvtiRutilities::study_promote(5678L)
```

- [ ] **Step 2:** Fragment `news/feat-setup-derived-from.md`:

```markdown
* `setup()` gains `derived_from`, to set up an exploration of a registered study that has no Study Tracker record of its own. `study_tracker_id` now defaults to `NULL`, and exactly one of the two is required. Needs hvtiRutilities 1.5.22.
```

- [ ] **Step 3:** Run the gates.

Run: `Rscript -e 'devtools::document(); devtools::test(); devtools::check(); lintr::lint_package()'`
Expected: 0/0/0, no lints, and no diff from `document()`.

- [ ] **Step 4:** Before the PR merges, run each dependent's tests against this
  branch, as `AGENTS.md` requires under release ordering. Then commit, push and
  open the PR.

---

## Part C: qhsprograms (its own plan, after A and B)

This part is not broken into steps here. The Python layer assumes an integer ID
in more places than the spec's table lists:

- the `StudyRecord` dataclass
- the title prompt in `identity.py`
- the `ST{id:04d}` Tracker link in `readme.py`
- `_candidate()` in `recovery.py`, which rejects a `_study.yml` with no
  `study_tracker_id`
- the `st-{id}-` prefix in `ado.py`
- the allow-list and `as.integer()` in `bridge.R`

Write `qhsprograms/docs/specs/<date>-study-setup-derived-from-plan.md`
covering:

1. `cli.py`: `--derived-from N`, mutually exclusive with the positional ID.
2. `StudyRecord`: an optional `derived_from`. `study_tracker_id` becomes
   optional when it is set.
3. `bridge.R`: allow `derived_from` and forward it.
4. `ado.py`: create no repository for a provisional study.
5. `readme.py`: link the parent's Tracker page as "derived from ST…".
6. `recovery.py`: accept a provisional `_study.yml`.

These go in one ADO PR.

## Self-review notes

Each requirement in the spec is covered by a task:

| Spec requirement | Task |
|---|---|
| The three states and the legacy rule | A1 |
| `study_setup()`, and its behaviour on rerun | A2 |
| Local-only checkpoints, and the push refusal | A3 |
| `study_status()` | A4 |
| `study_promote()`, including the warning for the parent's own ID | A5 |
| hvtiR `setup()`, the quoted command, the adopt prompt, the floor | B1 |
| The vignette | B2 |
| qhsprograms | C, deferred to its own plan |

The spec was corrected in step with this plan in two places:

- The new arguments go last in the formals, so positional calls keep their
  meaning.
- The checkpoint hold uses the existing `delivery$reason`, `"provisional"`,
  rather than a new `pushed:` field.
