#' Classify one member's installed version against the latest
#'
#' Pure: takes two version strings and returns a status. Checking whether the
#' package is installed comes first, so a member that is absent reports as
#' `"missing"` whether or not the remote was reachable.
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
  } else {
    "ok"
  }
}

#' Installed version of a package
#'
#' @param pkg Package name.
#' @return A length-1 character version string, or `NA_character_` if the
#'   package is not installed in any library on the search path.
#' @noRd
installed_version <- function(pkg) {
  found <- suppressWarnings(find.package(pkg, quiet = TRUE))

  if (length(found) == 0L) {
    return(NA_character_)
  }

  as.character(utils::packageVersion(pkg))
}

#' Version status of every hvtiR member
#'
#' Compares the version of each member installed locally against the version
#' on the `main` branch of its GitHub repository.
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
#'       `"unknown"` or `"ok-local"`.}
#'   }
#' @export
#' @examples
#' # Offline: reports what is installed without contacting GitHub
#' status(remote = FALSE)
status <- function(remote = TRUE) {
  registry <- members()

  installed <- vapply(
    registry$package, installed_version,
    FUN.VALUE = character(1), USE.NAMES = FALSE
  )

  latest <- if (remote) {
    vapply(
      registry$repo, remote_version,
      FUN.VALUE = character(1), USE.NAMES = FALSE
    )
  } else {
    rep(NA_character_, nrow(registry))
  }

  state <- vapply(
    seq_len(nrow(registry)),
    function(i) classify_status(installed[i], latest[i], remote = remote),
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

  if (remote) {
    unresolved <- sum(is.na(latest))

    if (unresolved > 0L) {
      cli::cli_warn(c(
        "Could not determine the latest version for {unresolved} member{?s}.",
        i = "GitHub may be unreachable, or a repository's DESCRIPTION may be unreadable.",
        i = "The {.field latest} column is incomplete."
      ))
    }
  }

  class(out) <- c("hvtiR_status", "data.frame")
  out
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
    cli::cli_text("{.strong hvtiR} - {nrow(x)} member{?s}")
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
MIN_R_VERSION <- "4.4.0"

#' Diagnose an hvtiR installation
#'
#' Reports the running R version against the strictest requirement in the
#' package family, the platform, and then the full member status table. This
#' is the report to run first when a member will not install.
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

    current <- getRversion()
    if (current < MIN_R_VERSION) {
      cli::cli_alert_danger(
        "R version {current} - members require {MIN_R_VERSION} or newer."
      )
      cli::cli_alert_info(
        "{.pkg ggRandomForests} and {.pkg hvtiRlifetables} will not install."
      )
    } else {
      cli::cli_alert_success("R version {current} (>= {MIN_R_VERSION} required)")
    }

    cli::cli_alert_info("Platform {R.version$platform}")

    cli::cli_h2("Members")
  })

  cat(lines, sep = "\n")

  st <- status(remote = remote)
  print(st)

  invisible(st)
}
