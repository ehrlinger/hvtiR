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

  st <- expect_no_error(suppressMessages(doctor(remote = FALSE)))
  expect_true(all(st$status == "ok-local"))
})
