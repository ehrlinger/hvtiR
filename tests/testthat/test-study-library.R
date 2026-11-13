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
  expect_error(
    require_study_library("update", project = "", library = "/home/u/R",
                          study = study),
    "lung\\.Rproj"
  )
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
