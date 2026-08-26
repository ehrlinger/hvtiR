# Maximum time a member's DESCRIPTION fetch may hold up diagnostics.
remote_timeout <- 5

# Base seconds between retried attempts, scaled by the attempt just failed.
remote_retry_wait <- 1

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
#' @param attempts Number of times to try the request before giving up,
#'   waiting `remote_retry_wait` seconds times the attempt just failed in
#'   between. The default of one keeps `status()` and `doctor()` inside the
#'   latency `remote_timeout` promises; callers that would rather wait than
#'   read a throttled host as a missing repository ask for more.
#' @return A character matrix as returned by [base::read.dcf()], or the value
#'   produced by `on_error` if every attempt failed. Warnings raised while
#'   connecting or parsing are muffled rather than discarding a result they
#'   did not actually invalidate.
#' @noRd
fetch_description <- function(
  repo,
  ref = "main",
  on_error = function(e) NULL,
  timeout = remote_timeout,
  attempts = 1L
) {
  # Guard before the loop: at attempts = 0 `seq_len()` yields nothing, so
  # `result` is never bound and the closing `on_error(result)` reaches for a
  # missing object. The default `on_error` ignores its argument and R's lazy
  # evaluation hides the mistake, but `remote_version()` passes
  # `on_error = identity`, which forces it.
  if (!is.numeric(attempts) || length(attempts) != 1L || is.na(attempts) ||
      attempts < 1) {
    cli::cli_abort("{.arg attempts} must be a single positive number.")
  }
  attempts <- as.integer(attempts)

  address <- sprintf(
    "https://raw.githubusercontent.com/%s/%s/DESCRIPTION",
    repo, ref
  )

  # Scoped to its own frame so each attempt closes its own connection: an
  # `on.exit()` registered in the loop would stack against `fetch_description`
  # and re-close the last connection once per attempt made.
  read_once <- function() {
    con <- url(address)
    on.exit(close(con), add = TRUE)
    read.dcf(con)
  }

  for (attempt in seq_len(attempts)) {
    result <- with_remote_timeout(
      timeout,
      tryCatch(
        withCallingHandlers(
          read_once(),
          warning = function(w) invokeRestart("muffleWarning")
        ),
        error = identity
      )
    )

    if (!inherits(result, "condition")) {
      return(result)
    }

    if (attempt < attempts) {
      Sys.sleep(remote_retry_wait * attempt)
    }
  }

  on_error(result)
}

#' Fetch a repository's branch commit feed
#'
#' Uses GitHub's public Atom feed rather than the rate-limited API.
#'
#' @param repo GitHub repository, as `"owner/repo"`.
#' @param ref Branch or tag whose latest commit is needed.
#' @param on_error Function applied to a connection error.
#' @param timeout Maximum number of seconds for the request.
#' @return Character lines from the Atom feed, or the value produced by
#'   `on_error` if the fetch failed.
#' @noRd
fetch_commit_feed <- function(
  repo,
  ref = "main",
  on_error = function(e) NULL,
  timeout = remote_timeout
) {
  address <- sprintf("https://github.com/%s/commits/%s.atom", repo, ref)

  with_remote_timeout(
    timeout,
    tryCatch(
      withCallingHandlers(
        {
          con <- url(address)
          on.exit(close(con), add = TRUE)
          readLines(con, warn = FALSE)
        },
        warning = function(w) invokeRestart("muffleWarning")
      ),
      error = on_error
    )
  )
}

#' Latest commit of a GitHub branch
#'
#' @param repo GitHub repository, as `"owner/repo"`.
#' @param ref Branch or tag to inspect.
#' @return A length-1 commit SHA, or `NA_character_` with a `remote_error`
#'   attribute if it could not be determined.
#' @noRd
remote_commit <- function(repo, ref = "main") {
  feed <- fetch_commit_feed(repo, ref, on_error = identity)

  if (inherits(feed, "condition")) {
    return(structure(
      NA_character_,
      remote_error = conditionMessage(feed)
    ))
  }

  pattern <- "Grit::Commit/[[:xdigit:]]{40}</id>"
  entry <- grep(pattern, feed, value = TRUE)

  if (length(entry) == 0L) {
    return(structure(
      NA_character_,
      remote_error = "Commit feed contains no commit SHA."
    ))
  }

  tolower(sub(
    ".*Grit::Commit/([[:xdigit:]]{40})</id>.*",
    "\\1",
    entry[1L]
  ))
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
