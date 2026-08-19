test_that("remote_version reads the Version field", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main") {
      read.dcf(test_path("fixtures", "DESCRIPTION-simple"))
    }
  )

  expect_identical(remote_version("ehrlinger/hvtiRutilities"), "1.0.10")
})

test_that("remote_version handles DESCRIPTION continuation lines", {
  # Version is wrapped onto a continuation line: grep("^Version:") would
  # return an empty value here, read.dcf resolves it to 2.7.6.
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main") {
      read.dcf(test_path("fixtures", "DESCRIPTION-continuation"))
    }
  )

  expect_identical(remote_version("ehrlinger/hvtiPlotR"), "2.7.6")
})

test_that("remote_version returns NA when the fetch fails", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main") NULL
  )

  expect_identical(remote_version("ehrlinger/nope"), NA_character_)
})

test_that("remote_version returns NA when DESCRIPTION has no Version field", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main") {
      read.dcf(textConnection("Package: broken\nTitle: No Version Here\n"))
    }
  )

  expect_identical(remote_version("ehrlinger/broken"), NA_character_)
})
