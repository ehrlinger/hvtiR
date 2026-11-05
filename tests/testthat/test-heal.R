test_that("compile and configure failures are compile causes", {
  out <- paste(
    "ERROR: compilation failed for package \u2018vctrs\u2019",
    "ERROR: configuration failed for package \u2018arrow\u2019",
    sep = "\n"
  )
  f <- classify_failures(out)
  expect_identical(f$package, c("vctrs", "arrow"))
  expect_identical(f$cause, c("compile", "compile"))
  expect_true(all(is.na(f$needs)))
})

test_that("a missing dependency names the package and what it needs", {
  out <- paste0(
    "ERROR: dependency \u2018tseries\u2019 is not available ",
    "for package \u2018forecast\u2019"
  )
  f <- classify_failures(out)
  expect_identical(f$package, "forecast")
  expect_identical(f$cause, "dependency")
  expect_identical(f$needs, "tseries")
})

test_that("R's plural dependency line gives every name, comma-joined", {
  out <- paste0(
    "ERROR: dependencies \u2018tseries\u2019, \u2018urca\u2019 are not ",
    "available for package \u2018forecast\u2019"
  )
  f <- classify_failures(out)
  expect_identical(f$package, "forecast")
  expect_identical(f$cause, "dependency")
  expect_identical(f$needs, "tseries,urca")
})

test_that("an ASCII-quoted dependency line parses", {
  f <- classify_failures(
    "ERROR: dependency 'xx' is not available for package 'yy'"
  )
  expect_identical(f$package, "yy")
  expect_identical(f$needs, "xx")
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
  out <- "ERROR: compilation failed for package \u2018bad name;rm\u2019"
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
  expect_match(expr, 'renv::install("tseries@0.10-58", project = ',
               fixed = TRUE)
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

test_that("an empty failures table plans nothing", {
  r <- decide(fails(character(), character(), character()))
  expect_length(r$move, 0L)
  expect_length(r$install, 0L)
  expect_identical(nrow(r$drop), 0L)
  expect_length(r$stop, 0L)
})

test_that("plural needs, none left out, are all installed", {
  r <- decide(fails("forecast", "dependency", "tseries,urca"))
  expect_identical(r$install, c("tseries", "urca"))
  expect_identical(nrow(r$drop), 0L)
})

test_that("plural needs with one left out drop the dependent, naming it", {
  r <- decide(fails("forecast", "dependency", "tseries,urca"),
              missing = "urca")
  expect_identical(r$drop$package, "forecast")
  expect_identical(r$drop$because, "urca")
  expect_identical(r$drop$reason, "needs urca, which was left out")
  expect_length(r$install, 0L)
})

test_that("a dependency row with no needs is an ordinary failure", {
  r <- decide(fails("forecast", "dependency", NA_character_))
  expect_identical(r$drop$package, "forecast")
  expect_identical(r$drop$reason, "failed to install")
})

local_children <- function(restores, recorded = "vctrs:0.7.3",
                           fail = character(), env = parent.frame()) {
  log <- new.env()
  log$calls <- character()
  log$exprs <- character()
  queue <- restores
  testthat::local_mocked_bindings(
    run_in_study = function(expr, root) {
      if (grepl("renv::restore(", expr, fixed = TRUE)) {
        log$calls <- c(log$calls, "restore")
        out <- queue[[1L]]
        queue <<- queue[-1L]
        ok <- identical(out, "ok")
        return(list(status = if (ok) 0L else 1L,
                    output = if (ok) "HVTIR_LIB=/l\n" else out))
      }
      kind <- if (grepl("renv::record(", expr, fixed = TRUE)) {
        "record"
      } else if (grepl("renv::install(", expr, fixed = TRUE)) {
        "install"
      } else {
        "drop"
      }
      log$calls <- c(log$calls, kind)
      log$exprs <- c(log$exprs, expr)
      if (kind %in% fail) {
        return(list(status = 1L, output = "Error: child failed"))
      }
      list(status = 0L, output = if (is.null(recorded)) {
        "nothing\n"
      } else {
        paste0("HVTIR_RECORDED=", recorded, "\n")
      })
    },
    save_setup_log = function(output, root = NULL) "renv/logs/x.log",
    .env = env
  )
  log
}
compile_out <- function(pkg) {
  paste0("ERROR: compilation failed for package \u2018", pkg, "\u2019")
}
dep_out <- function(dep, pkg) {
  paste0("ERROR: dependency \u2018", dep, "\u2019 is not available ",
         "for package \u2018", pkg, "\u2019")
}

test_that("a compile failure heals by moving the pin, then restores", {
  root <- local_lock()
  log <- local_children(list(compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls, c("restore", "record", "restore"))
  expect_identical(h$healed$package, "vctrs")
  expect_identical(h$healed$from, "0.7.2")
  expect_identical(h$healed$to, "0.7.3")
  expect_identical(nrow(h$missing), 0L)
  expect_true(file.exists(file.path(root, h$backup)))
})

test_that("a package that fails again after moving is left out at once", {
  root <- local_lock()
  log <- local_children(list(compile_out("vctrs"), compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls,
                   c("restore", "record", "restore", "drop", "restore"))
  expect_identical(h$missing$package, "vctrs")
})

test_that("a pin that did not change is moved but not counted as healed", {
  root <- local_lock()
  log <- local_children(
    list(compile_out("vctrs"), compile_out("vctrs"), "ok"),
    recorded = "vctrs:0.7.2"
  )
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(sum(log$calls == "record"), 1L)
  expect_identical(h$missing$package, "vctrs")
  expect_false("vctrs" %in% h$healed$package)
})

test_that("upgrade = FALSE leaves out an optional package without moving it", {
  root <- local_lock()
  log <- local_children(list(compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, FALSE, essential = "hvtiRutilities")
  expect_false("record" %in% log$calls)
  expect_identical(h$missing$package, "vctrs")
})

test_that("an essential failure stops with today's diagnosis", {
  root <- local_lock()
  local_children(list(compile_out("hvtiRutilities"),
                      compile_out("hvtiRutilities")))
  expect_error(
    heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
    "failed to compile"
  )
})

test_that("a missing dependency is installed at its locked version first", {
  root <- local_lock()
  log <- local_children(list(dep_out("vctrs", "forecast"), "ok"))
  heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls, c("restore", "install", "restore"))
  expect_match(log$exprs[1L], '"vctrs@0.7.2"', fixed = TRUE)
})

test_that("the same failed set twice ends healing", {
  root <- local_lock()
  dep <- dep_out("tseries", "forecast")
  log <- local_children(list(dep, dep, "ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls,
                   c("restore", "install", "restore", "drop", "restore"))
  expect_identical(h$missing$package, "forecast")
  expect_identical(h$missing$because, "tseries")
})

test_that("the round cap leaves out whatever still fails", {
  root <- local_lock()
  outs <- lapply(1:3, function(i) compile_out(paste0("p", i)))
  log <- local_children(c(outs, list("ok")))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities",
                    max_rounds = 3L)
  expect_identical(sum(log$calls == "restore"), 4L)
  expect_true("p3" %in% h$missing$package)
})

test_that("past the cap, the last failing optional package is left out", {
  root <- local_lock()
  # p1 fails twice: moved once, then stuck by repetition. p2, p3 and p4
  # each differ, so only the cap (max_rounds = 3) makes round 3 stuck.
  outs <- list(compile_out("vctrs"), compile_out("p2"), compile_out("p3"),
               compile_out("p4"), "ok")
  log <- local_children(outs)
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities",
                    max_rounds = 3L)
  expect_identical(sum(log$calls == "restore"), 5L)
  expect_identical(sum(log$calls == "record"), 1L)
  expect_true("p4" %in% h$missing$package)
  expect_true("p3" %in% h$missing$package)
})

test_that("past the cap, a drop exposing a dependent leaves it out too", {
  root <- local_lock()
  outs <- list(compile_out("pa"), dep_out("pa", "pb"), "ok")
  log <- local_children(outs)
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities",
                    max_rounds = 1L)
  expect_identical(h$missing$package, c("pa", "pb"))
  expect_identical(h$missing$because, c(NA, "pa"))
  expect_identical(sum(log$calls == "drop"), 2L)
})

test_that("past the cap, a round that drops nothing new aborts", {
  root <- local_lock()
  outs <- list(compile_out("pa"), compile_out("pa"), compile_out("pa"))
  local_children(outs)
  expect_error(
    heal_restore(root, NULL, TRUE, essential = "hvtiRutilities",
                 max_rounds = 1L),
    "compilation failed"
  )
})

test_that("a first round that only drops has a backup equal to the lock", {
  root <- local_lock()
  original <- readLines(file.path(root, "renv.lock"))
  local_children(list(compile_out("vctrs"), "ok"))
  h <- heal_restore(root, NULL, FALSE, essential = "hvtiRutilities")
  expect_true(file.exists(file.path(root, h$backup)))
  expect_identical(readLines(file.path(root, h$backup)), original)
})

test_that("an install child failing after a record round names the backup", {
  root <- local_lock()
  local_children(list(compile_out("vctrs"), dep_out("tseries", "forecast"),
                      "ok"), fail = "install")
  expect_error(
    heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
    "Healing changed renv.lock"
  )
})

test_that("an abort after a lock change keeps the original message", {
  root <- local_lock()
  local_children(list(compile_out("vctrs"), compile_out("hvtiRutilities"),
                      compile_out("hvtiRutilities")))
  err <- expect_error(
    heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
    "failed to compile"
  )
  expect_match(conditionMessage(err), "Healing changed renv.lock")
})

test_that("a missing recorded marker aborts, not a subscript error", {
  root <- local_lock()
  local_children(list(compile_out("vctrs"), "ok"), recorded = NULL)
  err <- expect_error(
    heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
    "did not report the recorded versions"
  )
  expect_no_match(conditionMessage(err), "subscript out of bounds")
  expect_match(conditionMessage(err), "Healing changed renv.lock")
})

test_that("a pin with no prior version is moved but not counted as healed", {
  root <- local_lock()
  local_children(list(compile_out("newpkg"), "ok"), recorded = "newpkg:1.0")
  testthat::local_mocked_bindings(
    record_specs = function(pkgs, root) stats::setNames("newpkg", "newpkg")
  )
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(nrow(h$healed), 0L)
})

test_that("an unrecognised failure stops with today's diagnosis", {
  root <- local_lock()
  local_children(list("Error: could not resolve host"))
  expect_error(heal_restore(root, NULL, TRUE, essential = "hvtiRutilities"),
               "Installing the study's packages failed")
})

test_that("a clean first restore heals nothing and backs nothing up", {
  root <- local_lock()
  log <- local_children(list("ok"))
  h <- heal_restore(root, NULL, TRUE, essential = "hvtiRutilities")
  expect_identical(log$calls, "restore")
  expect_true(is.na(h$backup))
})

test_that("save_setup_log keeps logs in the study when given its root", {
  root <- local_lock()
  rel <- save_setup_log("line one", root)
  expect_match(rel, "^renv/logs/setup-[0-9]{8}-[0-9]{6}-.*\\.log$")
  expect_identical(readLines(file.path(root, rel), warn = FALSE), "line one")
  expect_true(startsWith(save_setup_log("x"), tempdir()))
})

test_that("the setup record round-trips healed, missing and cleanup", {
  root <- local_lock()
  healed <- data.frame(package = "vctrs", from = "0.7.2", to = "0.7.3",
                       round = 1L, stringsAsFactors = FALSE)
  missing <- data.frame(package = "forecast", reason = "needs tseries",
                        because = "tseries", log = "renv/logs/x.log",
                        stringsAsFactors = FALSE)
  write_setup_record(root, healed, missing, "renv/renv.lock.before-setup-1",
                     list(status = "done", left = "a/tp.x"))
  rec <- read_setup_record(root)
  expect_identical(rec$run$LockBackup, "renv/renv.lock.before-setup-1")
  expect_identical(rec$healed$Package, "vctrs")
  expect_identical(rec$healed$To, "0.7.3")
  expect_identical(rec$missing$Package, "forecast")
  expect_identical(rec$missing$Because, "tseries")
  expect_identical(rec$cleanup$Status, "done")
})

test_that("no record reads as NULL, and an empty run writes only the run", {
  root <- local_lock()
  expect_null(read_setup_record(root))
  empty <- data.frame()
  write_setup_record(root, empty, empty, NA_character_, NULL)
  rec <- read_setup_record(root)
  expect_identical(nrow(rec$missing), 0L)
  expect_identical(rec$cleanup$Status, "off")
})

test_that("an older hvtiRutilities cleanup shape still records", {
  root <- local_lock()
  write_setup_record(root, data.frame(), data.frame(), NA_character_,
                     list(deleted = "a", removed_dirs = character()))
  expect_identical(read_setup_record(root)$cleanup$Status, "done")
})

test_that("two logs written in the same second do not overwrite each other", {
  root <- local_lock()
  a <- save_setup_log("one", root)
  b <- save_setup_log("two", root)
  expect_false(identical(a, b))
  expect_identical(readLines(file.path(root, a), warn = FALSE), "one")
  expect_false(identical(save_setup_log("x"), save_setup_log("x")))
  expect_match(basename(save_setup_log("x")), "^hvtiR-setup-")
})

test_that("a failure reason cannot forge or split a record", {
  root <- local_lock()
  for (reason in c("x\rType: run\r\rType: run", "a\nb")) {
    missing <- data.frame(package = "p", reason = reason, because = "q",
                          log = "l", stringsAsFactors = FALSE)
    write_setup_record(root, data.frame(), missing, NA_character_, NULL)
    rec <- read_setup_record(root)
    expect_identical(nrow(rec$run), 1L)
    expect_identical(nrow(rec$missing), 1L)
    expect_identical(rec$missing$Package, "p")
  }
})

test_that("a vector value is written as a display list", {
  root <- local_lock()
  write_setup_record(root, data.frame(), data.frame(), NA_character_,
                     list(status = "done", left = c("a", NA, "", "b")))
  expect_identical(read_setup_record(root)$cleanup$Left, "a; b")
  write_setup_record(root, data.frame(), data.frame(), NA_character_,
                     list(status = "done", left = c(NA, "")))
  expect_null(read_setup_record(root)$cleanup$Left)
})
