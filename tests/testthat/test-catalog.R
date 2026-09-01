# The catalog carries presentation metadata for every published artifact:
# the family members from members(), plus the SAS/C code and the Quarto book,
# which are not R packages and so cannot come from the registry.
#
# These tests are the drift guard at the source. A member added to members()
# without a catalog entry fails R CMD check, before any downstream sink can
# render an incomplete list.

catalog <- function() {
  read_catalog(system.file("extdata", "catalog.csv", package = "hvtiR"))
}

test_that("the catalog file ships with the package", {
  path <- system.file("extdata", "catalog.csv", package = "hvtiR")

  expect_true(nzchar(path))
  expect_true(file.exists(path))
})

test_that("the catalog has the documented columns", {
  cat <- catalog()

  expect_s3_class(cat, "data.frame")
  expect_identical(
    names(cat),
    c(
      "package", "repo", "family", "blurb", "cran", "status", "role",
      "homepage"
    )
  )
  expect_true(all(vapply(cat, is.character, logical(1))))
})

test_that("catalog members are exactly the registry members", {
  cat <- catalog()
  m <- members()

  expect_setequal(cat$package[cat$family == "member"], m$package)
  expect_identical(sum(cat$family == "member"), nrow(m))
})

test_that("every member's repository matches the registry", {
  cat <- catalog()
  m <- members()
  mem <- cat[cat$family == "member", c("package", "repo")]

  joined <- merge(mem, m, by = "package", suffixes = c("_catalog", "_registry"))

  expect_identical(nrow(joined), nrow(m))
  expect_identical(joined$repo_catalog, joined$repo_registry)
})

test_that("every entry has a non-empty blurb", {
  cat <- catalog()

  expect_true(all(nzchar(trimws(cat$blurb))))
})

test_that("the blurb carries no status or CRAN text", {
  # Status and CRAN presence are fields, so that each sink can render them in
  # its own house style. Leaking them into the blurb is what forced the same
  # edit to be made in three repositories by hand.
  cat <- catalog()

  expect_false(any(grepl("in active development|on CRAN|\\(Maintainer\\)",
                         cat$blurb, ignore.case = TRUE)))
})

test_that("family and status values are within their allowed sets", {
  cat <- catalog()

  expect_true(all(cat$family %in% c("member", "standalone", "book")))
  expect_true(all(cat$status %in% c("stable", "wip")))
})

test_that("package names are unique", {
  cat <- catalog()

  expect_identical(anyDuplicated(cat$package), 0L)
})

test_that("every member on CRAN names itself", {
  # cran is the CRAN package name, not a flag; a mismatch would render a
  # broken CRAN link in all three sinks.
  cat <- catalog()
  on_cran <- cat[nzchar(cat$cran), ]

  expect_identical(on_cran$cran, on_cran$package)
})

test_that("blurbs are ASCII so each sink can pick its own typography", {
  # The same blurb renders as Quarto prose, a Markdown table cell and an HTML
  # card. Storing a literal em dash would force one file's convention on the
  # other two, so the catalog stores " -- " and each renderer substitutes.
  cat <- catalog()

  non_ascii <- cat$package[grepl("[^\x01-\x7F]", cat$blurb)]

  expect_identical(non_ascii, character(0))
})
