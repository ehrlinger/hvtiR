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

#' What one healing round does with each failed package
#'
#' Pure, so every rule is testable without a child process.
#' @param failures From [classify_failures()].
#' @param specs From [record_specs()], named by package; `NA` has no safe spec.
#' @param moved Packages whose pins already moved this run.
#' @param missing Packages already left out this run.
#' @param essential Packages that stop the run rather than being left out.
#' @param upgrade As passed to [setup()].
#' @param stuck `TRUE` when this round failed on the same set as the last, or
#'   is the last round allowed.
#' @return `list(move, install, drop, stop)`.
#' @noRd
plan_round <- function(failures, specs, moved, missing, essential, upgrade,
                       stuck) {
  move <- character()
  install <- character()
  drop <- data.frame(
    package = character(), reason = character(), because = character(),
    stringsAsFactors = FALSE
  )
  stop_pkgs <- character()
  give_up <- function(pkg, reason, because = NA_character_) {
    if (pkg %in% essential) {
      stop_pkgs <<- c(stop_pkgs, pkg)
    } else {
      drop[nrow(drop) + 1L, ] <<- list(pkg, reason, because)
    }
  }
  for (i in seq_len(nrow(failures))) {
    pkg <- failures$package[i]
    cause <- failures$cause[i]
    if (cause == "compile") {
      spec <- unname(specs[pkg])
      if (pkg %in% moved) {
        give_up(pkg, "still failed to compile after its version moved")
      } else if (isTRUE(upgrade) && !stuck && length(spec) && !is.na(spec)) {
        move[pkg] <- spec
      } else {
        give_up(pkg, "failed to compile at its locked version")
      }
    } else if (cause == "dependency") {
      needs <- failures$needs[i]
      if (needs %in% missing) {
        give_up(pkg, paste0("needs ", needs, ", which was left out"), needs)
      } else if (!stuck) {
        install <- union(install, needs)
      } else {
        give_up(pkg, paste0("dependency ", needs, " is not available"), needs)
      }
    } else {
      give_up(pkg, "failed to install")
    }
  }
  list(move = move, install = install, drop = drop, stop = stop_pkgs)
}
