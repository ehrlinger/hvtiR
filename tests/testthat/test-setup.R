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
                        run_output = "installing\nHVTIR_LIB=@LIB@\n",
                        renv_present = TRUE,
                        session_lib = "/nonexistent/session/lib",
                        gone = data.frame(
                          package = character(), missing = character()
                        ),
                        locked_r = NA_character_, locked = NULL,
                        credentials = TRUE, subdir = character(0),
                        root_error = "study_config(): no _study.yml found.",
                        env = parent.frame()) {
  log <- new.env()
  lib <- withr::local_tempdir(.local_envir = env)
  log$pak <- list()
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
          output = paste0("HVTIR_LOCKED=", paste(locked, collapse = ","), "\n")
        ))
      }
      log$expr <- expr
      step("run")
      out <- gsub("@LIB@", lib, run_output, fixed = TRUE)
      list(status = run_status, output = out)
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
    subdir_remotes = function(...) subdir,
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
    log$steps, c("pak", "prefs", "study_setup", "declare", "run", "open")
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

test_that("the child turns renv's pak back end off in code, not env", {
  root <- withr::local_tempdir()
  log <- local_setup()
  setup("A study", 7L, root = root)
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

remotes_field <- paste(
  "boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.7-ccf,",
  "ehrlinger/hvtiRutilities,",
  "gitlab::someone/proj/sub,",
  "url::https://example.org/a/b/c"
)

test_that("only GitHub remotes with a subdirectory are kept", {
  got <- parse_subdir_remotes(remotes_field)
  expect_identical(
    got,
    c(boostmtree = "boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.7-ccf")
  )
})

test_that("a subdirectory remote with no name= is named by its subdirectory", {
  got <- parse_subdir_remotes("github::o/r/pkgdir@main\no/plain")
  expect_identical(names(got), "pkgdir")
  expect_identical(unname(got), "github::o/r/pkgdir@main")
})

test_that("a missing Remotes field gives nothing", {
  expect_identical(parse_subdir_remotes(NA), character(0))
  expect_identical(parse_subdir_remotes(NULL), character(0))
})

test_that("subdir_remotes reads each member, dedupes, and warns on a failure", {
  registry <- data.frame(
    package = c("a", "b", "c"), repo = c("o/a", "o/b", "o/c")
  )
  local_mocked_bindings(
    fetch_description = function(repo, ...) {
      if (repo == "o/c") return(NULL)
      cbind(Remotes = "boostmtree=o/src/boostmtree@v1")
    }
  )
  expect_warning(got <- subdir_remotes(registry), "c")
  expect_identical(unname(got), "boostmtree=o/src/boostmtree@v1")
  expect_identical(names(got), "boostmtree")
})

test_that("subdirectory remotes install after restore and before the rest", {
  expr <- install_expr(
    "/tmp", c("hvtiR", "arrow"),
    subdir = c(boostmtree = "boostmtree=o/src/boostmtree@v1")
  )
  at <- function(s) regexpr(s, expr, fixed = TRUE)[[1L]]
  expect_true(at("renv::restore(") < at("boostmtree=o/src/boostmtree@v1"))
  expect_true(at("boostmtree=o/src/boostmtree@v1") < at("add <- "))
  expect_true(at("pre <- pre[!\"boostmtree\" %in% locked]") > 0)
  expect_equal(lengths(regmatches(expr, gregexpr("renv::install(", expr,
                                                 fixed = TRUE))), 2L)
})

test_that("with no subdirectory remotes the child makes one install call", {
  expr <- install_expr("/tmp", c("hvtiR", "arrow"))
  expect_equal(lengths(regmatches(expr, gregexpr("renv::install(", expr,
                                                 fixed = TRUE))), 1L)
})

test_that("setup passes the subdirectory remotes to the child", {
  root <- withr::local_tempdir()
  log <- local_setup(subdir = c(boostmtree = "boostmtree=o/src/boostmtree@v1"))
  setup("A study", 7L, root = root)
  expect_match(log$expr, "boostmtree=o/src/boostmtree@v1", fixed = TRUE)
})

test_that("missing GitHub credentials warn and name the fix", {
  root <- withr::local_tempdir()
  log <- local_setup(credentials = FALSE)
  expect_message(
    setup("A study", 7L, root = root), "rate limit"
  )
  expect_message(
    setup("A study", 7L, root = root), "gitcreds_set"
  )
  expect_identical(log$steps[[1L]], "prefs")
})

test_that("with credentials there is no credentials warning", {
  root <- withr::local_tempdir()
  local_setup(credentials = TRUE)
  expect_no_match(
    capture.output(setup("A study", 7L, root = root), type = "message"),
    "rate limit"
  )
})

test_that("a GITHUB_PAT counts as credentials", {
  withr::local_envvar(GITHUB_PAT = "x")
  expect_true(github_credentials_available())
})

test_that("with no PAT and no gitcreds there are no credentials", {
  withr::local_envvar(GITHUB_PAT = "")
  local_mocked_bindings(
    requireNamespace = function(...) FALSE, .package = "base"
  )
  expect_false(github_credentials_available())
})

test_that("a failed install with an authentication error adds the hint", {
  root <- withr::local_tempdir()
  local_setup(
    run_status = 1L,
    run_output = "GitHub authentication credentials are not available\n"
  )
  expect_error(setup("A study", 7L, root = root), "gitcreds_set")
})

test_that("a failed install without that error carries no hint", {
  root <- withr::local_tempdir()
  local_setup(run_status = 1L, run_output = "boom\n")
  expect_error(
    setup("A study", 7L, root = root), "boom"
  )
  err <- tryCatch(setup("A study", 7L, root = root), error = conditionMessage)
  expect_no_match(err, "gitcreds_set")
})

test_that("the child records locked versions, then compares before snapshot", {
  expr <- install_expr("/tmp", c("hvtiR", "arrow"))
  at <- function(s) regexpr(s, expr, fixed = TRUE)[[1L]]
  expect_true(at("before <- ") > 0)
  expect_true(at("before <- ") < at("renv::install("))
  expect_true(at("renv::install(") < at("changed <- "))
  expect_true(at("changed <- ") < at("packages = changed"))
  expect_true(at("packages = changed") < at("HVTIR_CHANGED="))
  expect_true(at("HVTIR_CHANGED=") < at("quit(status = 3L"))
  expect_true(at("quit(status = 3L") < at("renv::snapshot("))
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
  expect_match(err, "update", fixed = TRUE)
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
  withr::local_envvar(RENV_PROJECT = "")
  local_mocked_bindings(installed_version = function(pkg) NA_character_)
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

test_that("the child cleans, drops the cache, isolates, then restores", {
  expr <- install_expr("/tmp", c("hvtiR", "arrow"))
  at <- function(s) regexpr(s, expr, fixed = TRUE)[[1L]]
  expect_true(at("renv::load(") < at("HVTIR_UNLINKED="))
  # The cleanup comes first: a leftover _cache makes renv's own scan fail.
  expect_true(at("HVTIR_UNLINKED=") < at("use.cache(FALSE"))
  expect_true(at("use.cache(FALSE") < at("renv::isolate("))
  expect_true(at("renv::isolate(") < at("renv::restore("))
  expect_true(at("renv::restore(") < at("renv::install("))
  expect_match(expr, "options(renv.config.pak.enabled = FALSE)", fixed = TRUE)
  expect_match(expr, "snapshot.type('explicit'", fixed = TRUE)
})

test_that("setup reports the links the child removed", {
  root <- withr::local_tempdir()
  local_setup(run_output = "HVTIR_UNLINKED=dplyr,_cache\nHVTIR_LIB=@LIB@\n")
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

test_that("install_members warns about debris when renv is active", {
  local_mocked_bindings(
    pak_install = function(specs) invisible(specs),
    renv_state = function(...) "active",
    session_library = function() "/study/renv/library",
    library_debris = function(lib) c("dplyr", "_cache")
  )
  expect_warning(
    install_members("hvtiPlotR"), "use.cache(FALSE)", fixed = TRUE
  )
  expect_warning(
    install_members("hvtiPlotR"), "dplyr", fixed = TRUE
  )
})

test_that("install_members is quiet about debris without an active project", {
  local_mocked_bindings(
    pak_install = function(specs) invisible(specs),
    renv_state = function(...) "installed",
    library_debris = function(lib) stop("must not be asked")
  )
  expect_no_warning(install_members("hvtiPlotR"))
})
