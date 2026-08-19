test_that("install_members passes every spec to pak in a single call", {
  calls <- list()
  local_mocked_bindings(
    pak_install = function(specs) {
      calls[[length(calls) + 1L]] <<- specs
      invisible(specs)
    }
  )

  install_members(c("hvtiRutilities", "TemporalHazard"))

  expect_length(calls, 1L)
  expect_identical(
    calls[[1]],
    c("ehrlinger/hvtiRutilities", "ehrlinger/temporal_hazard")
  )
})

test_that("install_members refuses to overwrite a loaded member", {
  local_mocked_bindings(
    pak_install = function(specs) stop("must not install"),
    check_loaded = function(targets, loaded = loadedNamespaces()) "hvtiPlotR"
  )

  expect_error(
    install_members(c("hvtiPlotR", "hvtiRtables")),
    "already loaded"
  )
})

test_that("force overrides the loaded-namespace guard", {
  local_mocked_bindings(
    pak_install = function(specs) invisible(specs),
    check_loaded = function(targets, loaded = loadedNamespaces()) "hvtiPlotR"
  )

  expect_no_error(install_members("hvtiPlotR", force = TRUE))
})

test_that("install_members does nothing when there is nothing to install", {
  local_mocked_bindings(
    pak_install = function(specs) stop("must not install")
  )

  expect_message(install_members(character(0)), "up to date")
})

test_that("hvtiverse_install targets every member", {
  captured <- NULL
  local_mocked_bindings(
    pak_install = function(specs) {
      captured <<- specs
      invisible(specs)
    },
    check_loaded = function(targets, loaded = loadedNamespaces()) character(0)
  )

  hvtiverse_install()

  expect_identical(captured, hvtiverse_members()$repo)
})

test_that("hvtiverse_update targets only missing and stale members", {
  captured <- NULL
  local_mocked_bindings(
    installed_version = function(pkg) {
      if (pkg == "hvtiPlotR") return(NA_character_)
      if (pkg == "hvtiRtables") return("0.9.0")
      "1.0.0"
    },
    remote_version = function(repo, ref = "main") "1.0.0",
    pak_install = function(specs) {
      captured <<- specs
      invisible(specs)
    },
    check_loaded = function(targets, loaded = loadedNamespaces()) character(0)
  )

  hvtiverse_update()

  expect_setequal(
    captured,
    c("ehrlinger/hvtiPlotR", "ehrlinger/hvtiRtables")
  )
})

test_that("hvtiverse_update installs nothing when everything is current", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    pak_install = function(specs) stop("must not install")
  )

  expect_message(hvtiverse_update(), "up to date")
})

test_that("hvtiverse_update does not claim members are current when GitHub is unreachable", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") NA_character_,
    pak_install = function(specs) stop("must not install")
  )

  msgs <- character(0)
  withCallingHandlers(
    suppressWarnings(hvtiverse_update()),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  expect_true(any(grepl("could not be checked", msgs)))
  expect_false(any(grepl("up to date", msgs)))
})
