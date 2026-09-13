test_that("the catalog has 57 rows and every row is keyed", {
  raw <- read_jobs()

  expect_type(raw, "list")
  expect_length(raw, 57L)
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
  expect_identical(nrow(j), 57L)
  # The relationship, which cannot go stale the way the literal above does:
  # jobs() returns exactly one row per catalog entry.
  expect_identical(nrow(j), length(read_jobs()))
  expect_true(all(c("prefix", "folder", "disposition", "destination",
                    "replaced_by") %in% names(j)))
  expect_type(j$replaced_by, "list")
  expect_type(j$sas_breadth, "integer")
  # sas_breadth_jobs is the figure of record, and r_exemplars travels with
  # r_jobs; a catalog reader that cannot see either reads the wrong column.
  expect_type(j$sas_breadth_jobs, "integer")
  expect_type(j$r_exemplars, "integer")
})

test_that("dc-stddiff counts the union of its folded spellings, pinned", {
  j <- jobs()
  row <- which(j$prefix == "dc" & j$qualifier %in% "stddiff")

  # 59 was the 2019 spelling alone. The row absorbs std_dif (72) and four
  # rarer spellings, and a study using two of them is one study, so the
  # figure is the union from the 2026-09-11 scan: 120, where the sum is 157.
  # 59 here means the rule was read as deciding the population as well as
  # the label; 157 means the union was replaced by a sum.
  expect_length(row, 1L)
  expect_identical(j$sas_breadth_jobs[row], 120L)
})

test_that("the qualified rows' R counts are pinned, and dp-postage is NA", {
  j <- jobs()
  at <- function(p, q) which(j$prefix == p & j$qualifier %in% q)

  # From the 2026-09-11 scan of the 2026-08-27 census, by the 2026-08-29
  # definition, which that scan reproduced for all 42 prefixes. Type checks
  # alone pass when every value reverts to null, so the values are pinned; a
  # re-census that moves them should change these on purpose.
  want <- data.frame(
    prefix = c("dc", "dc", "dc", "dc", "dc", "dc",
               "dp", "dp", "dp", "dp", "dp", "dp"),
    qualifier = c("general", "tables", "gfup", "dead", "stddiff", "trends",
                  "trends", "gfup", "spaghetti", "procs", "variable",
                  "boxplot"),
    r_jobs = c(1L, 1L, 0L, 0L, 0L, 0L, 105L, 50L, 68L, 0L, 2L, 2L),
    r_exemplars = c(1L, 1L, 0L, 0L, 0L, 0L, 75L, 4L, 40L, 0L, 2L, 2L),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(want))) {
    row <- at(want$prefix[i], want$qualifier[i])
    label <- paste0(want$prefix[i], "-", want$qualifier[i])
    expect_length(row, 1L)
    expect_identical(j$r_jobs[row], want$r_jobs[i], label = label)
    expect_identical(j$r_exemplars[row], want$r_exemplars[i], label = label)
  }

  # dp-postage is named by dataset, not by a name field, so a literal count
  # would be a false zero. NA is the finding here, and 0 would be the defect.
  postage <- at("dp", "postage")
  expect_length(postage, 1L)
  expect_true(is.na(j$sas_breadth_jobs[postage]))
  expect_true(is.na(j$r_jobs[postage]))
  expect_true(is.na(j$r_exemplars[postage]))
})

test_that("pm is folded into lm, and si and mi count jobs, pinned", {
  j <- jobs()
  at <- function(p) which(j$prefix == p & is.na(j$qualifier))

  # pm folds into lm (2026-09-11): lm counts the studies with either prefix,
  # 470, where lm alone is 469. pm's own row went on 2026-09-13 with its
  # taxonomy entry, since hvtiRtemplates wants catalog and taxonomy to match.
  expect_identical(j$sas_breadth_jobs[at("lm")], 470L)
  expect_identical(j$disposition[at("lm")], "thin")
  expect_length(at("pm"), 0L)
  # si and mi count jobs, as every row does; mi includes bd's multiple-
  # imputation jobs. 223 or 326 here would mean the macro call counts came
  # back into the field.
  expect_identical(j$sas_breadth_jobs[at("si")], 1L)
  expect_identical(j$sas_breadth_jobs[at("mi")], 18L)
})

test_that("the hazard rows name the TemporalHazard functions they call", {
  j <- jobs()
  at <- function(p) which(j$prefix == p & is.na(j$qualifier))

  # Read from the shipped templates in hvtiRtemplates on 2026-09-13. bc is a
  # Cox job and calls none of them, so it must not grow a reference either.
  uses <- list(ac = "hzr_kaplan", hz = c("hazard", "hzr_phase"),
               hm = c("hazard", "hzr_stepwise", "hzr_deciles", "hzr_gof"),
               hp = "hazard", hs = c("hazard", "hzr_stepwise"),
               bh = c("hzr_bootstrap", "hzr_stepwise"))
  for (p in names(uses)) {
    got <- j$replaced_by[[at(p)]]
    expect_true(all(paste0("TemporalHazard::", uses[[p]]) %in% got),
                label = p)
  }
  expect_false(any(grepl("^TemporalHazard::", j$replaced_by[[at("bc")]])))
})

test_that("the relabelled rows carry the taxonomy's new names, pinned", {
  j <- jobs()
  at <- function(p) which(j$prefix == p & is.na(j$qualifier))

  # The 2026-09-11 review relabelled these in hvti_taxonomy(). The catalog
  # copies the names, and nothing else checks that the two agree, so a later
  # edit reverting one would otherwise pass.
  want <- c(bn = "Bootstrap non-linear", nd = "Non-linear distributions",
            nm = "Non-linear model", np = "Non-linear plot", nb = "Boosting")
  for (p in names(want)) {
    expect_identical(j$name[at(p)], want[[p]], label = p)
  }
})

test_that("jobs() has exactly the seeded count of retire rows, each replaced", {
  j <- jobs()

  # 5 is the seeded count as of this catalog. A sixth retirement is not a
  # bug, but it should change this number on purpose rather than by
  # surprise, so a failure here points a future author at this line.
  # pm was a sixth from 2026-09-11 until 2026-09-13, when it left the
  # taxonomy and its row went with it; see the lm pin below.
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

test_that("jobs() names the row and field for a non-numeric count", {
  # as.integer() would make this NA with a warning, which reads downstream as
  # a field the catalog simply omits rather than one written wrong.
  testthat::local_mocked_bindings(
    read_jobs = function(...) {
      list(list(prefix = "aa", disposition = "scaffold",
                destination = "hvtiRtemplates", sas_breadth = "several"))
    }
  )

  expect_error(jobs(), "row 1")
  expect_error(jobs(), "prefix 'aa'")
  expect_error(jobs(), "sas_breadth")
})

test_that("jobs() still reads a whole number written as a string", {
  testthat::local_mocked_bindings(
    read_jobs = function(...) {
      list(list(prefix = "aa", disposition = "scaffold",
                destination = "hvtiRtemplates", sas_breadth = "12"))
    }
  )

  expect_identical(jobs()$sas_breadth, 12L)
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
      # A real R package name starts with a letter and may then contain
      # letters, digits and dots (e.g. TemporalHazard, hvtiRutilities);
      # the issue number stays digits-only.
      expect_match(r$blocked_on, "^[A-Za-z][A-Za-z0-9.]*#[0-9]+$",
                   label = r$prefix)
    }
  }
})

test_that("an intake row's blocked_on is not a placeholder either", {
  # The disposition == "build" && status == "intake" carve-out above skips
  # the issue-reference check entirely, which leaves a hole: an intake row
  # is allowed to point at something other than a real issue (today, both
  # intake build rows and the intake retire row point at
  # hvtiRutilities#taxonomy, a deliberate non-issue marker), but it must
  # still point at *something meaningful*. A bare "TBD", "TODO", "FIXME",
  # "?" or "needs ..." would slip past both the literal placeholder-string
  # test above and the non-intake issue-reference test above it, so this
  # pins it down directly: non-null, non-empty, and not shaped like a
  # stand-in for "someone hasn't decided yet".
  raw <- read_jobs()
  placeholder_shaped <- "(?i)^\\s*(TBD|TODO|FIXME|\\?+|needs\\b.*)\\s*$"
  for (r in raw) {
    if (identical(r$status, "intake")) {
      b <- r$blocked_on
      expect_false(is.null(b), label = r$prefix)
      expect_false(is.na(b) || !nzchar(trimws(b)), label = r$prefix)
      expect_false(grepl(placeholder_shaped, b, perl = TRUE), label = r$prefix)
    }
  }
})

test_that("status/batch are null off-destination, except intake", {
  raw <- read_jobs()
  for (r in raw) {
    # A null destination is exempt from nulling, even though it is not
    # "hvtiRtemplates" either. Design section 6 rule 1 lets destination be
    # null, meaning nobody owns the row yet, and the sibling hvtiRtemplates
    # repository filters its own catalog scan with destination in (None,
    # "hvtiRtemplates"). A null-destination row therefore reaches that
    # package's check_schema() the same as a row destined there, and that
    # schema has no status for "none" -- it would reject the row outright.
    # So a null destination is this repository's business too, and keeps
    # status and batch, exactly like a row destined for hvtiRtemplates.
    off_destination <- !is.null(r$destination) &&
      !identical(r$destination, "hvtiRtemplates")
    if (off_destination) {
      expect_null(r$batch, label = r$prefix)
      if (!identical(r$status, "intake")) {
        expect_null(r$status, label = r$prefix)
      }
    }
  }
})

test_that("no row anywhere carries the retired out-of-scope status", {
  raw <- read_jobs()
  statuses <- vapply(raw, function(r) {
    if (is.null(r$status)) NA_character_ else r$status
  }, character(1))

  expect_false("out-of-scope" %in% statuses)
})

test_that("a row destined for hvtiRtemplates still has a status", {
  raw <- read_jobs()
  for (r in raw) {
    # Covers a null destination as well as "hvtiRtemplates": see the comment
    # on the nulling rule above for why the sibling repository treats a
    # null destination as in scope for this same status requirement.
    in_scope <- is.null(r$destination) ||
      identical(r$destination, "hvtiRtemplates")
    if (in_scope) {
      expect_false(is.null(r$status), label = r$prefix)
    }
  }
})

test_that("the triage rows' sas_breadth_jobs are second-field counts, pinned", {
  raw <- read_jobs()

  # dc-trends and dp-boxplot count distinct studies whose SECOND job-name
  # field is the qualifier, the unit every qualified row uses (the 2026-09-02
  # re-parse). #61 first wrote a token count over the whole name, 58 and 34,
  # and nothing failed. Pinning the values makes a slide back to that unit
  # fail here. A re-census that moves them should change these on purpose.
  breadth <- function(prefix, qualifier) {
    hit <- Filter(function(r) {
      identical(r$prefix, prefix) && identical(r$qualifier, qualifier)
    }, raw)
    expect_length(hit, 1L)
    hit[[1]]$sas_breadth_jobs
  }
  expect_equal(breadth("dc", "trends"), 43)
  expect_equal(breadth("dp", "boxplot"), 9)
})
