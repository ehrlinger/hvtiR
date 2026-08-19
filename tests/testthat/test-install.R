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

test_that("hvtiverse_update reports unchecked members alongside a real install", {
  captured <- NULL
  local_mocked_bindings(
    installed_version = function(pkg) {
      if (pkg == "hvtiRtables") return("0.9.0")
      "1.0.0"
    },
    remote_version = function(repo, ref = "main") {
      if (repo %in% c("ehrlinger/hvtiPlotR", "ehrlinger/hvtiRlifetables")) {
        return(NA_character_)
      }
      "1.0.0"
    },
    pak_install = function(specs) {
      captured <<- specs
      invisible(specs)
    },
    check_loaded = function(targets, loaded = loadedNamespaces()) character(0)
  )

  msgs <- character(0)
  withCallingHandlers(
    suppressWarnings(hvtiverse_update()),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  # hvtiRtables is stale and gets installed...
  expect_identical(captured, "ehrlinger/hvtiRtables")
  # ...and the two members GitHub could not be reached for are still
  # reported, not silently dropped just because there was work to do.
  expect_true(any(grepl("2 members could not be checked", msgs)))
})

test_that("expand_targets pulls in an in-family dependency", {
  expect_identical(
    expand_targets("hvtiRlifetables"),
    c("hvtiRlifetables", "TemporalHazard")
  )
  expect_identical(
    expand_targets("hvtiRdatasets"),
    c("hvtiRutilities", "hvtiRdatasets")
  )
})

test_that("expand_targets leaves a target set with no in-family deps alone", {
  expect_identical(expand_targets("hvtiPlotR"), "hvtiPlotR")
  expect_identical(expand_targets(character(0)), character(0))
})

test_that("expand_targets does not duplicate a dependency already targeted", {
  out <- expand_targets(c("hvtiRlifetables", "TemporalHazard"))
  expect_identical(anyDuplicated(out), 0L)
  expect_setequal(out, c("hvtiRlifetables", "TemporalHazard"))
})

test_that("expand_targets returns registry order regardless of input order", {
  expect_identical(
    expand_targets(c("ggRandomForests", "hvtiRutilities")),
    c("hvtiRutilities", "ggRandomForests")
  )
})

test_that("hvtiverse_update sends a stale member's in-family dependency too", {
  captured <- NULL
  local_mocked_bindings(
    installed_version = function(pkg) if (pkg == "hvtiRlifetables") "0.0.1" else "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    pak_install = function(specs) {
      captured <<- specs
      invisible(specs)
    },
    check_loaded = function(targets, loaded = loadedNamespaces()) character(0)
  )

  hvtiverse_update()

  expect_true("ehrlinger/temporal_hazard" %in% captured)
  expect_true("ehrlinger/hvtiRlifetables" %in% captured)
})
