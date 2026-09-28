test_that("doctor reports hvtiR's own version", {
  local_mocked_bindings(fetch_description = function(...) NULL)

  expect_output(doctor(remote = FALSE),
                paste0("hvtiR ", as.character(utils::packageVersion("hvtiR"))))
})

test_that("doctor reports the R version and the platform", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    fetch_description = function(...) NULL,
    repo_versions = function(...) character()
  )

  expect_output(doctor(), "R version")
  expect_output(doctor(), "Platform")
})

test_that("doctor returns the status table invisibly", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    fetch_description = function(...) NULL,
    repo_versions = function(...) character()
  )

  expect_invisible(doctor())

  st <- suppressMessages(doctor())
  expect_s3_class(st, "hvtiR_status")
})

test_that("doctor works with no network", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      stop("must not be called when remote = FALSE")
    }
  )

  output <- capture.output(
    st <- expect_no_error(suppressMessages(doctor(remote = FALSE)))
  )
  expect_true(all(st$status == "ok-local"))
  expect_true(any(grepl("pak", output)))
  expect_false(any(grepl("Remote checks", output)))
})

test_that("doctor reports when pak is not installed", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    pak_available = function() FALSE,
    fetch_description = function(...) NULL,
    repo_versions = function(...) character()
  )

  expect_output(doctor(), "pak.*not installed")
})

test_that("doctor prints the reason a remote check failed", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") {
      if (repo == "ehrlinger/hvtiPlotR") {
        return(structure(
          NA_character_,
          remote_error = "connection timed out"
        ))
      }
      "1.0.0"
    },
    pak_available = function() TRUE,
    fetch_description = function(...) NULL,
    repo_versions = function(...) character()
  )

  expect_warning(
    expect_output(doctor(), "hvtiPlotR.*connection timed out"),
    "Could not determine the latest version"
  )
})

test_that("renv_state classifies the three renv situations", {
  expect_equal(
    renv_state(installed = TRUE, project = "/home/u/study"), "active"
  )
  expect_equal(renv_state(installed = TRUE, project = ""), "installed")
  expect_equal(renv_state(installed = FALSE, project = ""), "absent")
})

test_that("renv_state reports absent when renv is gone but a project is set", {
  expect_equal(
    renv_state(installed = FALSE, project = "/home/u/study"), "absent"
  )
})

# doctor() wraps its cli output to the console width, so collapse the captured
# lines before matching a phrase that may have been broken across two of them.
doctor_text <- function() {
  paste(
    capture.output(suppressMessages(doctor(remote = FALSE))),
    collapse = " "
  )
}

test_that("doctor reports an active renv project and asks for nothing", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    renv_state = function(...) "active"
  )

  out <- doctor_text()
  expect_match(out, "renv project is active")
  expect_no_match(out, "not pinned")
})

test_that("doctor reports renv present but no project, and versions float", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    renv_state = function(...) "installed"
  )

  out <- doctor_text()
  expect_match(out, "not an renv project")
  expect_match(out, "not pinned")
})

test_that("doctor reports renv missing, and says versions float", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    renv_state = function(...) "absent"
  )

  out <- doctor_text()
  expect_match(out, "renv is not installed")
  expect_match(out, "not pinned")
})

test_that("snapshot_repos flags dated and numbered Package Manager URLs", {
  repos <- c(
    CRAN = "https://cloud.r-project.org",
    PPM = "https://packagemanager.posit.co/cran/__linux__/jammy/2026-08-01",
    OLD = "https://packagemanager.rstudio.com/all/__linux__/focal/4526215/",
    LATEST = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"
  )

  expect_named(snapshot_repos(repos), c("PPM", "OLD"))
  expect_length(snapshot_repos(c(CRAN = "https://cloud.r-project.org")), 0L)
})

test_that("doctor lists the repositories and warns about a snapshot", {
  local_mocked_bindings(installed_version = function(pkg) "1.0.0")
  old <- options(repos = c(
    CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/2026-08-01"
  ))
  on.exit(options(old), add = TRUE)

  out <- doctor_text()
  expect_match(out, "Repository CRAN")
  expect_match(out, "dated snapshot")
})

test_that("doctor does not warn about a live repository", {
  local_mocked_bindings(installed_version = function(pkg) "1.0.0")
  old <- options(repos = c(CRAN = "https://cloud.r-project.org"))
  on.exit(options(old), add = TRUE)

  out <- doctor_text()
  expect_match(out, "Repository CRAN")
  expect_no_match(out, "dated snapshot")
})

# The repository checks -----------------------------------------------------

test_that("dependency_floors keeps outside floors and drops the rest", {
  dcf <- cbind(
    Depends = "R (>= 4.4.0)",
    Imports = paste(
      "varPro (>= 3.3.0),\n    ggplot2, hvtiRutilities (>= 1.0.0),",
      "randomForestSRC (> 3.4.0), utils (>= 4.0.0)"
    )
  )

  floors <- dependency_floors(dcf, exclude = c("hvtiRutilities", "utils"))
  expect_equal(floors$package, c("varPro", "randomForestSRC"))
  expect_equal(floors$floor, c("3.3.0", "3.4.0"))
})

test_that("dependency_floors leaves out packages a Remotes: entry supplies", {
  dcf <- cbind(
    Imports = "boostmtree (>= 2.0.1), ggsankey (>= 0.0.9), varPro (>= 3.3.0)",
    Remotes = paste(
      "boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.2-ccf,",
      "davidsjoberg/ggsankey"
    )
  )

  expect_equal(dependency_floors(dcf)$package, "varPro")
})

test_that("unmet_floors reports missing and too-old packages only", {
  needs <- data.frame(
    member = "ggRandomForests",
    package = c("varPro", "igraph", "survival"),
    floor = c("3.3.0", "1.0.0", "3.0"),
    stringsAsFactors = FALSE
  )
  offered <- c(varPro = "3.1.0", varPro = "3.2.0", survival = "3.5-8")

  unmet <- unmet_floors(needs, offered)
  expect_equal(unmet$package, c("varPro", "igraph"))
  expect_equal(unmet$offered, c("3.2.0", NA))
})

test_that("doctor names a dependency floor a frozen snapshot cannot meet", {

  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    remote_version = function(repo, ref = "main") "1.0.0",
    fetch_description = function(repo, ...) {
      if (repo != "ehrlinger/ggRandomForests") {
        return(NULL)
      }
      cbind(Package = "ggRandomForests", Imports = "varPro (>= 3.3.0)")
    },
    repo_versions = function(...) c(varPro = "3.1.0")
  )

  out <- paste(capture.output(suppressMessages(doctor())), collapse = " ")
  expect_match(out, "ggRandomForests needs varPro >= 3.3.0")
  expect_match(out, "offer 3.1.0")
})

test_that("doctor offline skips the dependency floor check", {
  local_mocked_bindings(
    installed_version = function(pkg) "1.0.0",
    repo_versions = function(...) stop("must not be called offline"),
    fetch_description = function(...) stop("must not be called offline")
  )

  expect_no_match(doctor_text(), "Dependency floors")
})
