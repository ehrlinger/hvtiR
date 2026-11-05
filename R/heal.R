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
  # A package being left out is not a dependency worth installing for it.
  install <- setdiff(install, c(names(move), drop$package))
  list(move = move, install = install, drop = drop, stop = stop_pkgs)
}

#' The locked version of each package, or another field of its record
#' @param pkgs Valid package names.
#' @param root The study root.
#' @param field The record's field, `Version` unless named.
#' @return A character vector named by `pkgs`, `NA` with no record or field.
#' @noRd
locked_versions <- function(pkgs, root, field = "Version") {
  path <- file.path(root, "renv.lock")
  text <- if (file.exists(path)) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  vapply(
    stats::setNames(pkgs, pkgs),
    function(pkg) lock_field(text, pkg, field),
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
#' as the last, or any round from `max_rounds` on, moves and installs nothing
#' more and must leave out a new package or abort.
#' A pin counts as healed only when its recorded version changed.
#' @param root The study root.
#' @param repos The study's repositories, or `NULL`.
#' @param upgrade As passed to [setup()].
#' @param essential Packages whose failure stops the run.
#' @param max_rounds The most healing rounds.
#' @return `list(result, raw, healed, missing, backup, pins)`. `pins` holds
#'   the `version` and `sha` (`RemoteSha`, `NA` for none) each dropped record
#'   had, so [setup()] can judge a copy already in the library against it.
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
  pins <- data.frame(
    package = character(), version = character(), sha = character(),
    stringsAsFactors = FALSE
  )
  moved <- character()
  backup <- NA_character_
  previous <- NULL
  # Once the lock has changed, every abort names the backup.
  backup_note <- function() {
    if (is.na(backup)) return(NULL)
    c(i = paste0("Healing changed renv.lock; the original is {.file ",
                 backup, "}."))
  }
  abort_after <- function(result, raw) {
    if (is.na(backup)) abort_stage(result, raw, root, upgrade)
    tryCatch(
      abort_stage(result, raw, root, upgrade),
      error = function(e) {
        cli::cli_abort(c("Healing the study's packages failed.",
                         backup_note()), parent = e)
      }
    )
  }
  child_failed <- function(what, output) {
    cli::cli_abort(c(
      paste0("Healing the study's packages failed while ", what, "."),
      output_bullets(output),
      backup_note(),
      i = "Full output: {.file {save_setup_log(output, root)}}"
    ))
  }
  child <- function(expr, what) {
    out <- run_in_study(expr, root)
    if (out$status != 0L) child_failed(what, out$output)
    out
  }
  # Termination: up to max_rounds ordinary rounds, then every round is
  # stuck, so plan_round() only drops or stops. A stuck round must leave out
  # at least one package not already in `missing`, else it aborts. The lock
  # holds finitely many records and each such round removes one, so the loop
  # ends. A package already in `missing` that fails again adds nothing.
  round <- 0L
  repeat {
    round <- round + 1L
    raw <- run_in_study(restore_expr(root, repos), root)
    result <- raw
    result$output <- iconv(raw$output, "UTF-8", "UTF-8", sub = "?")
    if (result$status == 0L) {
      return(list(result = result, raw = raw$output, healed = healed,
                  missing = missing, backup = backup, pins = pins))
    }
    failures <- classify_failures(result$output)
    if (!nrow(failures)) abort_after(result, raw$output)
    set <- sort(failures$package)
    stuck <- identical(set, previous) || round >= max_rounds
    previous <- set
    decision <- plan_round(
      failures, record_specs(failures$package, root), moved,
      missing$package, essential, upgrade, stuck
    )
    if (length(decision$stop)) abort_after(result, raw$output)
    fresh <- decision$drop[!decision$drop$package %in% missing$package, ,
                           drop = FALSE]
    fresh <- fresh[!duplicated(fresh$package), , drop = FALSE]
    if (stuck && !nrow(fresh)) abort_after(result, raw$output)
    if (is.na(backup)) backup <- backup_lock(root)
    if (length(decision$move)) {
      from <- locked_versions(names(decision$move), root)
      out <- child(record_expr(root, decision$move, repos), "moving pins")
      value <- child_value(out$output, "HVTIR_RECORDED")
      if (!length(value) || is.na(value[1L]) || !nzchar(value[1L])) {
        child_failed(
          "moving pins; the child did not report the recorded versions",
          out$output
        )
      }
      got <- strsplit(value[1L], ",", fixed = TRUE)[[1L]]
      to <- stats::setNames(sub("^[^:]*:", "", got), sub(":.*$", "", got))
      for (pkg in names(decision$move)) {
        moved <- union(moved, pkg)
        new <- unname(to[pkg])
        old <- unname(from[pkg])
        if (!is.na(new) && nzchar(new) && !is.na(old) &&
              !identical(new, old)) {
          healed[nrow(healed) + 1L, ] <- list(pkg, old, new, round)
        }
      }
    }
    if (length(decision$install)) {
      version <- locked_versions(decision$install, root)
      specs <- ifelse(is.na(version), decision$install,
                      paste0(decision$install, "@", version))
      out <- run_in_study(install_expr(root, specs, repos), root)
      if (out$status != 0L) {
        # A dependency that will not install degrades its dependents.
        log <- save_setup_log(out$output, root)
        needed <- strsplit(failures$needs, ",", fixed = TRUE)
        dep <- vapply(needed, function(x) {
          hit <- intersect(x, decision$install)
          if (length(hit)) hit[1L] else NA_character_
        }, character(1L))
        blocked <- which(!is.na(dep) & !failures$package %in% missing$package)
        if (any(failures$package[blocked] %in% essential)) {
          abort_after(result, raw$output)
        }
        extra <- data.frame(
          package = failures$package[blocked],
          reason = paste0("dependency ", dep[blocked],
                          " could not be installed"),
          because = dep[blocked], log = rep(log, length(blocked)),
          stringsAsFactors = FALSE
        )
        extra <- extra[!extra$package %in% fresh$package, , drop = FALSE]
        if (!nrow(extra) && !nrow(fresh)) {
          child_failed("installing dependencies first", out$output)
        }
        fresh$log <- rep(NA_character_, nrow(fresh))
        fresh <- rbind(fresh, extra)
      }
    }
    if (nrow(fresh)) {
      if (is.null(fresh$log)) fresh$log <- NA_character_
      log <- save_setup_log(raw$output, root)
      # Read before the drop: afterwards the lock no longer holds them.
      pins <- rbind(pins, data.frame(
        package = fresh$package,
        version = unname(locked_versions(fresh$package, root)),
        sha = unname(locked_versions(fresh$package, root, "RemoteSha")),
        stringsAsFactors = FALSE
      ))
      child(drop_expr(root, fresh$package), "leaving packages out")
      for (i in seq_len(nrow(fresh))) {
        missing[nrow(missing) + 1L, ] <- list(
          fresh$package[i], fresh$reason[i], fresh$because[i],
          if (is.na(fresh$log[i])) log else fresh$log[i]
        )
      }
    }
  }
}

#' Write `renv/hvtiR-setup.dcf`, the study's record of its last setup
#'
#' DCF, read with [read.dcf()], because hvtiR imports nothing to read JSON.
#' One record per line of fact, each with a `Type`.
#' @param root The study root.
#' @param healed,missing From [heal_restore()], plus any packages the install
#'   and check stages left out.
#' @param backup The lock backup's relative path, or `NA`.
#' @param cleanup `attr(, "cleanup")` from `study_setup()`, of either shape,
#'   or `NULL` when cleanup was off. Its `Left` is a display list joined by
#'   `"; "`, not a parseable vector.
#' @return The record's path, invisibly.
#' @noRd
write_setup_record <- function(root, healed, missing, backup, cleanup) {
  field <- function(name, value) {
    if (is.null(value) || !length(value)) return(NULL)
    if (length(value) > 1L) {
      value <- value[!is.na(value) & nzchar(value)]
      if (!length(value)) return(NULL)
      value <- paste(value, collapse = "; ")
    }
    if (is.na(value[1L])) return(NULL)
    # A control character, `\r` included, would let read.dcf() see a new
    # record, and a leading blank would make the value a continuation line.
    value <- sub("^\\s+", "", gsub("[[:cntrl:]]+", " ", value[1L]))
    paste0(name, ": ", value)
  }
  block <- function(...) c(..., "")
  run <- block(
    "Type: run", field("At", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    field("User", Sys.info()[["user"]]),
    field("R", as.character(getRversion())),
    field("hvtiR", hvtir_version()),
    field("LockBackup", backup)
  )
  rows <- function(df, type, cols) {
    unlist(lapply(seq_len(NROW(df)), function(i) {
      block(paste0("Type: ", type), unlist(lapply(names(cols), function(k) {
        field(k, df[[cols[[k]]]][i])
      })))
    }))
  }
  status <- if (is.null(cleanup)) "off" else if (is.null(cleanup$status)) {
    "done"
  } else {
    cleanup$status
  }
  lines <- c(
    run,
    rows(healed, "healed",
         c(Package = "package", From = "from", To = "to", Round = "round")),
    rows(missing, "missing",
         c(Package = "package", Reason = "reason", Because = "because",
           Log = "log")),
    block("Type: cleanup", field("Status", status),
          field("Reason", cleanup$reason), field("Left", cleanup$left))
  )
  path <- file.path(root, "renv", "hvtiR-setup.dcf")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path)
  invisible(path)
}

#' Read `renv/hvtiR-setup.dcf`
#' @param root The study root.
#' @return `list(run, healed, missing, cleanup)` of data.frames, or `NULL`.
#' @noRd
read_setup_record <- function(root) {
  path <- file.path(root, "renv", "hvtiR-setup.dcf")
  if (!file.exists(path)) return(NULL)
  all <- as.data.frame(read.dcf(path), stringsAsFactors = FALSE)
  pick <- function(type) {
    out <- all[all$Type == type, , drop = FALSE]
    out <- out[, colSums(!is.na(out)) > 0L, drop = FALSE]
    rownames(out) <- NULL
    out
  }
  list(run = pick("run"), healed = pick("healed"), missing = pick("missing"),
       cleanup = pick("cleanup"))
}
