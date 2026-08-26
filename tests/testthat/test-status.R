test_that("classify_status compares installed against latest", {
  expect_identical(classify_status("1.0.0", "1.0.0"), "ok")
  expect_identical(classify_status("1.0.0", "1.1.0"), "stale")
  expect_identical(classify_status("1.1.0", "1.0.0"), "ahead")
})

test_that("classify_status detects an older commit at the same version", {
  installed <- structure(
    "1.0.0",
    remote_sha = "1111111111111111111111111111111111111111"
  )
  latest <- structure(
    "1.0.0",
    remote_sha = "2222222222222222222222222222222222222222",
    commit_checked = TRUE
  )

  expect_identical(classify_status(installed, latest), "stale")
})

test_that("classify_status accepts the current commit at the same version", {
  sha <- "1111111111111111111111111111111111111111"
  installed <- structure("1.0.0", remote_sha = sha)
  latest <- structure(
    "1.0.0",
    remote_sha = sha,
    commit_checked = TRUE
  )

  expect_identical(classify_status(installed, latest), "ok")
})

test_that("classify_status falls back when install provenance is absent", {
  latest <- structure(
    "1.0.0",
    remote_sha = "2222222222222222222222222222222222222222",
    commit_checked = TRUE
  )

  expect_identical(classify_status("1.0.0", latest), "ok")
})

test_that("classify_status compares version segments numerically", {
  # string comparison would call 1.0.10 older than 1.0.9
  expect_identical(classify_status("1.0.10", "1.0.9"), "ahead")
  expect_identical(classify_status("1.0.9", "1.0.10"), "stale")
})

test_that("classify_status reports a package that is not installed", {
  expect_identical(classify_status(NA_character_, "1.0.0"), "missing")
  expect_identical(classify_status(NA_character_, NA_character_), "missing")
})

test_that("classify_status reports an unreachable remote", {
  expect_identical(classify_status("1.0.0", NA_character_), "unknown")
})

test_that("classify_status reports ok-local when the remote was not consulted", {
  expect_identical(
    classify_status("1.0.0", NA_character_, remote = FALSE),
    "ok-local"
  )
})

test_that("a package that is not installed stays missing when remote is FALSE", {
  expect_identical(
    classify_status(NA_character_, NA_character_, remote = FALSE),
    "missing"
  )
})

test_that("installed_version retains pak's GitHub commit", {
  sha <- "1234567890abcdef1234567890abcdef12345678"
  local_mocked_bindings(
    find.package = function(pkg, quiet = TRUE) "/mock/library/member",
    read.dcf = function(file, fields = NULL) {
      matrix(
        c("1.2.3", "github", sha),
        nrow = 1L,
        dimnames = list(NULL, c("Version", "RemoteType", "RemoteSha"))
      )
    },
    .package = "base"
  )

  installed <- installed_version("member")

  expect_identical(as.character(installed), "1.2.3")
  expect_identical(attr(installed, "remote_sha"), sha)
})

test_that("installed_version rejects a non-GitHub RemoteSha", {
  local_mocked_bindings(
    find.package = function(pkg, quiet = TRUE) "/mock/library/member",
    read.dcf = function(file, fields = NULL) {
      matrix(
        c("1.2.3", "standard", "1.2.3"),
        nrow = 1L,
        dimnames = list(NULL, c("Version", "RemoteType", "RemoteSha"))
      )
    },
    .package = "base"
  )

  installed <- installed_version("member")

  expect_identical(as.character(installed), "1.2.3")
  expect_null(attr(installed, "remote_sha"))
})

test_that("installed_version rejects a malformed GitHub RemoteSha", {
  local_mocked_bindings(
    find.package = function(pkg, quiet = TRUE) "/mock/library/member",
    read.dcf = function(file, fields = NULL) {
      matrix(
        c("1.2.3", "github", "not-a-commit"),
        nrow = 1L,
        dimnames = list(NULL, c("Version", "RemoteType", "RemoteSha"))
      )
    },
    .package = "base"
  )

  installed <- installed_version("member")

  expect_null(attr(installed, "remote_sha"))
})
