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
