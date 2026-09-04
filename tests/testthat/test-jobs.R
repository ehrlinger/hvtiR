test_that("the catalog has 53 rows and every row is keyed", {
  raw <- read_jobs()

  expect_type(raw, "list")
  expect_length(raw, 53L)
  expect_true(all(vapply(raw, function(r) is.character(r$prefix) ||
                           is.null(r$prefix), logical(1))))
})

test_that("prefix and qualifier together are unique", {
  raw <- read_jobs()
  key <- vapply(raw, function(r) {
    paste0(if (is.null(r$prefix)) "<NA>" else r$prefix, "\r",
           if (is.null(r$qualifier)) "<NA>" else r$qualifier)
  }, character(1))

  expect_identical(anyDuplicated(key), 0L)
})

test_that("every row carries a disposition from the enum", {
  raw <- read_jobs()
  d <- vapply(raw, function(r) {
    if (is.null(r$disposition)) NA_character_ else r$disposition
  }, character(1))

  expect_false(anyNA(d))
  expect_true(all(d %in% c("scaffold", "thin", "retire", "build")))
})

test_that("a retired row names what replaced it", {
  raw <- read_jobs()
  retired <- Filter(function(r) identical(r$disposition, "retire"), raw)

  expect_gt(length(retired), 0L)
  for (r in retired) {
    expect_false(is.null(r$destination), label = r$prefix)
    expect_gt(length(r$replaced_by), 0L)
  }
})

test_that("a scaffold or thin row is destined for hvtiRtemplates", {
  raw <- read_jobs()
  for (r in raw) {
    if (r$disposition %in% c("scaffold", "thin")) {
      expect_identical(r$destination, "hvtiRtemplates", label = r$prefix)
    }
  }
})

test_that("a build row names a destination, no replacement, and a blocker", {
  raw <- read_jobs()
  for (r in raw) {
    if (identical(r$disposition, "build")) {
      expect_false(is.null(r$destination), label = r$prefix)
      expect_length(r$replaced_by, 0L)
      expect_false(is.null(r$blocked_on), label = r$prefix)
    }
  }
})

test_that("every destination is a family member", {
  raw <- read_jobs()
  dest <- unique(unlist(lapply(raw, function(r) r$destination)))

  expect_true(all(dest %in% members()$package))
})
