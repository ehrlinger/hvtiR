test_that("remote_version reads the Version field", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main", ...) {
      read.dcf(test_path("fixtures", "DESCRIPTION-simple"))
    }
  )

  expect_identical(remote_version("ehrlinger/hvtiRutilities"), "1.0.10")
})

test_that("remote_version handles DESCRIPTION continuation lines", {
  # Version is wrapped onto a continuation line: grep("^Version:") would
  # return an empty value here, read.dcf resolves it to 2.7.6.
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main", ...) {
      read.dcf(test_path("fixtures", "DESCRIPTION-continuation"))
    }
  )

  expect_identical(remote_version("ehrlinger/hvtiPlotR"), "2.7.6")
})

test_that("remote_version returns NA when the fetch fails", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main", ...) NULL
  )

  expect_identical(remote_version("ehrlinger/nope"), NA_character_)
})

test_that("remote_version returns NA when DESCRIPTION has no Version field", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main", ...) {
      read.dcf(textConnection("Package: broken\nTitle: No Version Here\n"))
    }
  )

  expect_true(is.na(remote_version("ehrlinger/broken")))
})

test_that("remote requests use the bounded timeout", {
  old <- getOption("timeout")
  on.exit(options(timeout = old), add = TRUE)
  options(timeout = 60)

  observed <- with_remote_timeout(5, getOption("timeout"))

  expect_identical(observed, 5)
})

test_that("fetch_description reads under the bounded timeout", {
  old <- getOption("timeout")
  on.exit(options(timeout = old), add = TRUE)
  options(timeout = 60)

  observed <- NULL
  fixture <- base::read.dcf(
    test_path("fixtures", "DESCRIPTION-simple")
  )
  local_mocked_bindings(
    url = function(...) "mock connection",
    close = function(con) NULL,
    read.dcf = function(con) {
      observed <<- getOption("timeout")
      fixture
    },
    .package = "base"
  )

  dcf <- fetch_description("ehrlinger/hvtiRutilities", timeout = 5)

  expect_identical(observed, 5)
  expect_identical(unname(dcf[1L, "Version"]), "1.0.10")
  expect_identical(getOption("timeout"), 60)
})

test_that("fetch_description does not retry by default", {
  requests <- 0L
  local_mocked_bindings(
    url = function(...) {
      requests <<- requests + 1L
      stop("connection timed out")
    },
    close = function(con) NULL,
    .package = "base"
  )

  expect_null(fetch_description("ehrlinger/unreachable"))
  expect_identical(requests, 1L)
})

test_that("fetch_description retries until a request succeeds", {
  requests <- 0L
  fixture <- base::read.dcf(test_path("fixtures", "DESCRIPTION-simple"))
  local_mocked_bindings(
    url = function(...) {
      requests <<- requests + 1L
      if (requests < 3L) stop("connection timed out")
      "mock connection"
    },
    close = function(con) NULL,
    read.dcf = function(con) fixture,
    Sys.sleep = function(...) NULL,
    .package = "base"
  )

  dcf <- fetch_description("ehrlinger/hvtiRutilities", attempts = 3L)

  expect_identical(requests, 3L)
  expect_identical(unname(dcf[1L, "Version"]), "1.0.10")
})

test_that("fetch_description still fails once its attempts are spent", {
  # The gate that keeps a renamed repository failing: retrying must delay a
  # persistent 404, never absorb it.
  requests <- 0L
  waits <- numeric(0)
  local_mocked_bindings(
    url = function(...) {
      requests <<- requests + 1L
      stop("cannot open URL")
    },
    close = function(con) NULL,
    Sys.sleep = function(time) waits <<- c(waits, time),
    .package = "base"
  )

  result <- fetch_description(
    "ehrlinger/renamed",
    on_error = identity,
    attempts = 3L
  )

  expect_identical(requests, 3L)
  # Backs off between attempts, and does not wait after the last one.
  expect_identical(waits, c(1, 2))
  expect_s3_class(result, "condition")
  expect_match(conditionMessage(result), "cannot open URL")
})

test_that("remote timeout is restored after an error", {
  old <- getOption("timeout")
  on.exit(options(timeout = old), add = TRUE)
  options(timeout = 60)

  expect_error(with_remote_timeout(5, stop("request failed")))

  expect_identical(getOption("timeout"), 60)
})

test_that("remote_version retains the fetch failure reason", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main", on_error = NULL) {
      on_error(simpleError("connection timed out"))
    }
  )

  version <- remote_version("ehrlinger/unreachable")

  expect_true(is.na(version))
  expect_identical(attr(version, "remote_error"), "connection timed out")
})

test_that("remote_version explains a missing Version field", {
  local_mocked_bindings(
    fetch_description = function(repo, ref = "main", on_error = NULL) {
      read.dcf(textConnection("Package: broken\nTitle: No Version Here\n"))
    }
  )

  version <- remote_version("ehrlinger/broken")

  expect_true(is.na(version))
  expect_match(attr(version, "remote_error"), "no Version field")
})

test_that("remote_commit reads the first commit from the branch feed", {
  sha <- "1234567890abcdef1234567890abcdef12345678"
  feed <- c(
    "<feed>",
    "  <entry>",
    paste0("    <id>tag:github.com,2008:Grit::Commit/", sha, "</id>"),
    "  </entry>",
    "</feed>"
  )
  local_mocked_bindings(
    fetch_commit_feed = function(repo, ref = "main", ...) feed
  )

  expect_identical(remote_commit("ehrlinger/hvtiRutilities"), sha)
})

test_that("remote_commit retains a feed failure reason", {
  local_mocked_bindings(
    fetch_commit_feed = function(repo, ref = "main", on_error = NULL, ...) {
      on_error(simpleError("feed timed out"))
    }
  )

  commit <- remote_commit("ehrlinger/unreachable")

  expect_true(is.na(commit))
  expect_identical(attr(commit, "remote_error"), "feed timed out")
})

test_that("remote_commit rejects a feed without a commit id", {
  local_mocked_bindings(
    fetch_commit_feed = function(repo, ref = "main", ...) {
      c("<feed>", "<title>No commits here</title>", "</feed>")
    }
  )

  commit <- remote_commit("ehrlinger/empty")

  expect_true(is.na(commit))
  expect_match(attr(commit, "remote_error"), "no commit SHA")
})

test_that("a non-positive attempts count is rejected rather than crashing", {
  # With attempts = 0 the retry loop never runs, so `result` is never bound.
  # The default on_error ignores its argument and R's laziness hides that, but
  # remote_version() passes on_error = identity, which forces it -- the caller
  # would see "object 'result' not found" instead of a usable message.
  expect_error(
    fetch_description("ehrlinger/hvtiRutilities", attempts = 0L),
    "attempts"
  )
  expect_error(
    fetch_description("ehrlinger/hvtiRutilities", attempts = 0L,
                      on_error = identity),
    "attempts"
  )
})

test_that("a malformed attempts count is rejected with a message naming it", {
  for (bad in list(NA_integer_, -1L, c(1L, 2L), "3")) {
    expect_error(
      fetch_description("ehrlinger/hvtiRutilities", attempts = bad),
      "attempts"
    )
  }
})
