# A position finder that fails when the anchor is absent: a comparison of two
# regexpr() results passes when both are -1.
anchor_at <- function(x) {
  function(s) {
    pos <- regexpr(s, x, fixed = TRUE)[[1L]]
    testthat::expect_gt(pos, 0L)
    pos
  }
}

test_that("a study declares hvtiR, every member and the extras", {
  pkgs <- declared_packages()
  expect_identical(pkgs[1L], "hvtiR")
  expect_true(all(members()$package %in% pkgs))
  expect_true("arrow" %in% pkgs)
})

test_that("a study declares the team's standard analysis packages", {
  standard <- c(
    "tidyverse", "haven", "gtsummary", "flextable", "survival", "survminer",
    "randomForestSRC", "varPro", "pacman"
  )
  expect_true(all(standard %in% environment_extras()))
  expect_true(all(standard %in% declared_packages()))
  expect_false(anyDuplicated(declared_packages()) > 0L)
  expect_false(any(environment_extras() %in% members()$package))
})

test_that("install_specs passes the standard set through by name", {
  extras <- environment_extras()
  expect_identical(install_specs(extras), extras)
})

test_that("install_specs maps members to GitHub and leaves others alone", {
  specs <- install_specs(c("hvtiR", "hvtiRutilities", "arrow"))
  expect_identical(specs, c(SELF_REPO, "ehrlinger/hvtiRutilities", "arrow"))
})

local_setup <- function(run_status = 0L,
                        run_output = "installing\nHVTIR_LIB=@LIB@\n",
                        restore_status = 0L, restore_output = NULL,
                        pak_error = NULL,
                        renv_present = TRUE,
                        session_lib = "/nonexistent/session/lib",
                        gone = data.frame(
                          package = character(), missing = character()
                        ),
                        locked_r = NA_character_, locked = NULL,
                        credentials = TRUE, lock_repos = NULL,
                        root_error = "study_config(): no _study.yml found.",
                        env = parent.frame()) {
  log <- new.env()
  lib <- withr::local_tempdir(.local_envir = env)
  log$pak <- list()
  log$pak_lib <- list()
  log$steps <- character(0)
  step <- function(x) log$steps <- c(log$steps, x)
  fns <- list(
    study_root = function(...) stop(root_error),
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
  # testthat helper, not attached when lintr runs.
  # nolint next: object_usage_linter.
  local_mocked_bindings(
    utilities_fn = function(name) fns[[name]],
    run_in_study = function(expr, root) {
      if (grepl("HVTIR_LOCKED", expr, fixed = TRUE)) {
        step("read_lock")
        return(list(
          status = 0L,
          output = paste0(
            "HVTIR_LOCKED=", paste(locked, collapse = ","), "\n",
            if (!is.null(lock_repos)) {
              paste0("HVTIR_REPOS=", lock_repos, "\n")
            }
          )
        ))
      }
      if (grepl("HVTIR_LOCKVER", expr, fixed = TRUE)) {
        log$expr1 <- expr
        step("child1")
        out <- restore_output
        if (is.null(out)) {
          out <- paste0(
            "HVTIR_LIB=@LIB@\nHVTIR_LOCKVER=",
            paste(sprintf("%s:1.0:", locked), collapse = ","), "\n"
          )
        }
        out <- gsub("@LIB@", lib, out, fixed = TRUE)
        return(list(status = restore_status, output = out))
      }
      log$expr <- expr
      step("run")
      out <- gsub("@LIB@", lib, run_output, fixed = TRUE)
      list(status = run_status, output = out)
    },
    pak_install_lib = function(specs, lib, repos = NULL) {
      log$pak_lib <- c(
        log$pak_lib, list(list(specs = specs, lib = lib, repos = repos))
      )
      step("pak_lib")
      if (!is.null(pak_error)) stop(pak_error)
      invisible(NULL)
    },
    renv_available = function() renv_present,
    pak_install = function(specs) {
      log$pak <- c(log$pak, list(specs))
      step("pak")
      renv_present <<- TRUE
    },
    session_library = function() session_lib,
    renv_state = function(...) "installed",
    cheap_study_root = function() getwd(),
    github_credentials_available = function() credentials,
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
    log$steps,
    c("prefs", "study_setup", "declare", "child1", "pak_lib", "run", "open")
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

test_that("child 1 restores, child 2 fills LinkingTo gaps then snapshots", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  at1 <- anchor_at(log$expr1)
  expect_true(at1("snapshot.type('explicit'") < at1("renv::restore("))
  expect_true(at1("renv::restore(") < at1("HVTIR_LOCKVER="))
  expect_no_match(log$expr1, "renv::install(", fixed = TRUE)
  expect_no_match(log$expr1, "renv::snapshot(", fixed = TRUE)
  at <- anchor_at(log$expr)
  expect_true(at("LinkingTo") < at("quit(status = 3L"))
  expect_true(at("quit(status = 3L") < at("renv::snapshot("))
  expect_no_match(log$expr, "renv::restore(prompt", fixed = TRUE)
})

test_that("order is child 1, then pak into the project library, then child 2", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  expect_identical(
    log$steps[log$steps %in% c("child1", "pak_lib", "run")],
    c("child1", "pak_lib", "run")
  )
  expect_length(log$pak_lib, 1L)
  expect_true(dir.exists(log$pak_lib[[1L]]$lib))
  expect_true("ehrlinger/hvtiRutilities" %in% log$pak_lib[[1L]]$specs)
  expect_true("arrow" %in% log$pak_lib[[1L]]$specs)
})

test_that("pak gets only the declared packages the lockfile lacks", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  log <- local_setup(locked = c("arrow", "hvtiRutilities", "survival"))
  setup("A study", 7L, root = root)
  specs <- log$pak_lib[[1L]]$specs
  expect_false("arrow" %in% specs)
  expect_false("ehrlinger/hvtiRutilities" %in% specs)
  expect_false("survival" %in% specs)
  expect_true(SELF_REPO %in% specs)
})

test_that("with everything locked pak is not called", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  log <- local_setup(locked = c(declared_packages(), "survival"))
  setup("A study", 7L, root = root)
  expect_length(log$pak_lib, 0L)
  expect_true("run" %in% log$steps)
})

test_that("child 2 receives the locked versions child 1 reported", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  log <- local_setup(locked = "survival")
  setup("A study", 7L, root = root)
  expect_match(log$expr, "survival", fixed = TRUE)
  expect_match(log$expr, '"1.0"', fixed = TRUE)
})

test_that("a pak failure stops with its message, before child 2", {
  root <- withr::local_tempdir()
  log <- local_setup(pak_error = "could not solve")
  expect_error(setup("A study", 7L, root = root), "could not solve")
  expect_false("run" %in% log$steps)
})

test_that("a failed restore stops before pak", {
  root <- withr::local_tempdir()
  log <- local_setup(restore_status = 1L, restore_output = "restore boom\n")
  expect_error(setup("A study", 7L, root = root), "restore boom")
  expect_length(log$pak_lib, 0L)
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

test_that("a child that exits 0 without a library path still stops", {
  root <- withr::local_tempdir()
  local_setup(run_output = "installing, all fine\n")
  expect_error(setup("A study", 7L, root = root), "library")
})

test_that("a library path that does not exist stops", {
  root <- withr::local_tempdir()
  local_setup(run_output = "HVTIR_LIB=/no/such/dir\n")
  expect_error(setup("A study", 7L, root = root), "library")
})

test_that("two library paths stop", {
  root <- withr::local_tempdir()
  local_setup(run_output = "HVTIR_LIB=@LIB@\nHVTIR_LIB=@LIB@\n")
  expect_error(setup("A study", 7L, root = root))
})

test_that("a failed install shows only the last 40 lines", {
  root <- withr::local_tempdir()
  local_setup(
    run_status = 1L,
    run_output = paste(
      c(sprintf("noise%02d", 1:60), "the end"), collapse = "\n"
    )
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = function(e) e)
  expect_match(conditionMessage(err), "the end", fixed = TRUE)
  expect_match(conditionMessage(err), "noise60", fixed = TRUE)
  expect_no_match(conditionMessage(err), "noise01", fixed = TRUE)
})

test_that("a missing renv is installed through pak before study_setup", {
  root <- withr::local_tempdir()
  log <- local_setup(renv_present = FALSE)
  setup("A study", 7L, root = root)
  expect_identical(log$pak, list("renv"))
  expect_identical(
    log$steps,
    c("pak", "prefs", "study_setup", "declare", "child1", "pak_lib", "run",
      "open")
  )
})

test_that("a renv that is still missing after the install aborts", {
  root <- withr::local_tempdir()
  log <- local_setup(renv_present = FALSE)
  local_mocked_bindings(
    pak_install = function(specs) invisible(NULL),
    renv_available = function() FALSE
  )
  expect_error(setup("A study", 7L, root = root), "renv")
  expect_false("study_setup" %in% log$steps)
})

test_that("an existing lockfile's packages are declared with the family", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  log <- local_setup(locked = c("renv", "survival", "arrow"))
  setup("A study", 7L, root = root)
  expect_true(all(c("survival", "arrow", "hvtiR") %in% log$declared))
  expect_false("renv" %in% log$declared)
  expect_identical(anyDuplicated(log$declared), 0L)
  expect_true(match("read_lock", log$steps) < match("study_setup", log$steps))
})

test_that("setup declares quarto and ggiraph, which job rendering uses", {
  # No member imports quarto, so only the declaration puts it in an
  # explicit-mode lockfile; render_job() and submit_job() stop without it.
  # ggiraph is optional in dc-eda, so nothing else pulls it in either.
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  expect_true(all(c("quarto", "ggiraph") %in% log$declared))
})

test_that("with no lockfile no extra child run happens", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  expect_false("read_lock" %in% log$steps)
})

test_that("a failed lockfile read stops", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  local_setup(locked = "x")
  local_mocked_bindings(
    run_in_study = function(expr, root) list(status = 1L, output = "boom")
  )
  expect_error(setup("A study", 7L, root = root), "boom")
})

test_that("a failed install reports the real error and keeps the log", {
  root <- withr::local_tempdir()
  local_setup()
  messy <- paste0(
    "Downloading 10%\rDownloading 90%\r\n",
    "\033[32mOK\033[39m installed {curly} braces\n",
    "bad byte ", rawToChar(as.raw(c(0x66, 0xff))), "\n",
    "Error: boom\n"
  )
  local_mocked_bindings(
    run_in_study = function(expr, root) list(status = 1L, output = messy)
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = identity)
  msg <- conditionMessage(err)
  expect_match(msg, "boom", fixed = TRUE)
  expect_match(msg, "curly", fixed = TRUE)
  expect_match(msg, "hvtiR-setup-", fixed = TRUE)
  expect_false(grepl("ansi_strwrap", msg, fixed = TRUE))
  pat <- "[^ '\n]*hvtiR-setup-[^ '\n]*\\.log"
  log_file <- regmatches(msg, regexpr(pat, msg))
  expect_true(file.exists(log_file))
  saved <- rawToChar(readBin(log_file, "raw", file.size(log_file)))
  expect_true(grepl("Downloading 10%", saved, fixed = TRUE, useBytes = TRUE))
})

test_that("both children turn renv's pak back end off in code, not env", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
  expect_match(log$expr1, "^options\\(renv.config.pak.enabled = FALSE\\); ")
  expect_match(log$expr, "^options\\(renv.config.pak.enabled = FALSE\\); ")
})

test_that("setup refuses to run from inside the study's own library", {
  root <- withr::local_tempdir()
  lib <- file.path(root, "renv", "library")
  dir.create(lib, recursive = TRUE)
  log <- local_setup(session_lib = lib)
  expect_error(setup("A study", 7L, root = root), "root =")
  expect_identical(log$steps, character(0))
})

test_that("renv passed through ... is rejected", {
  root <- withr::local_tempdir()
  log <- local_setup()
  expect_error(setup("A study", 7L, root = root, renv = FALSE), "study_setup")
  expect_identical(log$steps, character(0))
})

test_that("a failure installing hvtiRutilities propagates", {
  local_setup()
  local_mocked_bindings(
    utilities_fn = function(name) stop("install blew up")
  )
  expect_error(setup("A study", 7L), "install blew up")
})

test_that("a lockfile made under another R says the snapshot records this R", {
  root <- withr::local_tempdir()
  local_setup(locked_r = "4.4.1")
  expect_message(setup("A study", 7L, root = root), "snapshot will record")
})

test_that("missing GitHub credentials warn and the install goes ahead", {
  root <- withr::local_tempdir()
  log <- local_setup(credentials = FALSE)
  expect_warning(setup("A study", 7L, root = root), "pak")
  expect_warning(setup("A study", 7L, root = root), "GITHUB_PAT")
  expect_warning(setup("A study", 7L, root = root), "create_github_token")
  suppressWarnings(setup("A study", 7L, root = root))
  expect_true(all(c("child1", "pak_lib", "run") %in% log$steps))
})

test_that("with credentials there is no credentials warning", {
  root <- withr::local_tempdir()
  local_setup(credentials = TRUE)
  expect_no_warning(setup("A study", 7L, root = root))
})

test_that("a gitcreds token reaches the child as GITHUB_PAT, then goes", {
  root <- withr::local_tempdir()
  withr::local_envvar(GITHUB_PAT = NA)
  local_setup(credentials = TRUE)
  seen <- NULL
  seen_pak <- NULL
  local_mocked_bindings(
    gitcreds_token = function() "tok",
    pak_install_lib = function(specs, lib, repos = NULL) {
      seen_pak <<- Sys.getenv("GITHUB_PAT", NA)
    },
    run_in_study = function(expr, root) {
      seen <<- Sys.getenv("GITHUB_PAT", NA)
      list(status = 0L, output = paste0(
        "HVTIR_LIB=", tempdir(), "\nHVTIR_LOCKVER=\n"
      ))
    }
  )
  try(suppressMessages(setup("A study", 7L, root = root)), silent = TRUE)
  expect_identical(seen, "tok")
  expect_identical(seen_pak, "tok")
  expect_identical(Sys.getenv("GITHUB_PAT", NA), NA_character_)
})

test_that("a GITHUB_PAT counts as credentials", {
  withr::local_envvar(GITHUB_PAT = "x")
  expect_true(github_credentials_available())
})

test_that("with no PAT and no gitcreds there are no credentials", {
  withr::local_envvar(GITHUB_PAT = "")
  local_mocked_bindings(gitcreds_token = function() NULL)
  expect_false(github_credentials_available())
})

test_that("a failed install with an authentication error adds the hint", {
  root <- withr::local_tempdir()
  local_setup(
    restore_status = 1L,
    restore_output = "GitHub authentication credentials are not available\n"
  )
  expect_error(setup("A study", 7L, root = root), "create_github_token")
})

test_that("a pak failure with an authentication error adds the hint", {
  root <- withr::local_tempdir()
  local_setup(pak_error = "GitHub authentication credentials are not available")
  expect_error(setup("A study", 7L, root = root), "create_github_token")
})

test_that("a failed install without that error carries no hint", {
  root <- withr::local_tempdir()
  local_setup(run_status = 1L, run_output = "boom\n")
  expect_error(
    setup("A study", 7L, root = root), "boom"
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_no_match(err, "create_github_token")
})

test_that("child 2 fills LinkingTo gaps, guards the lock, then snapshots", {
  expr <- finish_expr("/tmp", c(pkgA = "1.0"))
  at <- anchor_at(expr)
  expect_true(at("before <- ") < at("LinkingTo"))
  # The fill installs through renv, which can move a locked package, so the
  # guard follows it.
  expect_true(at("LinkingTo") < at("changed <- "))
  expect_true(at("changed <- ") < at("packages = changed"))
  expect_true(at("packages = changed") < at("HVTIR_CHANGED="))
  expect_true(at("HVTIR_CHANGED=") < at("quit(status = 3L"))
  expect_true(at("quit(status = 3L") < at("renv::snapshot("))
  expect_true(at("renv::snapshot(") < at("HVTIR_LIB="))
  expect_match(expr, "pkgA", fixed = TRUE)
})

# The LinkingTo fill, run against a temporary library.

run_fill <- function(lib) {
  env <- new.env()
  env$lib <- lib
  env$installed <- NULL
  env$fake_install <- function(x, ...) assign("installed", x, envir = env)
  # Defined in setup.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  eval(parse(text = linking_expr("lib", "/tmp", "fake_install")), env)
  env$installed
}

fake_pkg <- function(lib, name, ...) {
  dir.create(file.path(lib, name))
  writeLines(
    c(paste("Package:", name), "Version: 1.0", "Title: x", ...),
    file.path(lib, name, "DESCRIPTION")
  )
}

test_that("the LinkingTo fill selects the missing build-time package", {
  lib <- withr::local_tempdir()
  fake_pkg(lib, "fakeUser", "LinkingTo: fakeLinkDep (>= 0.2.0), fakeHere")
  fake_pkg(lib, "fakeHere")
  expect_identical(run_fill(lib), "fakeLinkDep")
})

test_that("the LinkingTo fill installs nothing when all are present", {
  lib <- withr::local_tempdir()
  fake_pkg(lib, "fakeUser", "LinkingTo: fakeLinkDep")
  fake_pkg(lib, "fakeLinkDep")
  expect_null(run_fill(lib))
  empty <- withr::local_tempdir()
  expect_null(run_fill(empty))
})

test_that("a locked package moved by the install stops, lockfile unchanged", {
  root <- withr::local_tempdir()
  local_setup(
    run_status = 3L,
    run_output = "HVTIR_CHANGED=pkgA:1.0->2.0,pkgC:0.1->0.2\n"
  )
  expect_error(setup("A study", 7L, root = root), "pkgA")
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_match(err, "1.0", fixed = TRUE)
  expect_match(err, "2.0", fixed = TRUE)
  expect_match(err, "pkgC", fixed = TRUE)
  expect_match(err, "unchanged", fixed = TRUE)
  expect_match(err, "upgrade = TRUE", fixed = TRUE)
  expect_match(err, "the default", fixed = TRUE)
  expect_match(err, "upgrade = FALSE", fixed = TRUE)
  expect_no_match(err, "update", fixed = TRUE)
})

test_that("the LinkingTo fill defaults to renv::install, with no test hook", {
  code <- linking_expr("lib", "/tmp")
  expect_match(code, "renv::install(need", fixed = TRUE)
  expect_no_match(code, "link_install", fixed = TRUE)
})

# The guard and its cleanup, run against a temporary library.

run_guard <- function(lib, before, sha, libpkgs, restore_error = NULL,
                      upgrade = FALSE) {
  env <- new.env()
  env$upgrade <- upgrade
  env$lib <- lib
  env$before <- before
  env$sha <- sha
  env$libpkgs <- libpkgs
  env$restored <- NULL
  env$fake_restore <- function(project, packages, prompt) {
    if (!is.null(restore_error)) stop(restore_error)
    assign("restored", packages, envir = env)
  }
  # Defined in setup.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  code <- guard_expr(deparse1("/tmp"))
  code <- sub("renv::restore(", "fake_restore(", code, fixed = TRUE)
  code <- sub("quit(status = 3L, save = 'no')", "cat('QUIT\\n')", code,
              fixed = TRUE)
  out <- paste(capture.output(eval(parse(text = code), env)), collapse = "\n")
  list(out = out, restored = env$restored)
}

sha_pkg <- function(lib, name, sha) {
  fake_pkg(lib, name, paste("RemoteSha:", sha))
}

test_that("the guard trips when RemoteSha moved and Version did not", {
  lib <- withr::local_tempdir()
  sha_pkg(lib, "pkgA", "bbb")
  res <- run_guard(lib, c(pkgA = "1.0"), c(pkgA = "aaa"), "pkgA")
  expect_match(res$out, "QUIT", fixed = TRUE)
  expect_match(res$out, "HVTIR_CHANGED=pkgA", fixed = TRUE)
  expect_identical(res$restored, "pkgA")
})

test_that("the guard passes when Version and RemoteSha both match", {
  lib <- withr::local_tempdir()
  sha_pkg(lib, "pkgA", "aaa")
  fake_pkg(lib, "pkgB")
  res <- run_guard(
    lib, c(pkgA = "1.0", pkgB = "1.0"), c(pkgA = "aaa", pkgB = ""),
    c("pkgA", "pkgB")
  )
  expect_identical(res$out, "")
  expect_null(res$restored)
})

test_that("a guard trip removes what this run added and keeps the rest", {
  lib <- withr::local_tempdir()
  sha_pkg(lib, "pkgA", "bbb")
  fake_pkg(lib, "kept")
  fake_pkg(lib, "pakAdded")
  res <- run_guard(lib, c(pkgA = "1.0"), c(pkgA = "aaa"), c("pkgA", "kept"))
  expect_false(dir.exists(file.path(lib, "pakAdded")))
  expect_true(dir.exists(file.path(lib, "kept")))
  expect_true(dir.exists(file.path(lib, "pkgA")))
  expect_identical(res$restored, "pkgA")
  expect_no_match(res$out, "RESTOREFAIL", fixed = TRUE)
})

test_that("a failed rollback restore is named and the guard still exits 3", {
  lib <- withr::local_tempdir()
  sha_pkg(lib, "pkgA", "bbb")
  res <- run_guard(
    lib, c(pkgA = "1.0"), c(pkgA = "aaa"), "pkgA", restore_error = "no token"
  )
  expect_match(res$out, "HVTIR_RESTOREFAIL=pkgA", fixed = TRUE)
  expect_match(res$out, "no token", fixed = TRUE)
  expect_match(res$out, "HVTIR_CHANGED=pkgA", fixed = TRUE)
  expect_match(res$out, "QUIT", fixed = TRUE)
})

test_that("the guard compares versions as versions, not strings", {
  lib <- withr::local_tempdir()
  fake_pkg(lib, "pkgA")
  writeLines(c("Package: pkgA", "Version: 1.2-5", "Title: x"),
             file.path(lib, "pkgA", "DESCRIPTION"))
  res <- run_guard(lib, c(pkgA = "1.2-5"), c(pkgA = ""), "pkgA")
  expect_identical(res$out, "")
  expect_null(res$restored)
  res <- run_guard(lib, c(pkgA = "1.2-6"), c(pkgA = ""), "pkgA")
  expect_match(res$out, "HVTIR_CHANGED=pkgA", fixed = TRUE)
})

test_that("the guard finds a recommended package in the system library", {
  lib <- withr::local_tempdir()
  sys <- withr::local_tempdir()
  fake_pkg(sys, "mgcv")
  withr::local_libpaths(sys, action = "prefix")
  res <- run_guard(lib, c(mgcv = "1.0"), c(mgcv = ""), character(0))
  expect_identical(res$out, "")
  expect_null(res$restored)
  res <- run_guard(lib, c(nowhere = "1.0"), c(nowhere = ""), character(0))
  expect_match(res$out, "HVTIR_CHANGED=nowhere:1.0->NA", fixed = TRUE)
})

test_that("with upgrade the guard reports the moves and does not roll back", {
  lib <- withr::local_tempdir()
  sha_pkg(lib, "pkgA", "bbb")
  fake_pkg(lib, "pakAdded")
  res <- run_guard(
    lib, c(pkgA = "0.9"), c(pkgA = "aaa"), "pkgA", upgrade = TRUE
  )
  expect_match(res$out, "HVTIR_MOVED=pkgA:0.9->1.0", fixed = TRUE)
  expect_match(res$out, "RemoteSha aaa->bbb", fixed = TRUE)
  expect_no_match(res$out, "QUIT", fixed = TRUE)
  expect_no_match(res$out, "HVTIR_CHANGED", fixed = TRUE)
  expect_null(res$restored)
  expect_true(dir.exists(file.path(lib, "pakAdded")))
})

test_that("child 2 carries the upgrade flag", {
  expect_match(finish_expr("/tmp", c(pkgA = "1.0")),
               "upgrade <- TRUE", fixed = TRUE)
  expect_match(finish_expr("/tmp", c(pkgA = "1.0"), upgrade = FALSE),
               "upgrade <- FALSE", fixed = TRUE)
})

test_that("setup() by default reports the moves and carries on", {
  root <- withr::local_tempdir()
  log <- local_setup(
    run_output = paste0(
      "HVTIR_MOVED=pkgA:0.9->1.0,pkgB:1.0->2.0 (RemoteSha aaa->bbb)\n",
      "HVTIR_LIB=@LIB@\n"
    )
  )
  expect_message(
    setup("A study", 7L, root = root), "pkgB"
  )
  expect_match(log$expr, "upgrade <- TRUE", fixed = TRUE)
  expect_identical(utils::tail(log$steps, 1L), "open")
  expect_false("upgrade" %in% names(log$setup_args))
  log <- local_setup()
  setup("A study", 7L, root = root, upgrade = FALSE)
  expect_match(log$expr, "upgrade <- FALSE", fixed = TRUE)
})

test_that("moves are grouped: the family, then the dependencies it needs", {
  mixed <- grouped_moves(c(
    "hvtiRutilities:0.3.0->1.5.8 (RemoteSha 5585df8->eedc575)",
    "officer:0.7.4->0.7.7"
  ))
  expect_identical(
    unname(mixed),
    c("Family packages",
      "hvtiRutilities 0.3.0 -> 1.5.8 (RemoteSha 5585df8 -> eedc575)",
      "Dependencies the family needs", "officer 0.7.4 -> 0.7.7")
  )
  fam <- grouped_moves(c("hvtiR:1.0->1.1", "hvtiRutilities:1->2"))
  expect_identical(sum(names(fam) == "i"), 1L)
  expect_identical(unname(fam)[1L], "Family packages")
  deps <- grouped_moves("officer:0.7.4->0.7.7")
  expect_identical(unname(deps)[1L], "Dependencies the family needs")
  expect_length(deps, 2L)
})

test_that("the abort lists a guard trip in the same two groups", {
  root <- withr::local_tempdir()
  local_setup(
    run_status = 3L,
    run_output = paste0(
      "HVTIR_CHANGED=hvtiRutilities:0.3.0->1.5.8,officer:0.7.4->0.7.7\n"
    )
  )
  err <- tryCatch(
    setup("A study", 7L, root = root, upgrade = FALSE),
    error = conditionMessage
  )
  expect_match(err, "Family packages", fixed = TRUE)
  expect_match(err, "Dependencies the family needs", fixed = TRUE)
  expect_match(err, "officer 0.7.4 -> 0.7.7", fixed = TRUE)
})

test_that("child 1 reports RemoteSha and the library's packages", {
  expr <- restore_expr("/tmp")
  at <- anchor_at(expr)
  expect_match(expr, "RemoteSha", fixed = TRUE)
  expect_true(at("renv::restore(") < at("HVTIR_LIBPKGS="))
})

test_that("the lockfile read reports repos, else the session's", {
  expr <- locked_expr("/tmp")
  expect_match(expr, "HVTIR_REPOS=", fixed = TRUE)
  expect_match(expr, "$R$Repositories", fixed = TRUE)
  expect_match(expr, "getOption('repos')", fixed = TRUE)
})

test_that("child 2 is given the library's packages and the locked SHAs", {
  expr <- finish_expr(
    "/tmp", c(pkgA = "1.0"), c(pkgA = "abc"), libpkgs = c("pkgA", "kept")
  )
  expect_match(expr, "abc", fixed = TRUE)
  expect_match(expr, "kept", fixed = TRUE)
})

test_that("setup parses sha, library packages and repos from child 1", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  log <- local_setup(
    locked = c("pkgA", "pkgB"),
    lock_repos = "CRAN=https://cran.example;P=https://p.example",
    restore_output = paste0(
      "HVTIR_LIB=@LIB@\nHVTIR_LOCKVER=pkgA:1.0:abc,pkgB:2.0:\n",
      "HVTIR_LIBPKGS=pkgA,pkgB\n"
    )
  )
  setup("A study", 7L, root = root)
  expect_identical(
    log$pak_lib[[1L]]$repos,
    c(CRAN = "https://cran.example", P = "https://p.example")
  )
  expect_match(log$expr, "pkgA", fixed = TRUE)
  expect_match(log$expr, "abc", fixed = TRUE)
  expect_match(log$expr, "pkgB", fixed = TRUE)
})

test_that("pak_install_lib sets the study's repos around the install", {
  seen <- NULL
  skip_if_not_installed("pak")
  local_mocked_bindings(
    pkg_install = function(...) {
      seen <<- getOption("repos")
      invisible(NULL)
    },
    .package = "pak"
  )
  before <- getOption("repos")
  pak_install_lib("x", "/tmp", repos = c(CRAN = "https://cran.example"))
  expect_identical(seen, c(CRAN = "https://cran.example"))
  expect_identical(getOption("repos"), before)
})

test_that("a guard trip names the outcome: restored, or not restorable", {
  root <- withr::local_tempdir()
  local_setup(
    run_status = 3L,
    run_output = "HVTIR_CHANGED=pkgA:1.0->2.0\n"
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_match(err, "unchanged", fixed = TRUE)
  expect_match(err, "added", fixed = TRUE)
  expect_match(err, "removed", fixed = TRUE)
  expect_match(err, "restored", fixed = TRUE)
  local_setup(
    run_status = 3L,
    run_output = paste0(
      "HVTIR_RESTOREFAIL=pkgA\nHVTIR_RESTOREERR=no token\n",
      "HVTIR_CHANGED=pkgA:1.0->2.0\n"
    )
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_match(err, "could not be restored", fixed = TRUE)
  expect_match(err, "pkgA", fixed = TRUE)
  expect_match(err, "token", fixed = TRUE)
  expect_match(err, "create_github_token", fixed = TRUE)
  expect_match(err, "unchanged", fixed = TRUE)
})

test_that("a malformed _study.yml is not mistaken for no study", {
  local_setup(root_error = "malformed YAML in _study.yml")
  expect_error(setup("A study", 7L), "malformed YAML")
})

test_that("no _study.yml falls back to the working directory", {
  log <- local_setup()
  withr::local_dir(withr::local_tempdir())
  setup("A study", 7L)
  expect_identical(
    normalizePath(log$setup_args$root), normalizePath(getwd())
  )
})
# setup() from inside the study: the guard comes before anything installs.

test_that("setup aborts with renv active, before anything can install", {
  seen <- character(0)
  local_mocked_bindings(
    renv_state = function(...) "active",
    utilities_fn = function(name) {
      seen <<- c(seen, "utilities_fn")
      stop("must not be reached")
    },
    pak_install = function(specs) {
      seen <<- c(seen, "pak_install")
      stop("must not be reached")
    },
    install_members = function(...) {
      seen <<- c(seen, "install_members")
      stop("must not be reached")
    },
    session_library = function() "/nonexistent/session/lib"
  )
  withr::local_envvar(RENV_PROJECT = "/studies/demo")
  err <- tryCatch(setup("A study", 7L), error = conditionMessage)
  expect_match(err, "/studies/demo", fixed = TRUE)
  expect_match(err, "root =", fixed = TRUE)
  expect_match(err, "outside", fixed = TRUE)
  expect_match(err, "A study", fixed = TRUE)
  expect_match(err, "study_tracker_id = 7L", fixed = TRUE)
  expect_match(err, "Close Project", fixed = TRUE)
  expect_identical(seen, character(0))
})

test_that("an explicit root is named in the message when renv is active", {
  local_mocked_bindings(
    renv_state = function(...) "active",
    utilities_fn = function(name) stop("must not be reached")
  )
  withr::local_envvar(RENV_PROJECT = "/studies/demo")
  err <- tryCatch(
    setup("A study", 7L, root = "/studies/other"), error = conditionMessage
  )
  expect_match(err, "/studies/other", fixed = TRUE)
  expect_match(err, "Close Project", fixed = TRUE)
  err <- tryCatch(
    setup("A study", 7L, root = "/studies/other", adopt = TRUE),
    error = conditionMessage
  )
  expect_match(err, "adopt = TRUE", fixed = TRUE)
})

test_that("a session in another project names that project, not loaded ones", {
  local_mocked_bindings(
    renv_state = function(...) "active",
    utilities_fn = function(name) stop("must not be reached")
  )
  withr::local_envvar(RENV_PROJECT = "/studies/demo")
  err <- tryCatch(
    setup("A study", 7L, root = "/studies/other"), error = conditionMessage
  )
  expect_match(err, "another project", fixed = TRUE)
  expect_match(err, "/studies/demo", fixed = TRUE)
  expect_no_match(err, "this session has loaded", fixed = TRUE)
  # The study's own project keeps the original reason.
  err <- tryCatch(
    setup("A study", 7L, root = "/studies/demo"), error = conditionMessage
  )
  expect_match(err, "this session has loaded", fixed = TRUE)
  expect_no_match(err, "another project", fixed = TRUE)
})

test_that("an old hvtiRutilities and root NULL install nothing first", {
  installed <- FALSE
  root <- withr::local_tempdir()
  dir.create(file.path(root, "renv", "library"), recursive = TRUE)
  local_mocked_bindings(
    renv_state = function(...) "installed",
    installed_version = function(pkg) "0.3.0",
    cheap_study_root = function() root,
    install_members = function(...) installed <<- TRUE,
    pak_install = function(...) installed <<- TRUE,
    session_library = function() file.path(root, "renv", "library")
  )
  expect_error(setup("A study", 7L), "outside")
  expect_false(installed)
})

test_that("cheap_study_root prefers RENV_PROJECT and installs nothing", {
  withr::local_envvar(RENV_PROJECT = "/studies/demo")
  expect_identical(cheap_study_root(), "/studies/demo")
})

test_that("cheap_study_root walks up to _study.yml without loading anything", {
  withr::local_envvar(RENV_PROJECT = "")
  top <- normalizePath(withr::local_tempdir(), winslash = "/")
  deep <- file.path(top, "a", "b")
  dir.create(deep, recursive = TRUE)
  writeLines("study: x", file.path(top, "_study.yml"))
  withr::local_dir(deep)
  loaded <- loadedNamespaces()
  local_mocked_bindings(installed_version = function(pkg) "1.5.5")
  expect_identical(cheap_study_root(), top)
  expect_identical(loadedNamespaces(), loaded)
  expect_false(isNamespaceLoaded("hvtiRutilities") &&
                 !"hvtiRutilities" %in% loaded)
})

test_that("cheap_study_root falls back to the working directory", {
  withr::local_envvar(RENV_PROJECT = "")
  wd <- withr::local_tempdir()
  withr::local_dir(wd)
  expect_identical(cheap_study_root(), getwd())
})

# The child's library cleanup.

lib_fixture <- function(env = parent.frame()) {
  # testthat helper, not attached when lintr runs.
  # nolint next: object_usage_linter.
  skip_on_os("windows")
  base <- withr::local_tempdir(.local_envir = env)
  lib <- file.path(base, "lib")
  dir.create(lib)
  targets <- file.path(base, "targets")
  dir.create(targets)
  dir.create(file.path(targets, "good"))
  dir.create(file.path(targets, "locked"))
  writeLines("x", file.path(targets, "locked", "f"))
  dir.create(file.path(lib, "real"))
  file.symlink(file.path(targets, "gone"), file.path(lib, "dangling"))
  file.symlink(file.path(targets, "locked"), file.path(lib, "unreadable"))
  file.symlink(file.path(targets, "good"), file.path(lib, "readable"))
  Sys.chmod(file.path(targets, "locked"), "000")
  withr::defer(Sys.chmod(file.path(targets, "locked"), "755"), envir = env)
  list(lib = lib, targets = targets)
}

run_unlink <- function(lib) {
  env <- new.env()
  env$lib <- lib
  # Defined in setup.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  code <- unlink_expr("lib")
  out <- capture.output(eval(parse(text = code), env))
  paste(out, collapse = "\n")
}

test_that("unlink_expr removes unreadable links and nothing else", {
  skip_if(identical(Sys.info()[["user"]], "root"), "root reads everything")
  fx <- lib_fixture()
  out <- run_unlink(fx$lib)
  expect_false(file.exists(file.path(fx$lib, "dangling")))
  expect_false("unreadable" %in% list.files(fx$lib))
  expect_true(nzchar(Sys.readlink(file.path(fx$lib, "readable"))))
  expect_true(dir.exists(file.path(fx$lib, "real")))
  # targets untouched
  expect_true(dir.exists(file.path(fx$targets, "locked")))
  Sys.chmod(file.path(fx$targets, "locked"), "755")
  expect_true(file.exists(file.path(fx$targets, "locked", "f")))
  expect_match(out, "HVTIR_UNLINKED=", fixed = TRUE)
  expect_match(out, "dangling", fixed = TRUE)
  expect_match(out, "unreadable", fixed = TRUE)
  expect_no_match(out, "readable,|,readable$|=readable")
})

test_that("a link to an unsearchable directory is removed, target kept", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root reads everything")
  fx <- lib_fixture()
  tgt <- file.path(fx$targets, "noexec")
  dir.create(tgt)
  file.symlink(tgt, file.path(fx$lib, "noexec"))
  Sys.chmod(tgt, "444")
  withr::defer(Sys.chmod(tgt, "755"))
  run_unlink(fx$lib)
  expect_false("noexec" %in% list.files(fx$lib))
  expect_true(dir.exists(tgt))
})

test_that("unlink_expr prints nothing when the library is clean", {
  skip_on_os("windows")
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "real"))
  expect_identical(run_unlink(lib), "")
})

test_that("unlink_expr removes pak's staging _cache directory", {
  skip_on_os("windows")
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "_cache", "tmp"), recursive = TRUE)
  writeLines("x", file.path(lib, "_cache", "tmp", "f"))
  out <- run_unlink(lib)
  expect_false(dir.exists(file.path(lib, "_cache")))
  expect_match(out, "HVTIR_UNLINKED=_cache", fixed = TRUE)
})

test_that("unlink_expr takes a library path literally, never as a glob", {
  skip_on_os("windows")
  base <- withr::local_tempdir()
  for (study in c("study[12]", "study1", "study2")) {
    dir.create(file.path(base, study, "lib", "_cache"), recursive = TRUE)
  }
  run_unlink(file.path(base, "study[12]", "lib"))
  expect_false(dir.exists(file.path(base, "study[12]", "lib", "_cache")))
  expect_true(dir.exists(file.path(base, "study1", "lib", "_cache")))
  expect_true(dir.exists(file.path(base, "study2", "lib", "_cache")))
})

test_that("unlink_expr keeps a _cache package and never follows a link", {
  skip_on_os("windows")
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "_cache"))
  writeLines("Package: x", file.path(lib, "_cache", "DESCRIPTION"))
  run_unlink(lib)
  expect_true(dir.exists(file.path(lib, "_cache")))

  lib2 <- withr::local_tempdir()
  target <- withr::local_tempdir()
  writeLines("x", file.path(target, "f"))
  file.symlink(target, file.path(lib2, "_cache"))
  out <- run_unlink(lib2)
  expect_true(file.exists(file.path(target, "f")))
  expect_true(nzchar(Sys.readlink(file.path(lib2, "_cache"))))
  expect_identical(out, "")
})

test_that("a link whose DESCRIPTION is unreadable is removed, target kept", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root reads everything")
  fx <- lib_fixture()
  tgt <- file.path(fx$targets, "nodesc")
  dir.create(tgt)
  writeLines("Package: nodesc", file.path(tgt, "DESCRIPTION"))
  file.symlink(tgt, file.path(fx$lib, "nodesc"))
  Sys.chmod(file.path(tgt, "DESCRIPTION"), "000")
  withr::defer(Sys.chmod(file.path(tgt, "DESCRIPTION"), "644"))
  expect_true("nodesc" %in% library_debris(fx$lib))
  run_unlink(fx$lib)
  expect_false("nodesc" %in% list.files(fx$lib))
  expect_true(file.exists(file.path(tgt, "DESCRIPTION")))
})

run_unreadable <- function(lib) {
  env <- new.env()
  env$lib <- lib
  # Defined in setup.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  code <- unreadable_expr("lib")
  code <- sub("quit(status = 4L, save = 'no')", "cat('QUIT')", code,
              fixed = TRUE)
  paste(capture.output(eval(parse(text = code), env)), collapse = "\n")
}

test_that("a real package with an unreadable DESCRIPTION is kept and named", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root reads everything")
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "theirs"))
  dir.create(file.path(lib, "fine"))
  writeLines("Package: theirs", file.path(lib, "theirs", "DESCRIPTION"))
  writeLines("Package: fine", file.path(lib, "fine", "DESCRIPTION"))
  Sys.chmod(file.path(lib, "theirs", "DESCRIPTION"), "000")
  withr::defer(Sys.chmod(file.path(lib, "theirs", "DESCRIPTION"), "644"))
  expect_identical(library_unreadable(lib), "theirs")
  expect_false("theirs" %in% library_debris(lib))
  out <- run_unreadable(lib)
  expect_match(out, "HVTIR_UNREADABLE=theirs", fixed = TRUE)
  expect_match(out, "QUIT", fixed = TRUE)
  expect_true(dir.exists(file.path(lib, "theirs")))
  expect_identical(run_unreadable(withr::local_tempdir()), "")
})

test_that("child 1 stops on unreadable packages before changing anything", {
  expr <- restore_expr("/tmp")
  at <- anchor_at(expr)
  expect_true(at("HVTIR_UNREADABLE=") < at("HVTIR_UNLINKED="))
  expect_true(at("quit(status = 4L") < at("use.cache(FALSE"))
})

test_that("setup names unreadable packages and says who fixes them", {
  root <- withr::local_tempdir()
  log <- local_setup(
    restore_status = 4L,
    restore_output = "HVTIR_UNREADABLE=theirs,other\n"
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_match(err, "theirs", fixed = TRUE)
  expect_match(err, "other", fixed = TRUE)
  expect_match(err, "chmod -R g+rX", fixed = TRUE)
  expect_match(err, "administrator", fixed = TRUE)
  expect_length(log$pak_lib, 0L)
})

test_that("child 1 cleans, drops the cache, isolates, then restores", {
  expr <- restore_expr("/tmp")
  at <- anchor_at(expr)
  expect_true(at("renv::load(") < at("HVTIR_UNLINKED="))
  # The cleanup comes first: a leftover _cache makes renv's own scan fail.
  expect_true(at("HVTIR_UNLINKED=") < at("use.cache(FALSE"))
  expect_true(at("use.cache(FALSE") < at("renv::isolate("))
  expect_true(at("renv::isolate(") < at("renv::restore("))
  expect_match(expr, "options(renv.config.pak.enabled = FALSE)", fixed = TRUE)
  expect_match(expr, "snapshot.type('explicit'", fixed = TRUE)
})

test_that("setup does not claim a reinstall when the install failed", {
  root <- withr::local_tempdir()
  local_setup(
    restore_output = "HVTIR_UNLINKED=dplyr\nHVTIR_LIB=@LIB@\nHVTIR_LOCKVER=\n",
    run_status = 1L
  )
  msgs <- character(0)
  tryCatch(
    withCallingHandlers(
      setup("A study", 7L, root = root),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) NULL
  )
  expect_false(any(grepl("reinstalled", msgs, fixed = TRUE)))
})

test_that("setup reports the links the child removed", {
  root <- withr::local_tempdir()
  local_setup(restore_output = paste0(
    "HVTIR_UNLINKED=dplyr,_cache\nHVTIR_LIB=@LIB@\nHVTIR_LOCKVER=\n"
  ))
  expect_message(setup("A study", 7L, root = root), "dplyr")
})

# install() and update() warn about a shared library full of dead links.

test_that("library_debris finds unreadable links and a leftover _cache", {
  skip_if(identical(Sys.info()[["user"]], "root"), "root reads everything")
  fx <- lib_fixture()
  dir.create(file.path(fx$lib, "_cache"))
  expect_setequal(
    library_debris(fx$lib), c("_cache", "dangling", "unreadable")
  )
})

# The warning install_members() raises for the given debris, from the study.
debris_warning <- function(debris, lib = "/study/renv/library") {
  testthat::local_mocked_bindings(
    pak_install = function(specs) invisible(specs),
    renv_state = function(...) "active",
    session_library = function() lib,
    library_debris = function(lib) debris,
    .env = parent.frame()
  )
  withr::local_envvar(RENV_PROJECT = "/study")
  msg <- NULL
  withCallingHandlers(
    install_members("hvtiPlotR"),
    warning = function(w) {
      msg <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  msg
}

test_that("install_members warns about debris, repair steps in order", {
  msg <- debris_warning(c("_cache", "dplyr", "ggplot2"))
  expect_match(msg, "dplyr", fixed = TRUE)
  # The commands carry the real paths, so they paste as they are.
  expect_no_match(msg, "<(library|path|link|study)>")
  flat <- gsub("\\s+", " ", msg)
  cache <- "\"/study/renv/library/_cache\""
  expect_match(flat, paste0("Sys.readlink(", cache, ")"), fixed = TRUE)
  expect_match(
    flat, paste0("unlink(", cache, ", recursive = TRUE, expand = FALSE)"),
    fixed = TRUE
  )
  expect_match(
    flat,
    paste0(
      "file.remove(c(\"/study/renv/library/dplyr\", ",
      "\"/study/renv/library/ggplot2\"))"
    ),
    fixed = TRUE
  )
  expect_match(flat, "root = \"/study\"", fixed = TRUE)
  # Only the links are what pak cannot replace.
  expect_no_match(msg, "cannot replace: \"_cache\"", fixed = TRUE)
  # renv's own commands fail on a leftover _cache, so it goes first.
  expect_match(flat, "fail until", fixed = TRUE)
  # A bare restore() undoes what install() and update() just installed, and
  # restore(packages =) still downgrades their installed dependencies, so
  # everything already installed is excluded.
  restore <- paste0(
    "renv::restore(packages = c(\"dplyr\", \"ggplot2\"), exclude = ",
    "setdiff(rownames(installed.packages(\"/study/renv/library\", ",
    "noCache = TRUE)), c(\"dplyr\", \"ggplot2\")))"
  )
  expect_match(flat, restore, fixed = TRUE)
  expect_match(flat, "`renv::restore()` would", fixed = TRUE)
  at <- anchor_at(flat)
  steps <- c("unlink(", "file.remove", "use.cache(FALSE)", "isolate()",
             restore)
  pos <- vapply(steps, at, 1L)
  expect_identical(order(pos), seq_along(steps))
  # Numbered steps are indented bullets, not flush-left text.
  expect_match(msg, "\n +1\\. ")
  expect_match(msg, "\n +5\\. ")
})

test_that("the printed _cache removal deletes only that _cache", {
  # unlink() expands globs by default: "study[12]" would match "study1".
  root <- withr::local_tempdir()
  lib <- file.path(root, "study[12]", "lib")
  sibling <- file.path(root, "study1", "lib", "_cache")
  dir.create(file.path(lib, "_cache"), recursive = TRUE)
  dir.create(sibling, recursive = TRUE)
  for (debris in list("_cache", c("_cache", "dplyr"))) {
    dir.create(file.path(lib, "_cache"), showWarnings = FALSE)
    flat <- gsub("\\s+", " ", debris_warning(debris, lib))
    cmd <- regmatches(flat, regexpr("if \\(!nzchar[^`]*", flat))
    eval(parse(text = cmd))
    expect_false(dir.exists(file.path(lib, "_cache")))
    expect_true(dir.exists(sibling))
  }
})

test_that("a leftover _cache alone needs only its removal", {
  msg <- debris_warning("_cache")
  expect_no_match(msg, "<(library|path|link|study)>")
  expect_no_match(msg, "cannot replace", fixed = TRUE)
  expect_match(msg, "staging", fixed = TRUE)
  expect_match(msg, "renv", fixed = TRUE)
  expect_match(
    gsub("\\s+", " ", msg),
    "unlink(\"/study/renv/library/_cache\", recursive = TRUE, expand = FALSE)",
    fixed = TRUE
  )
  for (step in c("file.remove", "use.cache", "isolate", "restore")) {
    expect_no_match(msg, step, fixed = TRUE)
  }
})

test_that("install_members is quiet about debris without an active project", {
  local_mocked_bindings(
    pak_install = function(specs) invisible(specs),
    renv_state = function(...) "installed",
    library_debris = function(lib) stop("must not be asked")
  )
  expect_no_warning(install_members("hvtiPlotR"))
})

test_that("run_in_study runs code too long for an -e argument", {
  skip_on_cran()
  root <- withr::local_tempdir()
  vec <- paste0("'pkg", seq_len(3000L), "'", collapse = ", ")
  expr <- paste0("x <- c(", vec, "); cat('N=', length(x), '\\n', sep = '')")
  expect_gt(nchar(expr), 20000L)
  res <- run_in_study(expr, root)
  expect_identical(res$status, 0L)
  expect_match(res$output, "N=3000", fixed = TRUE)
})

src <- "https://ppm.example:4242/cran/latest"
bin <- "https://ppm.example:4242/cran/__linux__/centos8/latest"

test_that("binary_repos swaps a source URL for the session's binary form", {
  expect_identical(binary_repos(c(CRAN = src), c(CRAN = bin)), c(CRAN = bin))
  expect_identical(
    binary_repos(c(CRAN = paste0(src, "/")), c(CRAN = bin)), c(CRAN = bin)
  )
})

test_that("binary_repos keeps the study URL when the session's differs", {
  other_host <- sub("ppm.example", "other.example", bin, fixed = TRUE)
  other_port <- sub("4242", "4243", bin, fixed = TRUE)
  other_path <- sub("/cran/", "/bioc/", bin, fixed = TRUE)
  dated <- sub("latest", "2026-10-01", bin, fixed = TRUE)
  for (session in c(other_host, other_port, other_path, dated, src)) {
    expect_identical(binary_repos(c(CRAN = src), c(CRAN = session)),
                     c(CRAN = src))
  }
  expect_identical(
    binary_repos(c(CRAN = sub("latest", "2026-10-01", src)), c(CRAN = bin)),
    c(CRAN = sub("latest", "2026-10-01", src))
  )
})

test_that("binary_repos leaves a binary or non-PPM study URL alone", {
  expect_identical(binary_repos(c(CRAN = bin), c(CRAN = bin)), c(CRAN = bin))
  cran <- "https://cloud.r-project.org"
  expect_identical(binary_repos(c(CRAN = cran), c(CRAN = bin)), c(CRAN = cran))
  expect_identical(
    binary_repos(c(CRAN = "https://cran.r-project.org/"), c(CRAN = bin)),
    c(CRAN = "https://cran.r-project.org/")
  )
  expect_null(binary_repos(NULL, c(CRAN = bin)))
})

test_that("binary_repos handles several named repos independently", {
  p <- "https://ppm.example:4242/bioc/latest"
  got <- binary_repos(
    c(CRAN = src, BIOC = p, X = "https://x.example/r"),
    c(CRAN = bin,
      other = "https://ppm.example:4242/bioc/__linux__/rhel9/latest")
  )
  expect_identical(
    unname(got),
    c(bin, "https://ppm.example:4242/bioc/__linux__/rhel9/latest",
      "https://x.example/r")
  )
  expect_named(got, c("CRAN", "BIOC", "X"))
})

test_that("setup installs, restores and records the binary URL", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  withr::local_options(repos = c(CRAN = bin))
  log <- local_setup(
    locked = "pkgA", lock_repos = paste0("CRAN=", src),
    restore_output = "HVTIR_LIB=@LIB@\nHVTIR_LOCKVER=pkgA:1.0:\n"
  )
  msgs <- testthat::capture_messages(setup("A study", 7L, root = root))
  expect_identical(log$pak_lib[[1L]]$repos, c(CRAN = bin))
  expect_match(log$expr1, bin, fixed = TRUE)
  expect_match(log$expr1, "repos = hvtir_repos", fixed = TRUE)
  expect_match(log$expr, bin, fixed = TRUE)
  expect_match(log$expr, "lockfile_write", fixed = TRUE)
  expect_false(grepl(src, log$expr, fixed = TRUE))
  expect_match(paste(msgs, collapse = ""), "recording it in renv.lock",
               fixed = TRUE)
})

test_that("setup keeps the study URL when the session has no binary form", {
  root <- withr::local_tempdir()
  writeLines("{}", file.path(root, "renv.lock"))
  withr::local_options(repos = c(CRAN = "https://elsewhere.example/cran"))
  log <- local_setup(
    locked = "pkgA", lock_repos = paste0("CRAN=", src),
    restore_output = "HVTIR_LIB=@LIB@\nHVTIR_LOCKVER=pkgA:1.0:\n"
  )
  msgs <- testthat::capture_messages(setup("A study", 7L, root = root))
  expect_identical(log$pak_lib[[1L]]$repos, c(CRAN = src))
  expect_match(log$expr1, src, fixed = TRUE)
  expect_match(log$expr, src, fixed = TRUE)
  expect_false(grepl("lockfile_write", log$expr, fixed = TRUE))
  expect_false(grepl("recording it", paste(msgs, collapse = ""), fixed = TRUE))
})

# The version-floor step, run against temporary libraries.

dep_pkg <- function(lib, name, version, ...) {
  dir.create(file.path(lib, name))
  writeLines(
    c(paste("Package:", name), paste("Version:", version), "Title: x", ...),
    file.path(lib, name, "DESCRIPTION")
  )
}

test_that("a dependency below its floor is selected; a met one is not", {
  lib <- withr::local_tempdir()
  dep_pkg(lib, "pkgA", "1.0", "Imports: pkgB (>= 2.0), stats")
  dep_pkg(lib, "pkgB", "1.0")
  # Defined in setup.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  got <- unmet_requirements(lib, lib)
  expect_identical(got$dep, "pkgB")
  expect_identical(got$has, "1.0")
  dep_pkg(lib, "pkgC", "1.0", "Depends: R (>= 4.0), pkgB (> 1.0)",
          "LinkingTo: pkgD (== 3.0)")
  got <- unmet_requirements(lib, lib)
  expect_setequal(got$dep, c("pkgB", "pkgD"))
  expect_true(is.na(got$has[got$dep == "pkgD"]))
  unlink(file.path(lib, "pkgB"), recursive = TRUE)
  dep_pkg(lib, "pkgB", "2.0")
  dep_pkg(lib, "pkgD", "3.0")
  expect_identical(nrow(unmet_requirements(lib, lib)), 0L)
})

test_that("dash and dot versions are equal in the floor check", {
  lib <- withr::local_tempdir()
  dep_pkg(lib, "pkgA", "1.0", "Imports: pkgB (>= 1.2.5)")
  dep_pkg(lib, "pkgB", "1.2-5")
  expect_identical(nrow(unmet_requirements(lib, lib)), 0L)
  dep_pkg(lib, "pkgE", "1.0", "Imports: pkgF (>= 1.2-5)")
  dep_pkg(lib, "pkgF", "1.2.5")
  expect_identical(nrow(unmet_requirements(lib, lib)), 0L)
})

test_that("a dependency found only in a second library path is installed", {
  lib <- withr::local_tempdir()
  sys <- withr::local_tempdir()
  dep_pkg(lib, "pkgA", "1.0", "Imports: mgcv (>= 1.8)")
  dep_pkg(sys, "mgcv", "1.9")
  expect_identical(nrow(unmet_requirements(lib, c(lib, sys))), 0L)
  expect_identical(unmet_requirements(lib, lib)$dep, "mgcv")
})

# Run the child step for real, with fakes for install and quit.
run_floors <- function(lib, upgrade, fix = NULL, repos = NULL) {
  env <- new.env()
  env$lib <- lib
  env$upgrade <- upgrade
  env$hvtir_repos <- repos
  env$installed <- NULL
  env$fake_install <- function(x, ...) {
    assign("installed", x, envir = env)
    if (!is.null(fix)) fix()
  }
  code <- floors_expr("/tmp", "fake_install", repos)
  code <- sub("quit(status = 5L, save = 'no')", "cat('QUIT5\\n')", code,
              fixed = TRUE)
  out <- paste(capture.output(eval(parse(text = code), env)), collapse = "\n")
  list(out = out, installed = env$installed)
}

test_that("with upgrade the floor step installs, rechecks, and reports", {
  lib <- withr::local_tempdir()
  dep_pkg(lib, "pkgA", "1.0", "Imports: pkgB (>= 2.0)")
  dep_pkg(lib, "pkgB", "1.0")
  fix <- function() {
    unlink(file.path(lib, "pkgB"), recursive = TRUE)
    dep_pkg(lib, "pkgB", "2.1")
  }
  res <- run_floors(lib, TRUE, fix)
  expect_identical(res$installed, "pkgB")
  expect_match(res$out, "HVTIR_RAISED=pkgB", fixed = TRUE)
  expect_no_match(res$out, "HVTIR_UNMET", fixed = TRUE)
  expect_no_match(res$out, "QUIT5", fixed = TRUE)
  res <- run_floors(lib, TRUE, repos = c(CRAN = "https://x"))
  expect_null(res$installed)
  expect_identical(res$out, "")
})

test_that("with upgrade, what stays unmet exits 5 before the snapshot", {
  lib <- withr::local_tempdir()
  dep_pkg(lib, "pkgA", "1.0", "Imports: pkgB (>= 2.0), pkgC (> 1.0)")
  dep_pkg(lib, "pkgB", "1.0")
  res <- run_floors(lib, TRUE)
  expect_identical(res$installed, c("pkgB", "pkgC"))
  expect_match(res$out, "HVTIR_UNMET=pkgA needs pkgB (>= 2.0), has 1.0;",
               fixed = TRUE)
  expect_match(res$out, "pkgA needs pkgC (> 1.0), has none", fixed = TRUE)
  expect_match(res$out, "QUIT5", fixed = TRUE)
})

test_that("without upgrade the floor step installs nothing and exits 5", {
  lib <- withr::local_tempdir()
  dep_pkg(lib, "pkgA", "1.0", "Imports: pkgB (>= 2.0)")
  dep_pkg(lib, "pkgB", "1.0")
  res <- run_floors(lib, FALSE)
  expect_null(res$installed)
  expect_match(res$out, "HVTIR_UNMET=pkgA needs pkgB (>= 2.0), has 1.0",
               fixed = TRUE)
  expect_match(res$out, "QUIT5", fixed = TRUE)
})

test_that("child 2 meets floors after the LinkingTo fill, before the guard", {
  at <- anchor_at(finish_expr("/tmp", c(pkgA = "1.0"), repos = c(CRAN = "u")))
  expect_true(at("LinkingTo") < at("unmet <- unmet_requirements(lib)"))
  expect_true(at("unmet <- unmet_requirements(lib)") < at("quit(status = 5L"))
  expect_true(at("quit(status = 5L") < at("changed <- "))
  expect_match(finish_expr("/tmp", c(pkgA = "1.0"), repos = c(CRAN = "u")),
               "unique(unmet$dep), project = ", fixed = TRUE)
  expect_match(finish_expr("/tmp", c(pkgA = "1.0"), repos = c(CRAN = "u")),
               "prompt = FALSE, repos = hvtir_repos); cat('\\nHVTIR_RAISED",
               fixed = TRUE)
})

test_that("setup() aborts on unmet requirements, lockfile unchanged", {
  root <- withr::local_tempdir()
  local_setup(
    run_status = 5L,
    run_output = paste0(
      "HVTIR_UNMET=readxl needs cpp11 (>= 0.5.5), has 0.5.4;",
      "devtools needs pak (>= 0.9.3), has 0.9.2\n"
    )
  )
  err <- tryCatch(
    setup("A study", 7L, root = root, upgrade = FALSE),
    error = conditionMessage
  )
  expect_match(err, "readxl needs cpp11 (>= 0.5.5), has 0.5.4", fixed = TRUE)
  expect_match(err, "devtools needs pak", fixed = TRUE)
  expect_match(err, "renv.lock", fixed = TRUE)
  expect_match(err, "unchanged", fixed = TRUE)
  expect_match(err, "upgrade = TRUE", fixed = TRUE)
  expect_match(err, "installing the required versions", fixed = TRUE)
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_match(err, "still unmet", fixed = TRUE)
  expect_no_match(err, "(the default) resolves", fixed = TRUE)
})

test_that("raised packages that moved get their own group in the report", {
  got <- grouped_moves(
    c("hvtiR:1.0->1.1", "officer:0.7.4->0.7.7", "cpp11:0.5.4->0.5.5"),
    raised = "cpp11"
  )
  expect_identical(
    unname(got),
    c("Family packages", "hvtiR 1.0 -> 1.1",
      "Dependencies the family needs", "officer 0.7.4 -> 0.7.7",
      "Other unmet requirements resolved", "cpp11 0.5.4 -> 0.5.5")
  )
  root <- withr::local_tempdir()
  local_setup(
    run_output = paste0(
      "HVTIR_RAISED=cpp11\nHVTIR_MOVED=cpp11:0.5.4->0.5.5\nHVTIR_LIB=@LIB@\n"
    )
  )
  expect_message(setup("A study", 7L, root = root),
                 "Other unmet requirements resolved")
})
