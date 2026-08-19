test_that("hvtiverse_doctor reports the R version and the platform", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  expect_output(hvtiverse_doctor(), "R version")
  expect_output(hvtiverse_doctor(), "Platform")
})

test_that("hvtiverse_doctor returns the status table invisibly", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  expect_invisible(hvtiverse_doctor())

  st <- suppressMessages(hvtiverse_doctor())
  expect_s3_class(st, "hvtiverse_status")
})

test_that("hvtiverse_doctor works with no network", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      stop("must not be called when remote = FALSE")
    }
  )

  st <- expect_no_error(suppressMessages(hvtiverse_doctor(remote = FALSE)))
  expect_true(all(st$status == "ok-local"))
})
