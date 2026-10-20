test_that("setup cleans a legacy study before renv, locks declared packages", {
  skip_if_not(identical(Sys.getenv("HVTIR_E2E"), "true"),
              "set HVTIR_E2E=true to run")
  skip_on_cran()
  skip_if_not_installed("renv")
  skip_if_not_installed("praise")
  skip_if_not_installed("hvtiRutilities", UTILITIES_FLOOR)

  corpus <- withr::local_tempdir()
  writeLines("corpus", file.path(corpus, "README.txt"))
  root <- file.path(withr::local_tempdir(), "legacy")
  dir.create(file.path(root, "analyses"), recursive = TRUE)
  writeLines("library(praise)",
             file.path(root, "analyses", "tp.hz.R"))
  writeLines("study: legacy", file.path(root, "notes.txt"))

  local_mocked_bindings(set_workspace_prefs = function() invisible(FALSE),
                        open_project = function(root) invisible(NULL))
  setup("Legacy", 1L, root = root, adopt = TRUE, template_dir = corpus)

  expect_false(file.exists(file.path(root, "analyses", "tp.hz.R")))
  # In explicit mode an undeclared package cannot reach the lockfile, whatever
  # order runs, so cleanup-before-renv is asserted by the deleted file above,
  # not by the lockfile.
  lock <- paste(readLines(file.path(root, "renv.lock")), collapse = "\n")
  expect_false(grepl('"praise"', lock, fixed = TRUE))
  settings <- paste(
    readLines(file.path(root, "renv", "settings.json")), collapse = "\n"
  )
  expect_match(settings, '"snapshot.type": "explicit"', fixed = TRUE)
  expect_true(grepl('"hvtiRutilities"', lock, fixed = TRUE))
  expect_true(grepl('"arrow"', lock, fixed = TRUE))
})
