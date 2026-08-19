test_that("hvtiverse_status returns one row per member with the right columns", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  st <- hvtiverse_status()

  expect_s3_class(st, "hvtiverse_status")
  expect_s3_class(st, "data.frame")
  expect_identical(
    names(st),
    c("package", "repo", "installed", "latest", "status")
  )
  expect_identical(nrow(st), nrow(hvtiverse_members()))
  expect_true(all(st$status == "ok"))
})

test_that("hvtiverse_status marks stale and missing members", {
  local_mocked_bindings(
    installed_version = function(pkg) {
      if (pkg == "hvtiPlotR") return(NA_character_)
      if (pkg == "hvtiRtables") return("0.9.0")
      "1.0.0"
    },
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  st <- hvtiverse_status()

  expect_identical(st$status[st$package == "hvtiPlotR"], "missing")
  expect_identical(st$status[st$package == "hvtiRtables"], "stale")
  expect_identical(st$status[st$package == "hvtiRutilities"], "ok")
})

test_that("hvtiverse_status warns once, not per member, when GitHub is unreachable", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") NA_character_
  )

  seen <- character(0)
  withCallingHandlers(
    st <- hvtiverse_status(),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_length(seen, 1L)
  expect_match(seen, "Could not determine the latest version")
  expect_true(all(st$status == "unknown"))
})

test_that("hvtiverse_status warns when nothing is installed and GitHub is unreachable", {
  local_mocked_bindings(
    installed_version = function(pkg) NA_character_,
    remote_version = function(repo, ref = "main") NA_character_
  )

  seen <- character(0)
  withCallingHandlers(
    st <- hvtiverse_status(),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_length(seen, 1L)
  expect_match(seen, "Could not determine the latest version")
  expect_true(all(st$status == "missing"))
})

test_that("hvtiverse_status skips the network entirely when remote is FALSE", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      stop("remote_version must not be called when remote = FALSE")
    }
  )

  st <- expect_no_warning(hvtiverse_status(remote = FALSE))

  expect_true(all(is.na(st$latest)))
  expect_true(all(st$status == "ok-local"))
})

test_that("printing a status object returns it invisibly", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0"
  )

  st <- hvtiverse_status()

  expect_invisible(print(st))
  expect_output(print(st), "hvtiRutilities")
})

make_status <- function(status) {
  out <- data.frame(
    package = "hvtiRutilities",
    repo = "ehrlinger/hvtiRutilities",
    installed = "1.0.0",
    latest = if (status %in% c("unknown", "ok-local")) NA_character_ else "1.0.0",
    status = status,
    stringsAsFactors = FALSE
  )
  class(out) <- c("hvtiverse_status", "data.frame")
  out
}

test_that("the footer reports members needing updates when any are stale", {
  expect_output(print(make_status("stale")), "need.*updating")
})

test_that("the footer reports unchecked members when any are unknown", {
  expect_output(print(make_status("unknown")), "could not be checked against GitHub")
})

test_that("the footer discloses installed-only versions when all are ok-local", {
  expect_output(print(make_status("ok-local")), "Remote was not consulted")
})

test_that("the footer claims up to date only when everything is genuinely ok", {
  expect_output(print(make_status("ok")), "Everything is up to date")
})
