# Maximum time a member's DESCRIPTION fetch may hold up diagnostics.
remote_timeout <- 5

#' Evaluate an expression with a bounded connection timeout
#'
#' Restores the caller's timeout even when `code` errors.
#'
#' @param timeout Maximum number of seconds for a remote connection.
#' @param code Code to evaluate under the bounded timeout.
#' @return The value returned by `code`.
#' @noRd
with_remote_timeout <- function(timeout, code) {
  old <- options("timeout")
  on.exit(options(old), add = TRUE)

  options(timeout = min(old$timeout, timeout))
  force(code)
}

#' Fetch a repository's raw DESCRIPTION
#'
#' The single network seam in the package. Isolated in its own function so
#' tests can replace it with [testthat::local_mocked_bindings()] and never
#' reach the network.
#'
#' @param repo GitHub repository, as `"owner/repo"`.
#' @param ref Branch or tag to read from.
#' @param on_error Function applied to a connection or parsing error. The
#'   default preserves the existing `NULL`-on-failure contract.
#' @param timeout Maximum number of seconds for the request.
#' @return A character matrix as returned by [base::read.dcf()], or the value
#'   produced by `on_error` if the fetch failed. Warnings raised while
#'   connecting or parsing are muffled rather than discarding a result they
#'   did not actually invalidate.
#' @noRd
fetch_description <- function(
  repo,
  ref = "main",
  on_error = function(e) NULL,
  timeout = remote_timeout
) {
  address <- sprintf(
    "https://raw.githubusercontent.com/%s/%s/DESCRIPTION",
    repo, ref
  )

  with_remote_timeout(
    timeout,
    tryCatch(
      withCallingHandlers(
        {
          con <- url(address)
          on.exit(close(con), add = TRUE)
          read.dcf(con)
        },
        warning = function(w) invokeRestart("muffleWarning")
      ),
      error = on_error
    )
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
  dcf <- fetch_description(repo, ref, on_error = identity)

  if (inherits(dcf, "condition")) {
    return(structure(
      NA_character_,
      remote_error = conditionMessage(dcf)
    ))
  }

  if (is.null(dcf)) {
    return(NA_character_)
  }

  if (!"Version" %in% colnames(dcf)) {
    return(structure(
      NA_character_,
      remote_error = "DESCRIPTION has no Version field."
    ))
  }

  as.character(dcf[1L, "Version"])
}
