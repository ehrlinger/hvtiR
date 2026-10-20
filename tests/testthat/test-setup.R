test_that("a study declares hvtiR, every member and the extras", {
  pkgs <- declared_packages()
  expect_identical(pkgs[1L], "hvtiR")
  expect_true(all(members()$package %in% pkgs))
  expect_true("arrow" %in% pkgs)
})

test_that("install_specs maps members to GitHub and leaves others alone", {
  specs <- install_specs(c("hvtiR", "hvtiRutilities", "arrow"))
  expect_identical(specs, c(SELF_REPO, "ehrlinger/hvtiRutilities", "arrow"))
})

local_setup <- function(run_status = 0L,
                        gone = data.frame(
                          package = character(), missing = character()
                        ),
                        locked_r = NA_character_, env = parent.frame()) {
  log <- new.env()
  log$steps <- character(0)
  step <- function(x) log$steps <- c(log$steps, x)
  fns <- list(
    study_root = function(...) stop("no study"),
    study_setup = function(...) {
      log$setup_args <- list(...)
      step("study_setup")
      structure(list(), class = "x")
    },
    study_declare = function(packages, root) {
      log$declared <- packages
      step("declare")
    }
  )
  # nolint next: object_usage_linter.
  local_mocked_bindings(
    utilities_fn = function(name) fns[[name]],
    run_in_study = function(expr, root) {
      log$expr <- expr
      step("run")
      list(status = run_status, output = "installing\nHVTIR_LIB=/tmp/lib\n")
    },
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
  expect_identical(
    log$steps, c("prefs", "study_setup", "declare", "run", "open")
  )
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

test_that("the install restores, adds what is missing, snapshots", {
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
