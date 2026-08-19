test_that("classify_status compares installed against latest", {
  expect_identical(classify_status("1.0.0", "1.0.0"), "ok")
  expect_identical(classify_status("1.0.0", "1.1.0"), "stale")
  expect_identical(classify_status("1.1.0", "1.0.0"), "ahead")
})

test_that("classify_status compares version segments numerically", {
  # string comparison would call 1.0.10 older than 1.0.9
  expect_identical(classify_status("1.0.10", "1.0.9"), "ahead")
  expect_identical(classify_status("1.0.9", "1.0.10"), "stale")
})

test_that("classify_status reports a package that is not installed", {
  expect_identical(classify_status(NA_character_, "1.0.0"), "missing")
  expect_identical(classify_status(NA_character_, NA_character_), "missing")
})

test_that("classify_status reports an unreachable remote", {
  expect_identical(classify_status("1.0.0", NA_character_), "unknown")
})

test_that("classify_status reports ok-local when the remote was not consulted", {
  expect_identical(
    classify_status("1.0.0", NA_character_, remote = FALSE),
    "ok-local"
  )
})

test_that("a package that is not installed stays missing when remote is FALSE", {
  expect_identical(
    classify_status(NA_character_, NA_character_, remote = FALSE),
    "missing"
  )
})
