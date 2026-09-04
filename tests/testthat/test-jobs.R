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
