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
  open <- "[\u2018'\"\u201c]"
  close <- "[\u2019'\"\u201d]"
  configured <- paste0(
    "configuration failed for package ", open, name, close
  )
  hits <- regmatches(output, gregexpr(configured, output))[[1L]]
  compiled <- unique(c(
    compile_failures(output), sub(configured, "\\1", hits)
  ))
  dependency <- paste0(
    "dependenc(?:y|ies) ([^\n]*?) (?:is|are) not available for package ",
    open, name, close
  )
  dep_hits <- regmatches(
    output, gregexpr(dependency, output, perl = TRUE)
  )[[1L]]
  dep_pkg <- sub(dependency, "\\2", dep_hits, perl = TRUE)
  dep_needs <- vapply(
    sub(dependency, "\\1", dep_hits, perl = TRUE),
    function(part) {
      found <- regmatches(part, gregexpr(name, part, perl = TRUE))[[1L]]
      paste(found, collapse = ",")
    },
    character(1L), USE.NAMES = FALSE
  )
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
      list(stop = pkg)
    } else {
      list(drop = list(pkg, reason, because))
    }
  }
  for (i in seq_len(nrow(failures))) {
    pkg <- failures$package[i]
    cause <- failures$cause[i]
    needs <- failures$needs[i]
    if (cause == "dependency" && (is.na(needs) || !nzchar(needs))) {
      cause <- "other"
    }
    gave <- NULL
    if (cause == "compile") {
      spec <- unname(specs[pkg])
      if (pkg %in% moved) {
        gave <- give_up(pkg, "still failed to compile after its version moved")
      } else if (isTRUE(upgrade) && !stuck && length(spec) && !is.na(spec)) {
        move[pkg] <- spec
      } else {
        gave <- give_up(pkg, "failed to compile at its locked version")
      }
    } else if (cause == "dependency") {
      wanted <- strsplit(needs, ",", fixed = TRUE)[[1L]]
      absent <- wanted[wanted %in% missing][1L]
      if (!is.na(absent)) {
        gave <- give_up(
          pkg, paste0("needs ", absent, ", which was left out"), absent
        )
      } else if (!stuck) {
        install <- union(install, wanted)
      } else {
        gave <- give_up(
          pkg, paste0("dependency ", needs, " is not available"), needs
        )
      }
    } else {
      gave <- give_up(pkg, "failed to install")
    }
    if (!is.null(gave$stop)) stop_pkgs <- c(stop_pkgs, gave$stop)
    if (!is.null(gave$drop)) drop[nrow(drop) + 1L, ] <- gave$drop
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

#' Restore the study's lockfile, healing what fails, leaving out what cannot
#'
#' Each round restores; on failure, [plan_round()] decides what to move,
#' install first, leave out or stop on. A round that fails on the same set
#' as the last, or the last round allowed, moves and installs nothing more.
#' A pin counts as healed only when its recorded version changed.
#' @param root The study root.
#' @param repos The study's repositories, or `NULL`.
#' @param upgrade As passed to [setup()].
#' @param essential Packages whose failure stops the run.
#' @param max_rounds The most healing rounds.
#' @return `list(result, raw, healed, missing, backup)`.
#' @noRd
heal_restore <- function(root, repos, upgrade, essential, max_rounds = 10L) {
  healed <- data.frame(
    package = character(), from = character(), to = character(),
    round = integer(), stringsAsFactors = FALSE
  )
  missing <- data.frame(
    package = character(), reason = character(), because = character(),
    log = character(), stringsAsFactors = FALSE
  )
  moved <- character()
  backup <- NA_character_
  previous <- NULL
  child <- function(expr, what) {
    out <- run_in_study(expr, root)
    if (out$status != 0L) {
      cli::cli_abort(c(
        "Healing the study's packages failed while {what}.",
        output_bullets(out$output),
        i = "Full output: {.file {save_setup_log(out$output)}}"
      ))
    }
    out
  }
  for (round in seq_len(max_rounds + 1L)) {
    raw <- run_in_study(restore_expr(root, repos), root)
    result <- raw
    result$output <- iconv(raw$output, "UTF-8", "UTF-8", sub = "?")
    if (result$status == 0L) {
      return(list(result = result, raw = raw$output, healed = healed,
                  missing = missing, backup = backup))
    }
    failures <- classify_failures(result$output)
    if (!nrow(failures) || round > max_rounds) {
      abort_stage(result, raw$output, root, upgrade)
    }
    set <- sort(failures$package)
    stuck <- identical(set, previous) || round == max_rounds
    previous <- set
    decision <- plan_round(
      failures, record_specs(failures$package, root), moved,
      missing$package, essential, upgrade, stuck
    )
    if (length(decision$stop)) {
      abort_stage(result, raw$output, root, upgrade)
    }
    if (is.na(backup)) backup <- backup_lock(root)
    if (length(decision$move)) {
      from <- locked_versions(names(decision$move), root)
      out <- child(record_expr(root, decision$move, repos), "moving pins")
      got <- strsplit(child_value(out$output, "HVTIR_RECORDED"), ",",
                      fixed = TRUE)[[1L]]
      to <- stats::setNames(sub("^[^:]*:", "", got), sub(":.*$", "", got))
      for (pkg in names(decision$move)) {
        moved <- union(moved, pkg)
        new <- unname(to[pkg])
        if (!is.na(new) && nzchar(new) && !identical(new, unname(from[pkg]))) {
          healed[nrow(healed) + 1L, ] <- list(
            pkg, unname(from[pkg]), new, round
          )
        }
      }
    }
    if (length(decision$install)) {
      version <- locked_versions(decision$install, root)
      specs <- ifelse(is.na(version), decision$install,
                      paste0(decision$install, "@", version))
      child(install_expr(root, specs, repos), "installing dependencies first")
    }
    if (nrow(decision$drop)) {
      log <- save_setup_log(raw$output)
      child(drop_expr(root, decision$drop$package), "leaving packages out")
      for (i in seq_len(nrow(decision$drop))) {
        missing[nrow(missing) + 1L, ] <- list(
          decision$drop$package[i], decision$drop$reason[i],
          decision$drop$because[i], log
        )
      }
    }
  }
}
