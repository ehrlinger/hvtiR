#' Which install targets are already loaded
#'
#' Pure: `loaded` is a parameter rather than a call to
#' [base::loadedNamespaces()] inside the body, so the guard can be tested
#' without loading anything.
#'
#' @param targets Character vector of package names about to be installed.
#' @param loaded Character vector of loaded namespace names.
#' @return The subset of `targets` present in `loaded`, possibly empty.
#' @noRd
check_loaded <- function(targets, loaded = loadedNamespaces()) {
  intersect(targets, loaded)
}

#' Map member package names to their GitHub specs
#'
#' @param members The registry, as returned by [hvtiverse_members()].
#' @param packages Character vector of member package names.
#' @return A character vector of `"owner/repo"` strings, in the order of
#'   `packages`.
#' @noRd
build_specs <- function(members, packages) {
  index <- match(packages, members$package)

  if (anyNA(index)) {
    unknown <- packages[is.na(index)]
    cli::cli_abort("{.pkg {unknown}} {?is/are} not an hvtiverse member.")
  }

  members$repo[index]
}

#' Install specs with pak
#'
#' The seam that performs the actual installation, isolated so that tests can
#' replace it and never install anything.
#'
#' @param specs Character vector of `"owner/repo"` strings.
#' @return The value returned by [pak::pak()], invisibly.
#' @noRd
pak_install <- function(specs) {
  if (!requireNamespace("pak", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg pak} package is required to install hvtiverse members.",
      i = 'Install it with {.code install.packages("pak")}, then try again.'
    ))
  }

  invisible(pak::pak(specs, ask = FALSE))
}

#' Install a set of members
#'
#' Every spec goes to [pak::pak()] in one call. This is a correctness
#' requirement, not an optimisation: `hvtiRlifetables` imports
#' `TemporalHazard (>= 1.2.0)` without a `Remotes:` line, so resolving it on
#' its own sends pak to CRAN and the requirement fails. Passing every spec at
#' once co-resolves `ehrlinger/temporal_hazard` and satisfies the import.
#'
#' @param packages Character vector of member package names.
#' @param force Bypass the loaded-namespace guard.
#' @return The character vector of specs passed to pak, invisibly.
#' @noRd
install_members <- function(packages, force = FALSE) {
  if (length(packages) == 0L) {
    cli::cli_alert_success("All hvtiverse members are up to date.")
    return(invisible(character(0)))
  }

  blocked <- check_loaded(packages)

  if (length(blocked) > 0L && !force) {
    cli::cli_abort(c(
      "Cannot install {.pkg {blocked}}: already loaded in this session.",
      i = paste0(
        "{cli::qty(length(blocked))}Restart R and run this before ",
        "anything attaches {?it/them}."
      ),
      i = "Pass {.code force = TRUE} to install anyway (unsafe on Windows)."
    ))
  }

  specs <- build_specs(hvtiverse_members(), packages)
  pak_install(specs)

  cli::cli_alert_success("Installed {length(specs)} member{?s}.")
  invisible(specs)
}

#' Install every hvtiverse member
#'
#' Installs all members from GitHub `main`, whether or not they are already
#' present. This is the fresh-machine command; use [hvtiverse_update()] to
#' install only what is missing or out of date.
#'
#' Members are installed from GitHub rather than CRAN so that releases held
#' behind the CRAN queue remain available.
#'
#' @param force Bypass the loaded-namespace guard. A package whose namespace
#'   is loaded cannot be safely overwritten; on Windows the write fails and
#'   leaves a broken library. Unsafe — restart R instead.
#' @return The character vector of `"owner/repo"` specs passed to pak,
#'   invisibly.
#' @export
#' @examples
#' \dontrun{
#' hvtiverse_install()
#' }
hvtiverse_install <- function(force = FALSE) {
  install_members(hvtiverse_members()$package, force = force)
}

#' Update out-of-date hvtiverse members
#'
#' Installs only the members whose status is `"missing"` or `"stale"`. When
#' everything is current, reports that and installs nothing.
#'
#' @param force Bypass the loaded-namespace guard. See [hvtiverse_install()].
#' @return The character vector of `"owner/repo"` specs passed to pak,
#'   invisibly. Empty if nothing needed updating.
#' @export
#' @examples
#' \dontrun{
#' hvtiverse_update()
#' }
hvtiverse_update <- function(force = FALSE) {
  st <- hvtiverse_status(remote = TRUE)
  targets <- st$package[st$status %in% c("missing", "stale")]

  install_members(targets, force = force)
}
