test_that("the catalog has 53 rows and every row is keyed", {
  raw <- read_jobs()

  expect_type(raw, "list")
  expect_length(raw, 53L)
  expect_true(all(vapply(raw, function(r) {
    is.character(r$prefix) || is.null(r$prefix)
  }, logical(1))))
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
    is_scaffold_or_thin <- identical(r$disposition, "scaffold") ||
      identical(r$disposition, "thin")
    if (is_scaffold_or_thin) {
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

  # Guard the vacuous pass: unlist() on rows that carry no destination
  # returns NULL, and all(NULL %in% x) is all(logical(0)), which is TRUE.
  # Renaming the JSON key would otherwise leave this test green while
  # every routing had silently lost its destination.
  expect_gt(length(dest), 0L)
  expect_true(all(dest %in% members()$package),
              info = paste(setdiff(dest, members()$package), collapse = ", "))
})

test_that("jobs() returns one row per job type with a list column", {
  j <- jobs()

  expect_s3_class(j, "data.frame")
  expect_identical(nrow(j), 53L)
  expect_true(all(c("prefix", "folder", "disposition", "destination",
                    "replaced_by") %in% names(j)))
  expect_type(j$replaced_by, "list")
  expect_type(j$sas_breadth, "integer")
})

test_that("jobs() has exactly the seeded count of retire rows, each replaced", {
  j <- jobs()

  # 5 is the seeded count as of this catalog. A sixth retirement is not a
  # bug, but it should change this number on purpose rather than by
  # surprise, so a failure here points a future author at this line.
  expect_identical(sum(j$disposition == "retire"), 5L)
  expect_true(all(lengths(j$replaced_by[j$disposition == "retire"]) > 0L))
})

test_that("the real blocked_on values for sid, vt and rfr are pinned", {
  j <- jobs()

  # sid and vt are disposition build; rfr is disposition retire. All three
  # carry the same real blocker, hvtiRutilities#taxonomy, unlike the five
  # placeholder build rows still waiting on an issue. A placeholder sweep
  # that overwrites blocked_on wholesale would silently clobber these three;
  # this test is here so that overwrite fails loudly instead.
  # which(), not a bare logical: an NA prefix -- which the schema test
  # above permits -- indexes in an NA element and fails these pins with
  # a message about the blockers rather than about the malformed row.
  by_prefix <- function(p) j$blocked_on[which(j$prefix == p)]

  expect_identical(by_prefix("sid"), "hvtiRutilities#taxonomy")
  expect_identical(by_prefix("vt"), "hvtiRutilities#taxonomy")
  expect_identical(by_prefix("rfr"), "hvtiRutilities#taxonomy")
})

test_that("jobs() names the row and field when a scalar arrives as an array", {
  # The catalog is hand edited and four of its fields are arrays, so a scalar
  # written as one is a plausible slip. vapply's own message for it names
  # neither the row nor the field, and the first sign is the vignette failing
  # to build. Mocked over the reader, per the seam this package already uses
  # for the network.
  testthat::local_mocked_bindings(
    read_jobs = function(...) {
      list(
        list(prefix = "aa", disposition = "scaffold",
             destination = "hvtiRtemplates", blocked_on = "x#1"),
        list(prefix = "bb", disposition = "scaffold",
             destination = "hvtiRtemplates", blocked_on = c("x#1", "x#2"))
      )
    }
  )

  expect_error(jobs(), "row 2")
  expect_error(jobs(), "prefix 'bb'")
  expect_error(jobs(), "blocked_on")
})

test_that("jobs() still reads a row whose scalar fields are absent", {
  testthat::local_mocked_bindings(
    read_jobs = function(...) {
      list(list(prefix = "aa", disposition = "scaffold",
                destination = "hvtiRtemplates"))
    }
  )

  j <- jobs()

  expect_identical(nrow(j), 1L)
  expect_true(is.na(j$blocked_on))
  expect_true(is.na(j$sas_breadth))
})
