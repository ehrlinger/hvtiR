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
