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

local_lock <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  writeLines(c(
    "{", '  "R": {"Version": "4.5.1"},', '  "Packages": {',
    '    "vctrs": {"Package": "vctrs", "Version": "0.7.2",',
    '      "Source": "Repository", "Repository": "CRAN"},',
    '    "hvtiRutilities": {"Package": "hvtiRutilities", "Version": "1.5.6",',
    '      "Source": "GitHub", "RemoteUsername": "ehrlinger",',
    '      "RemoteRepo": "hvtiRutilities"}',
    "  }", "}"
  ), file.path(root, "renv.lock"))
  dir.create(file.path(root, "renv"))
  root
}

test_that("locked_versions reads each record's version", {
  root <- local_lock()
  expect_identical(
    locked_versions(c("vctrs", "hvtiRutilities", "absent"), root),
    c(vctrs = "0.7.2", hvtiRutilities = "1.5.6", absent = NA)
  )
})

test_that("record_specs is unchanged by the refactor", {
  root <- local_lock()
  expect_identical(
    record_specs(c("vctrs", "hvtiRutilities"), root),
    c(vctrs = "vctrs", hvtiRutilities = "ehrlinger/hvtiRutilities")
  )
})

test_that("record_expr records against the study's repositories", {
  root <- local_lock()
  expr <- record_expr(root, c(vctrs = "vctrs"), c(PPM = "https://ppm/x"))
  expect_match(expr, "options(repos = hvtir_repos)", fixed = TRUE)
  expect_match(expr, 'renv::record("vctrs", project = ', fixed = TRUE)
  expect_match(expr, "HVTIR_RECORDED=", fixed = TRUE)
  expect_true(startsWith(expr, pak_off()))
})

test_that("install_expr installs into the project with no prompt", {
  root <- local_lock()
  expr <- install_expr(root, "tseries@0.10-58")
  expect_match(expr, 'renv::install("tseries@0.10-58", project = ', fixed = TRUE)
  expect_match(expr, "prompt = FALSE", fixed = TRUE)
})

test_that("drop_expr removes records from the lock", {
  root <- local_lock()
  expect_match(drop_expr(root, "vctrs"), 'lf$Packages["vctrs"] <- NULL',
               fixed = TRUE)
})

test_that("drop_expr really removes the record from a lockfile", {
  skip_on_cran()
  skip_if_not_installed("renv")
  root <- local_lock()
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c("--vanilla", "-e", shQuote(drop_expr(root, "vctrs"))))
  expect_identical(status, 0L)
  kept <- names(renv::lockfile_read(file.path(root, "renv.lock"))$Packages)
  expect_identical(kept, "hvtiRutilities")
})

test_that("backup_lock copies the lock once under renv/", {
  root <- local_lock()
  rel <- backup_lock(root, stamp = "20261105-161000")
  expect_identical(rel, "renv/renv.lock.before-setup-20261105-161000")
  expect_identical(readLines(file.path(root, rel)),
                   readLines(file.path(root, "renv.lock")))
  expect_true(is.na(backup_lock(withr::local_tempdir())))
})
