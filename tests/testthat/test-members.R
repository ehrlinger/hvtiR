test_that("the registry has one row per member with two character columns", {
  m <- hvtiverse_members()

  expect_s3_class(m, "data.frame")
  expect_identical(names(m), c("package", "repo"))
  expect_identical(nrow(m), 11L)
  expect_type(m$package, "character")
  expect_type(m$repo, "character")
})

test_that("the registry has no duplicate packages or repositories", {
  m <- hvtiverse_members()

  expect_identical(anyDuplicated(m$package), 0L)
  expect_identical(anyDuplicated(m$repo), 0L)
})

test_that("every member repository is owned by ehrlinger", {
  m <- hvtiverse_members()

  expect_true(all(grepl("^ehrlinger/", m$repo)))
})

test_that("the two name mismatches are recorded", {
  m <- hvtiverse_members()

  expect_identical(
    m$repo[m$package == "hvtiRpropensity"],
    "ehrlinger/hvtiPropensityScores"
  )
  expect_identical(
    m$repo[m$package == "TemporalHazard"],
    "ehrlinger/temporal_hazard"
  )
})
