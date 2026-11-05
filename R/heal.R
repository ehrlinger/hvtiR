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

#' The locked version of each package
#' @param pkgs Valid package names.
#' @param root The study root.
#' @return A character vector named by `pkgs`, `NA` with no record.
#' @noRd
locked_versions <- function(pkgs, root) {
  path <- file.path(root, "renv.lock")
  text <- if (file.exists(path)) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  vapply(
    stats::setNames(pkgs, pkgs),
    function(pkg) lock_field(text, pkg, "Version"),
    character(1L)
  )
}

#' The child's code to move pins to the newest version the repositories serve
#' @param root The study root.
#' @param specs Specs from [record_specs()], named by package, none `NA`.
#' @param repos The study's repositories, or `NULL`.
#' @return One string of R code; it prints `HVTIR_RECORDED=pkg:version,...`.
#' @noRd
record_expr <- function(root, specs, repos = NULL) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    repos_expr(repos),
    "renv::record(", deparse1(unname(specs)), ", project = ", p, "); ",
    "lf <- renv::lockfile_read(file.path(", p, ", 'renv.lock'))$Packages; ",
    "pk <- ", deparse1(names(specs)), "; ",
    "cat('\\nHVTIR_RECORDED=', paste0(pk, ':', vapply(pk, function(x) ",
    "if (is.null(lf[[x]])) '' else as.character(lf[[x]]$Version), ''), ",
    "collapse = ','), '\\n', sep = '')"
  )
}

#' The child's code to install packages into the study's library
#' @param root The study root.
#' @param specs Install specs, such as `"tseries@0.10-58"` or `"tseries"`.
#' @param repos The study's repositories, or `NULL`.
#' @return One string of R code.
#' @noRd
install_expr <- function(root, specs, repos = NULL) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    repos_expr(repos),
    "renv::install(", deparse1(unname(specs)), ", project = ", p,
    ", prompt = FALSE)"
  )
}

#' The child's code to take records out of the study's lockfile
#' @param root The study root.
#' @param pkgs Valid package names.
#' @return One string of R code.
#' @noRd
drop_expr <- function(root, pkgs) {
  path <- deparse1(file.path(normalizePath(root, winslash = "/"), "renv.lock"))
  paste0(
    "lf <- renv::lockfile_read(", path, "); ",
    "lf$Packages[", deparse1(pkgs), "] <- NULL; ",
    "renv::lockfile_write(lf, ", path, ")"
  )
}

#' Copy the study's lockfile aside before healing changes it
#' @param root The study root.
#' @param stamp A time stamp for the file name.
#' @return The copy's path relative to `root`, or `NA` with no lockfile.
#' @noRd
backup_lock <- function(root, stamp = format(Sys.time(), "%Y%m%d-%H%M%S")) {
  lock <- file.path(root, "renv.lock")
  if (!file.exists(lock)) return(NA_character_)
  rel <- file.path("renv", paste0("renv.lock.before-setup-", stamp))
  dir.create(file.path(root, "renv"), showWarnings = FALSE)
  if (!file.copy(lock, file.path(root, rel), overwrite = FALSE)) {
    cli::cli_abort("Could not back up {.file renv.lock} to {.file {rel}}.")
  }
  rel
}
