# Rule 3 of the job catalog design: every replaced_by entry must name a real
# export of a real family package.
#
# This test needs the destination packages installed. A plain skip would be
# invisible: R CMD check reports a skip as success, so the family could drift
# for months under a green check. That failure has already happened once in
# hvtiRlifetables, where a regression guard read SKIP 5 | PASS 474 and had
# never run on Windows. So the uninstalled packages are NAMED in the output,
# and on CI a missing package is a failure rather than a skip.

.jobs_refs <- function() {
  raw <- read_jobs()
  unique(unlist(lapply(raw, function(r) unlist(r$replaced_by))))
}

# Reporting the unvalidated packages is its own function so that the loud-skip
# behaviour can be tested directly, with a package name that is certainly not
# installed, rather than by uninstalling something from the developer's real
# library and hoping the reinstall runs.
.jobs_report_absent <- function(absent,
                                ci = identical(Sys.getenv("CI"), "true")) {
  if (!length(absent)) {
    return(invisible(character(0)))
  }
  msg <- paste("UNVALIDATED routings, package not installed:",
               paste(absent, collapse = ", "))
  if (ci) stop(msg, call. = FALSE) else message(msg)
  invisible(absent)
}

test_that("an absent destination is named, and is fatal on CI", {
  expect_identical(.jobs_report_absent(character(0)), character(0))
  expect_message(
    .jobs_report_absent("notAPackageThatExists", ci = FALSE),
    "UNVALIDATED routings, package not installed: notAPackageThatExists"
  )
  expect_error(.jobs_report_absent("notAPackageThatExists", ci = TRUE),
               "UNVALIDATED routings")
})

test_that("every replaced_by entry is package::function", {
  refs <- .jobs_refs()

  expect_gt(length(refs), 0L)
  expect_true(all(grepl("^[A-Za-z][A-Za-z0-9.]*::[A-Za-z._][A-Za-z0-9._]*$",
                        refs)),
              info = paste(refs[!grepl("::", refs)], collapse = ", "))
})

test_that("every replaced_by package is a family member", {
  pkgs <- unique(sub("::.*$", "", .jobs_refs()))

  expect_true(all(pkgs %in% members()$package),
              info = paste(setdiff(pkgs, members()$package), collapse = ", "))
})

test_that("every replaced_by function is exported by its package", {
  refs <- .jobs_refs()
  pkgs <- unique(sub("::.*$", "", refs))

  have <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  .jobs_report_absent(pkgs[!have])

  for (p in pkgs[have]) {
    exported <- getNamespaceExports(p)
    want <- sub("^.*::", "", refs[sub("::.*$", "", refs) == p])
    expect_true(all(want %in% exported),
                info = paste0(p, ": ", paste(setdiff(want, exported),
                                             collapse = ", ")))
  }
})
