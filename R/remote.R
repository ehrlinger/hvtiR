#' Fetch a repository's raw DESCRIPTION
#'
#' The single network seam in the package. Isolated in its own function so
#' tests can replace it with [testthat::local_mocked_bindings()] and never
#' reach the network.
#'
#' @param repo GitHub repository, as `"owner/repo"`.
#' @param ref Branch or tag to read from.
#' @return A character matrix as returned by [base::read.dcf()], or `NULL` if
#'   the fetch failed for any reason. Warnings raised while connecting or
#'   parsing are muffled rather than discarding a result they did not
#'   actually invalidate; only a true error yields `NULL`.
#' @noRd
fetch_description <- function(repo, ref = "main") {
  address <- sprintf(
    "https://raw.githubusercontent.com/%s/%s/DESCRIPTION",
    repo, ref
  )

  tryCatch(
    withCallingHandlers(
      {
        con <- url(address)
        on.exit(close(con), add = TRUE)
        read.dcf(con)
      },
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) NULL
  )
}

#' Latest version of a member on GitHub
#'
#' @param repo GitHub repository, as `"owner/repo"`.
#' @param ref Branch or tag to read from.
#' @return A length-1 character version string, or `NA_character_` if the
#'   version could not be determined.
#' @noRd
remote_version <- function(repo, ref = "main") {
  dcf <- fetch_description(repo, ref)

  if (is.null(dcf) || !"Version" %in% colnames(dcf)) {
    return(NA_character_)
  }

  as.character(dcf[1L, "Version"])
}
