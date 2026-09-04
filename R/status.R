#' Classify one member's installed version against the latest
#'
#' Pure: takes two version strings, including optional commit attributes, and
#' returns a status. Checking whether the package is installed comes first, so
#' a member that is absent reports as `"missing"` whether or not the remote was
#' reachable.
#'
#' @param installed Installed version string, or `NA_character_` if absent.
#' @param latest Latest version string, or `NA_character_` if unavailable.
#' @param remote Was the remote consulted? When `FALSE`, an installed package
#'   reports `"ok-local"` rather than `"unknown"`.
#' @return A length-1 character status: one of `"missing"`, `"ok-local"`,
#'   `"unknown"`, `"stale"`, `"ahead"` or `"ok"`.
#' @noRd
classify_status <- function(installed, latest, remote = TRUE) {
  if (is.na(installed)) {
    return("missing")
  }

  if (!remote) {
    return("ok-local")
  }

  if (is.na(latest)) {
    return("unknown")
  }

  comparison <- utils::compareVersion(installed, latest)

  if (comparison < 0L) {
    "stale"
  } else if (comparison > 0L) {
    "ahead"
  } else if (!is.null(attr(installed, "remote_sha")) &&
               isTRUE(attr(latest, "commit_checked"))) {
    installed_sha <- attr(installed, "remote_sha")
    latest_sha <- attr(latest, "remote_sha")

    if (is.null(latest_sha) || is.na(latest_sha)) {
      "unknown"
    } else if (identical(tolower(installed_sha), tolower(latest_sha))) {
      "ok"
    } else {
      "stale"
    }
  } else {
    "ok"
  }
}

#' Installed version of a package
#'
#' @param pkg Package name.
#' @return A length-1 character version string, optionally carrying pak's
#'   `RemoteSha` as a `remote_sha` attribute, or `NA_character_` if the package
#'   is not installed in any library on the search path.
#' @noRd
installed_version <- function(pkg) {
  found <- suppressWarnings(find.package(pkg, quiet = TRUE))

  if (length(found) == 0L) {
    return(NA_character_)
  }

  description <- read.dcf(
    file.path(found[1L], "DESCRIPTION"),
    fields = c("Version", "RemoteType", "RemoteSha")
  )
  version <- as.character(description[1L, "Version"])
  remote_type <- description[1L, "RemoteType"]
  sha <- description[1L, "RemoteSha"]

  if (!is.na(remote_type) && tolower(remote_type) == "github" &&
        !is.na(sha) && grepl("^[[:xdigit:]]{40}$", sha)) {
    attr(version, "remote_sha") <- tolower(as.character(sha))
  }

  version
}

#' Version status of every hvtiR member
#'
#' Compares each member installed locally against the version and, when pak
#' recorded its GitHub commit, the commit on the `main` branch of its
#' repository. The returned table remains version-focused; commit provenance
#' is an internal tie-breaker when versions match.
#'
#' The object is returned visibly and has a `print` method, so a bare call
#' displays the table while `st <- status()` captures the data frame
#' for scripting.
#'
#' @param remote Consult GitHub for the latest versions? When `FALSE`, no
#'   network request is made, `latest` is `NA` throughout, and installed
#'   members report `"ok-local"`.
#' @return A data frame of class `hvtiR_status`, one row per member, with
#'   character columns:
#'   \describe{
#'     \item{package}{The package name.}
#'     \item{repo}{The GitHub repository it installs from.}
#'     \item{installed}{Installed version, or `NA` if not installed.}
#'     \item{latest}{Version on GitHub `main`, or `NA`.}
#'     \item{status}{One of `"ok"`, `"stale"`, `"missing"`, `"ahead"`,
#'       `"unknown"` or `"ok-local"`. A member is also `"stale"` when its
#'       version matches `main` but its recorded GitHub commit does not.}
#'   }
#' @export
#' @examples
#' # Offline: reports what is installed without contacting GitHub
#' status(remote = FALSE)
status <- function(remote = TRUE) {
  registry <- members()

  installed_checks <- lapply(registry$package, installed_version)

  installed <- vapply(
    installed_checks, as.character,
    FUN.VALUE = character(1), USE.NAMES = FALSE
  )

  checks <- if (remote) {
    lapply(registry$repo, remote_version)
  } else {
    rep(list(NA_character_), nrow(registry))
  }

  latest <- vapply(
    checks, as.character,
    FUN.VALUE = character(1), USE.NAMES = FALSE
  )

  if (remote) {
    commit_candidates <- vapply(
      seq_len(nrow(registry)),
      function(i) {
        sha <- attr(installed_checks[[i]], "remote_sha")
        !is.null(sha) && !is.na(latest[i]) &&
          utils::compareVersion(installed[i], latest[i]) == 0L
      },
      FUN.VALUE = logical(1)
    )

    for (i in which(commit_candidates)) {
      commit <- remote_commit(registry$repo[i])
      attr(checks[[i]], "remote_sha") <- as.character(commit)
      attr(checks[[i]], "commit_checked") <- TRUE

      commit_error <- attr(commit, "remote_error")
      if (!is.null(commit_error)) {
        attr(checks[[i]], "remote_error") <- commit_error
      }
    }
  }

  remote_error <- vapply(
    checks,
    function(x) {
      error <- attr(x, "remote_error")
      if (is.null(error)) NA_character_ else error
    },
    FUN.VALUE = character(1), USE.NAMES = FALSE
  )

  state <- vapply(
    seq_len(nrow(registry)),
    function(i) {
      classify_status(
        installed_checks[[i]], checks[[i]], remote = remote
      )
    },
    FUN.VALUE = character(1)
  )

  out <- data.frame(
    package = registry$package,
    repo = registry$repo,
    installed = installed,
    latest = latest,
    status = state,
    stringsAsFactors = FALSE
  )

  failed <- !is.na(remote_error)
  attr(out, "remote_errors") <- data.frame(
    package = registry$package[failed],
    repo = registry$repo[failed],
    error = remote_error[failed],
    stringsAsFactors = FALSE
  )

  if (remote) {
    unresolved <- sum(is.na(latest) | state == "unknown")

    if (unresolved > 0L) {
      cli::cli_warn(c(
        paste0(
          "Could not determine the latest version or commit for ",
          "{unresolved} member{?s}."
        ),
        i = paste0(
          "GitHub may be unreachable, or a remote response may be ",
          "unreadable."
        ),
        i = "The remote check is incomplete."
      ))
    }
  }

  class(out) <- c("hvtiR_status", "data.frame")
  out
}

#' The running hvtiR version
#'
#' hvtiR is not a member, so `status()` walks `members()` and never reports the
#' version of the package the user is actually running. That is the first thing
#' a maintainer needs from a pasted `status()` or `doctor()`, and both issue
#' templates ask for exactly that output.
#'
#' @return A length-1 character version, or `NA_character_` if the package
#'   description cannot be read.
#' @noRd
hvtir_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("hvtiR")),
    error = function(e) NA_character_
  )
}

#' @export
print.hvtiR_status <- function(x, ...) {
  symbols <- c(
    ok = "v", `ok-local` = "-", stale = "!", ahead = "^",
    missing = "x", unknown = "?"
  )

  width <- max(nchar(x$package))
  stale <- sum(x$status %in% c("stale", "missing"))
  unknown <- sum(x$status == "unknown")
  ok_local <- sum(x$status == "ok-local")

  # cli's default handler writes via message() (stderr), which would make
  # this invisible to print()'s conventional stdout consumers (and to
  # testthat::expect_output()). cli_fmt() captures the formatted lines
  # instead of displaying them, so we can cat() them to stdout ourselves.
  lines <- cli::cli_fmt({
    version <- hvtir_version()
    if (is.na(version)) {
      cli::cli_text("{.strong hvtiR} - {nrow(x)} member{?s}")
    } else {
      cli::cli_text("{.strong hvtiR} {version} - {nrow(x)} member{?s}")
    }
    cli::cli_verbatim("")

    for (i in seq_len(nrow(x))) {
      cli::cli_verbatim(sprintf(
        "  %s %-*s  %-10s %-10s %s",
        symbols[[x$status[i]]],
        width, x$package[i],
        ifelse(is.na(x$installed[i]), "-", x$installed[i]),
        ifelse(is.na(x$latest[i]), "-", x$latest[i]),
        x$status[i]
      ))
    }

    cli::cli_verbatim("")
    if (stale > 0L) {
      cli::cli_alert_info(
        "{stale} member{?s} need{?s/} updating. Run {.run hvtiR::update()}."
      )
    } else if (unknown > 0L) {
      cli::cli_alert_warning(
        "{unknown} member{?s} could not be checked against GitHub."
      )
    } else if (ok_local > 0L) {
      cli::cli_alert_info(
        "Remote was not consulted; versions shown are installed versions only."
      )
    } else {
      cli::cli_alert_success("Everything is up to date.")
    }
  })

  cat(lines, sep = "\n")

  invisible(x)
}

# The strictest R requirement across the family: ggRandomForests and
# hvtiRlifetables both declare Depends: R (>= 4.4.0). hvtiR itself
# deliberately requires only 4.1.0 so that this diagnostic can run on a
# machine whose R is too old for the members.
# Package constant; see SELF_REPO in install.R for the same convention.
# nolint next: object_name_linter.
MIN_R_VERSION <- "4.4.0"

#' Is pak available for installation commands?
#'
#' @return A length-1 logical value.
#' @noRd
pak_available <- function() {
  requireNamespace("pak", quietly = TRUE)
}

#' Is renv available for pinning package versions?
#'
#' Uses [base::find.package()] rather than [base::requireNamespace()]: this
#' package never calls `renv`, it only reports on it, so there is no reason to
#' load the namespace or to declare a dependency the package does not use.
#'
#' @return A length-1 logical value.
#' @noRd
renv_available <- function() {
  length(suppressWarnings(find.package("renv", quiet = TRUE))) > 0L
}

#' Classify the renv situation
#'
#' Pure: `installed` and `project` are parameters rather than calls made in
#' the body, so every situation is testable without installing `renv` or
#' touching the environment.
#'
#' `renv` sets `RENV_PROJECT` when it loads a project, so a non-empty value is
#' what distinguishes an active project from a machine that merely has `renv`
#' on it. Without `renv` the project variable cannot be acted on, so it does
#' not change the answer.
#'
#' @param installed Is `renv` installed?
#' @param project The `RENV_PROJECT` environment variable, possibly `""`.
#' @return A length-1 character state: one of `"active"`, `"installed"` or
#'   `"absent"`.
#' @noRd
renv_state <- function(installed = renv_available(),
                       project = Sys.getenv("RENV_PROJECT", "")) {
  if (!installed) {
    return("absent")
  }

  if (nzchar(project)) "active" else "installed"
}

#' Diagnose an hvtiR installation
#'
#' Reports the running R version against the strictest requirement in the
#' package family, whether `pak` is installed, the platform, and then the full
#' member status table. When a remote check fails, reports the reason retained
#' by [hvtiR::status()]. This is the report to run first when a member will not
#' install.
#'
#' @param remote Consult GitHub for the latest versions? Passed through to
#'   [hvtiR::status()].
#' @return The [hvtiR::status()] data frame, invisibly. Called for the
#'   report it prints.
#' @export
#' @examples
#' # Offline: environment checks plus what is installed
#' doctor(remote = FALSE)
doctor <- function(remote = TRUE) {
  lines <- cli::cli_fmt({
    cli::cli_h1("hvtiR doctor")

    cli::cli_h2("Environment")

    # First line of the section, because it is the first thing a maintainer
    # needs from a pasted report and the one thing the member table below
    # cannot show: hvtiR is not a member of its own registry.
    version <- hvtir_version()
    if (is.na(version)) {
      cli::cli_alert_warning("hvtiR version could not be read")
    } else {
      cli::cli_alert_info("hvtiR {version}")
    }

    current <- getRversion()
    if (current < MIN_R_VERSION) {
      cli::cli_alert_danger(
        "R version {current} - members require {MIN_R_VERSION} or newer."
      )
      cli::cli_alert_info(
        "{.pkg ggRandomForests} and {.pkg hvtiRlifetables} will not install."
      )
    } else {
      cli::cli_alert_success(
        "R version {current} (>= {MIN_R_VERSION} required)"
      )
    }

    cli::cli_alert_info("Platform {R.version$platform}")

    if (pak_available()) {
      cli::cli_alert_success("{.pkg pak} is installed")
    } else {
      cli::cli_alert_danger("{.pkg pak} is not installed")
      cli::cli_alert_info(
        paste0(
          "Install it with {.code install.packages(\"pak\")} ",
          "before installing members."
        )
      )
    }

    renv <- renv_state()
    if (renv == "active") {
      cli::cli_alert_success(
        "{.pkg renv} project is active - it can pin member versions"
      )
    } else {
      if (renv == "installed") {
        cli::cli_alert_info(
          "{.pkg renv} is installed, but this is not an {.pkg renv} project"
        )
      } else {
        cli::cli_alert_info("{.pkg renv} is not installed")
      }
      cli::cli_alert_info(
        paste0(
          "Member versions are not pinned - installs resolve from ",
          "GitHub {.val main}."
        )
      )
    }

    cli::cli_h2("Members")
  })

  cat(lines, sep = "\n")

  st <- status(remote = remote)
  print(st)

  failures <- attr(st, "remote_errors")
  if (!is.null(failures) && nrow(failures) > 0L) {
    lines <- cli::cli_fmt({
      cli::cli_h2("Remote checks")

      for (i in seq_len(nrow(failures))) {
        cli::cli_alert_warning(
          "{.pkg {failures$package[i]}}: {failures$error[i]}"
        )
      }
    })
    cat(lines, sep = "\n")
  }

  invisible(st)
}
