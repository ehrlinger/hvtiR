test_that("check_loaded finds targets that are already loaded", {
  expect_identical(
    check_loaded(c("hvtiPlotR", "hvtiRtables"), loaded = c("stats", "hvtiPlotR")),
    "hvtiPlotR"
  )
})

test_that("check_loaded returns an empty vector when nothing is loaded", {
  expect_length(
    check_loaded(c("hvtiPlotR", "hvtiRtables"), loaded = c("stats", "utils")),
    0L
  )
})

test_that("check_loaded handles an empty target set", {
  expect_length(check_loaded(character(0), loaded = c("stats")), 0L)
})

test_that("build_specs maps package names to repositories", {
  m <- hvtiverse_members()

  expect_identical(
    build_specs(m, c("hvtiRutilities", "hvtiPlotR")),
    c("ehrlinger/hvtiRutilities", "ehrlinger/hvtiPlotR")
  )
})

test_that("build_specs resolves the two name mismatches", {
  m <- hvtiverse_members()

  expect_identical(
    build_specs(m, c("TemporalHazard", "hvtiRpropensity")),
    c("ehrlinger/temporal_hazard", "ehrlinger/hvtiPropensityScores")
  )
})

test_that("build_specs preserves the order it was given", {
  m <- hvtiverse_members()

  expect_identical(
    build_specs(m, c("ggRandomForests", "hvtiRutilities")),
    c("ehrlinger/ggRandomForests", "ehrlinger/hvtiRutilities")
  )
})

test_that("build_specs errors on a package that is not a member", {
  m <- hvtiverse_members()

  expect_error(build_specs(m, "dplyr"), "not an hvtiverse member")
})
