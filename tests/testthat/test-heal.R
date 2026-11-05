test_that("compile and configure failures are compile causes", {
  out <- paste(
    "ERROR: compilation failed for package ‘vctrs’",
    "ERROR: configuration failed for package ‘arrow’",
    sep = "\n"
  )
  f <- classify_failures(out)
  expect_identical(f$package, c("vctrs", "arrow"))
  expect_identical(f$cause, c("compile", "compile"))
  expect_true(all(is.na(f$needs)))
})

test_that("a missing dependency names the package and what it needs", {
  out <- "ERROR: dependency ‘tseries’ is not available for package ‘forecast’"
  f <- classify_failures(out)
  expect_identical(f$package, "forecast")
  expect_identical(f$cause, "dependency")
  expect_identical(f$needs, "tseries")
})

test_that("renv's failed list fills in packages with no other cause", {
  out <- paste(
    "ERROR: compilation failed for package 'xts'",
    "Error: failed to install \"xts\", \"igraph\"",
    sep = "\n"
  )
  f <- classify_failures(out)
  expect_identical(f$package, c("xts", "igraph"))
  expect_identical(f$cause, c("compile", "other"))
})

test_that("output with no recognisable failure gives no rows", {
  f <- classify_failures("Error: could not resolve host")
  expect_identical(nrow(f), 0L)
  expect_named(f, c("package", "cause", "needs"))
})

test_that("only valid package names are taken from untrusted output", {
  out <- "ERROR: compilation failed for package ‘bad name;rm’"
  expect_identical(nrow(classify_failures(out)), 0L)
})
