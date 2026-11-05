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

fails <- function(package, cause, needs = NA_character_) {
  data.frame(package = package, cause = cause, needs = needs,
             stringsAsFactors = FALSE)
}
decide <- function(f, specs = stats::setNames(f$package, f$package),
                   moved = character(), missing = character(),
                   essential = "hvtiRutilities", upgrade = TRUE,
                   stuck = FALSE) {
  plan_round(f, specs, moved, missing, essential, upgrade, stuck)
}

test_that("a compile failure moves its pin under upgrade = TRUE", {
  r <- decide(fails("vctrs", "compile"))
  expect_identical(r$move, c(vctrs = "vctrs"))
  expect_identical(nrow(r$drop), 0L)
})

test_that("a pin that already moved is not moved again but dropped", {
  r <- decide(fails("vctrs", "compile"), moved = "vctrs")
  expect_length(r$move, 0L)
  expect_identical(r$drop$package, "vctrs")
  expect_match(r$drop$reason, "after its version moved")
})

test_that("upgrade = FALSE moves nothing", {
  r <- decide(fails("vctrs", "compile"), upgrade = FALSE)
  expect_length(r$move, 0L)
  expect_identical(r$drop$package, "vctrs")
})

test_that("a package with no safe spec is dropped, not moved", {
  r <- decide(fails("odd", "compile"), specs = c(odd = NA_character_))
  expect_length(r$move, 0L)
  expect_identical(r$drop$package, "odd")
})

test_that("a missing dependency is installed first", {
  r <- decide(fails("forecast", "dependency", "tseries"))
  expect_identical(r$install, "tseries")
  expect_identical(nrow(r$drop), 0L)
})

test_that("a dependency already left out drops its dependent, saying why", {
  r <- decide(fails("forecast", "dependency", "tseries"), missing = "tseries")
  expect_identical(r$drop$package, "forecast")
  expect_identical(r$drop$because, "tseries")
})

test_that("a stuck round drops what it would otherwise retry", {
  r <- decide(fails(c("vctrs", "forecast"), c("compile", "dependency"),
                    c(NA, "tseries")), stuck = TRUE)
  expect_length(r$move, 0L)
  expect_length(r$install, 0L)
  expect_setequal(r$drop$package, c("vctrs", "forecast"))
})

test_that("an essential package is never dropped: it stops", {
  r <- decide(fails("hvtiRutilities", "other"))
  expect_identical(r$stop, "hvtiRutilities")
  expect_identical(nrow(r$drop), 0L)
  r <- decide(fails("hvtiRutilities", "compile"), moved = "hvtiRutilities")
  expect_identical(r$stop, "hvtiRutilities")
})

test_that("an other failure is dropped with its reason", {
  r <- decide(fails("igraph", "other"))
  expect_identical(r$drop$package, "igraph")
  expect_identical(r$drop$reason, "failed to install")
})

test_that("an essential package whose dependency was left out stops", {
  r <- decide(fails("hvtiRutilities", "dependency", "tseries"),
              missing = "tseries")
  expect_identical(r$stop, "hvtiRutilities")
  expect_identical(nrow(r$drop), 0L)
})
