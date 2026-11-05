#' Why each package in a child's output failed to install
#'
#' Read from untrusted output, so only valid package names are taken. A
#' package gets the first cause found, in the order compile, dependency,
#' other.
#' @param output A child's output.
#' @return A data.frame: `package`, `cause` (`"compile"`, `"dependency"` or
#'   `"other"`) and `needs` (the missing dependency, else `NA`).
#' @noRd
classify_failures <- function(output) {
  name <- "([A-Za-z][A-Za-z0-9.]*[A-Za-z0-9])"
  open <- "[‘'\"“]"
  close <- "[’'\"”]"
  configured <- paste0(
    "configuration failed for package ", open, name, close
  )
  hits <- regmatches(output, gregexpr(configured, output))[[1L]]
  compiled <- unique(c(
    compile_failures(output), sub(configured, "\\1", hits)
  ))
  dependency <- paste0(
    "dependency ", open, name, close, " is not available for package ",
    open, name, close
  )
  dep_hits <- regmatches(output, gregexpr(dependency, output))[[1L]]
  dep_pkg <- sub(dependency, "\\2", dep_hits)
  dep_needs <- sub(dependency, "\\1", dep_hits)
  failed <- restore_failures(output)
  other <- if (is.null(failed)) character() else failed$pkgs
  out <- data.frame(
    package = c(compiled, dep_pkg, other),
    cause = c(
      rep("compile", length(compiled)), rep("dependency", length(dep_pkg)),
      rep("other", length(other))
    ),
    needs = c(
      rep(NA_character_, length(compiled)), dep_needs,
      rep(NA_character_, length(other))
    ),
    stringsAsFactors = FALSE
  )
  out <- out[!duplicated(out$package), , drop = FALSE]
  rownames(out) <- NULL
  out
}
