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

  expect_true(all(dest %in% members()$package))
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
  by_prefix <- function(p) j$blocked_on[j$prefix == p]

  expect_identical(by_prefix("sid"), "hvtiRutilities#taxonomy")
  expect_identical(by_prefix("vt"), "hvtiRutilities#taxonomy")
  expect_identical(by_prefix("rfr"), "hvtiRutilities#taxonomy")
})

test_that("no row is still blocked on a placeholder", {
  raw <- read_jobs()
  stale <- vapply(raw, function(r) {
    b <- r$blocked_on
    !is.null(b) && grepl("^needs an issue", b)
  }, logical(1))

  expect_identical(sum(stale), 0L)
})

test_that("a build row that is not intake names a real issue", {
  raw <- read_jobs()
  for (r in raw) {
    if (identical(r$disposition, "build") &&
          !identical(r$status, "intake")) {
      expect_match(r$blocked_on, "^[A-Za-z]+#[0-9]+$", label = r$prefix)
    }
  }
})
