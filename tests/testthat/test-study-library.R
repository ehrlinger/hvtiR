# hvtiR installs into a study's renv library, never a personal one. On
# 2026-11-12 an update() run outside the study's project installed into the
# user's own library, and the study's next snapshot then failed.

test_that("require_study_library passes when the library is the project's", {
  project <- withr::local_tempdir()
  lib <- file.path(project, "renv", "library", "R-4.6")
  dir.create(lib, recursive = TRUE)
  expect_identical(
    require_study_library("update", project = project, library = lib),
    project
  )
})

test_that("require_study_library stops when no project is active", {
  expect_error(
    require_study_library("update", project = "", library = "/home/u/R",
                          study = NULL),
    "personal library"
  )
  expect_error(
    require_study_library("update", project = "", library = "/home/u/R",
                          study = NULL),
    "\\.Rproj"
  )
})

test_that("require_study_library stops on a library outside the project", {
  project <- withr::local_tempdir()
  expect_error(
    require_study_library("update", project = project, library = "/home/u/R"),
    "personal library"
  )
})

test_that("require_study_library names the study's own .Rproj", {
  study <- withr::local_tempdir()
  file.create(file.path(study, "lung.Rproj"))
  dir.create(file.path(study, "renv"))
  file.create(file.path(study, "renv", "activate.R"))
  expect_error(
    require_study_library("update", project = "", library = "/home/u/R",
                          study = study),
    "lung\\.Rproj"
  )
})

test_that("a study with no renv library is sent to setup(), not its .Rproj", {
  # 2026-11-18: a study made with RStudio's New Project wizard had its .Rproj
  # open but no renv yet, and the hint to double-click that .Rproj led nowhere.
  study <- withr::local_tempdir()
  file.create(file.path(study, "2020.Rproj"))
  msg <- tryCatch(
    require_study_library("update", project = "", library = "/home/u/R",
                          study = study),
    error = conditionMessage
  )
  expect_match(msg, "no study library yet")
  expect_match(msg, "setup()", fixed = TRUE)
  expect_no_match(msg, "double-click")
  expect_no_match(msg, "outside any project")
})

test_that("a wizard project with no _study.yml is sent to setup()", {
  # Discovery, not a passed-in study: the project folder holds a .Rproj and
  # nothing else, so enclosing_study() finds no _study.yml.
  proj <- withr::local_tempdir()
  file.create(file.path(proj, "2020.Rproj"))
  withr::local_dir(proj)
  local_mocked_bindings(active_project = function() NULL)
  msg <- tryCatch(
    require_study_library("update", project = "", library = "/home/u/R"),
    error = conditionMessage
  )
  expect_match(msg, "no study library yet")
  expect_match(msg, "setup()", fixed = TRUE)
  expect_no_match(msg, "double-click")
  expect_no_match(msg, "outside any project")
})

test_that("a study with renv is sent to its .Rproj, with no setup() line", {
  study <- withr::local_tempdir()
  file.create(file.path(study, "lung.Rproj"))
  dir.create(file.path(study, "renv"))
  file.create(file.path(study, "renv", "activate.R"))
  msg <- tryCatch(
    require_study_library("update", project = "", library = "/home/u/R",
                          study = study),
    error = conditionMessage
  )
  expect_match(msg, "lung.Rproj", fixed = TRUE)
  expect_no_match(msg, "setup()", fixed = TRUE)
})

test_that("update() and install() stop before pak outside a study project", {
  local_mocked_bindings(
    session_library = function() "/home/u/R",
    enclosing_study = function() NULL,
    status = function(...) stop("status() ran"),
    pak_install = function(specs) stop("pak ran")
  )
  withr::local_envvar(RENV_PROJECT = "")
  expect_error(update(), "personal library")
  expect_error(install(), "personal library")
})

test_that("the status table opens with the missing project", {
  local_mocked_bindings(session_library = function() "/home/u/R",
                        enclosing_study = function() NULL)
  withr::local_envvar(RENV_PROJECT = "")
  st <- structure(
    data.frame(package = "hvtiRutilities", installed = "1.0.0",
               latest = "1.0.0", status = "ok"),
    class = c("hvtiR_status", "data.frame")
  )
  out <- capture.output(print(st))
  expect_match(out[2L], "Not in a study project")
})

test_that("the status table says nothing in a study project", {
  project <- withr::local_tempdir()
  lib <- file.path(project, "renv", "library")
  dir.create(lib, recursive = TRUE)
  local_mocked_bindings(session_library = function() lib)
  withr::local_envvar(RENV_PROJECT = project)
  st <- structure(
    data.frame(package = "hvtiRutilities", installed = "1.0.0",
               latest = "1.0.0", status = "ok"),
    class = c("hvtiR_status", "data.frame")
  )
  expect_no_match(paste(capture.output(print(st)), collapse = " "),
                  "Not in a study project")
})

test_that("pak installs into the library the guard checked, not pkg.library", {
  seen <- NULL
  local_mocked_bindings(
    pak = function(pkg, ...) {
      seen <<- list(...)$lib
      invisible(NULL)
    },
    .package = "pak"
  )
  withr::local_options(pkg.library = "/home/u/R")
  local_mocked_bindings(session_library = function() "/studies/x/renv/library")
  pak_install("ehrlinger/hvtiRutilities")
  expect_identical(seen, "/studies/x/renv/library")
})
