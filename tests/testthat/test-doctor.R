test_that("doctor reports the R version and the platform", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  expect_output(doctor(), "R version")
  expect_output(doctor(), "Platform")
})

test_that("doctor returns the status table invisibly", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  expect_invisible(doctor())

  st <- suppressMessages(doctor())
  expect_s3_class(st, "hvtiR_status")
})

test_that("doctor works with no network", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      stop("must not be called when remote = FALSE")
    }
  )

  output <- capture.output(
    st <- expect_no_error(suppressMessages(doctor(remote = FALSE)))
  )
  expect_true(all(st$status == "ok-local"))
  expect_true(any(grepl("pak", output)))
  expect_false(any(grepl("Remote checks", output)))
})

test_that("doctor reports when pak is not installed", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    pak_available = function() FALSE
  )

  expect_output(doctor(), "pak.*not installed")
})

test_that("doctor prints the reason a remote check failed", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      if (repo == "ehrlinger/hvtiPlotR") {
        return(structure(
          NA_character_,
          remote_error = "connection timed out"
        ))
      }
      "1.0.0"
    },
    pak_available = function() TRUE
  )

  expect_warning(
    expect_output(doctor(), "hvtiPlotR.*connection timed out"),
    "Could not determine the latest version"
  )
})
