test_that("status returns one row per member with the right columns", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  st <- status()

  expect_s3_class(st, "hvtiR_status")
  expect_s3_class(st, "data.frame")
  expect_identical(
    names(st),
    c("package", "repo", "installed", "latest", "status")
  )
  expect_identical(nrow(st), nrow(members()))
  expect_true(all(st$status == "ok"))
})

test_that("status marks stale and missing members", {
  local_mocked_bindings(
    installed_version = function(pkg) {
      if (pkg == "hvtiPlotR") return(NA_character_)
      if (pkg == "hvtiRtables") return("0.9.0")
      "1.0.0"
    },
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  st <- status()

  expect_identical(st$status[st$package == "hvtiPlotR"], "missing")
  expect_identical(st$status[st$package == "hvtiRtables"], "stale")
  expect_identical(st$status[st$package == "hvtiRutilities"], "ok")
})

test_that("status marks a same-version older GitHub install stale", {
  old_sha <- "1111111111111111111111111111111111111111"
  current_sha <- "2222222222222222222222222222222222222222"
  checked <- character(0)
  local_mocked_bindings(
    installed_version = function(pkg) {
      if (pkg == "hvtiRtables") {
        return(structure("1.0.0", remote_sha = old_sha))
      }
      "1.0.0"
    },
    remote_version = function(repo, ref = "main") "1.0.0",
    remote_commit = function(repo, ref = "main") {
      checked <<- c(checked, repo)
      current_sha
    }
  )

  st <- status()

  expect_identical(
    names(st),
    c("package", "repo", "installed", "latest", "status")
  )
  expect_identical(st$status[st$package == "hvtiRtables"], "stale")
  expect_true(all(st$status[st$package != "hvtiRtables"] == "ok"))
  expect_identical(checked, "ehrlinger/hvtiRtables")
})

test_that("status reports a failed same-version commit check as unknown", {
  sha <- "1111111111111111111111111111111111111111"
  local_mocked_bindings(
    installed_version = function(pkg) {
      if (pkg == "hvtiRtables") {
        return(structure("1.0.0", remote_sha = sha))
      }
      "1.0.0"
    },
    remote_version = function(repo, ref = "main") "1.0.0",
    remote_commit = function(repo, ref = "main") {
      structure(NA_character_, remote_error = "feed timed out")
    }
  )

  st <- NULL
  expect_warning(st <- status(), "latest version or commit")
  failures <- attr(st, "remote_errors")

  expect_identical(st$status[st$package == "hvtiRtables"], "unknown")
  expect_identical(failures$package, "hvtiRtables")
  expect_identical(failures$error, "feed timed out")
})

test_that("status warns once, not per member, when GitHub is unreachable", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") NA_character_
  )

  seen <- character(0)
  withCallingHandlers(
    st <- status(),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_length(seen, 1L)
  expect_match(seen, "Could not determine the latest version")
  expect_true(all(st$status == "unknown"))
})

test_that("status warns when nothing is installed and GitHub is unreachable", {
  local_mocked_bindings(
    installed_version = function(pkg) NA_character_,
    remote_version = function(repo, ref = "main") NA_character_
  )

  seen <- character(0)
  withCallingHandlers(
    st <- status(),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_length(seen, 1L)
  expect_match(seen, "Could not determine the latest version")
  expect_true(all(st$status == "missing"))
})

test_that("status retains per-member remote failure details", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      if (repo == "ehrlinger/hvtiPlotR") {
        return(structure(
          NA_character_,
          remote_error = paste("could not fetch", repo)
        ))
      }
      "1.0.0"
    }
  )

  st <- suppressWarnings(status())
  failures <- attr(st, "remote_errors")

  expect_s3_class(failures, "data.frame")
  expect_identical(names(failures), c("package", "repo", "error"))
  expect_identical(nrow(failures), 1L)
  expect_identical(failures$package, "hvtiPlotR")
  expect_match(failures$error, failures$repo, fixed = TRUE)
})

test_that("status skips the network entirely when remote is FALSE", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      stop("remote_version must not be called when remote = FALSE")
    }
  )

  st <- expect_no_warning(status(remote = FALSE))

  expect_true(all(is.na(st$latest)))
  expect_true(all(st$status == "ok-local"))
})

test_that("printing a status object returns it invisibly", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  st <- status()

  expect_invisible(print(st))
  expect_output(print(st), "hvtiRutilities")
})

make_status <- function(status) {
  out <- data.frame(
    package = "hvtiRutilities",
    repo = "ehrlinger/hvtiRutilities",
    installed = "1.0.0",
    latest = if (status %in% c("unknown", "ok-local")) {
      NA_character_
    } else {
      "1.0.0"
    },
    status = status,
    stringsAsFactors = FALSE
  )
  class(out) <- c("hvtiR_status", "data.frame")
  out
}

test_that("the footer reports members needing updates when any are stale", {
  expect_output(print(make_status("stale")), "need.*updating")
})

test_that("the footer reports unchecked members when any are unknown", {
  expect_output(
    print(make_status("unknown")),
    "could not be checked against GitHub"
  )
})

test_that("the footer discloses installed-only versions when all are local", {
  expect_output(print(make_status("ok-local")), "Remote was not consulted")
})

test_that("the footer claims up to date only when everything is genuinely ok", {
  expect_output(print(make_status("ok")), "Everything is up to date")
})

test_that("printing a status object reports hvtiR's own version", {
  # hvtiR is not a member, so the table below the header can never carry it.
  # Both issue templates ask users to paste this output, and the first
  # question about any report is which hvtiR produced it.
  st <- make_status("ok")

  expect_output(print(st),
                paste0("hvtiR ", as.character(utils::packageVersion("hvtiR"))))
})
