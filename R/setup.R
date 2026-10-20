#' Packages a study needs beyond the members
#'
#' Suggested packages that members' study-facing functions use: `arrow` reads
#' and writes registered data. Kept here, beside [members()], so one place owns
#' the list.
#'
#' @return A character vector of package names.
#' @noRd
environment_extras <- function() {
  c("arrow")
}

#' Every package a study declares
#'
#' @param registry The registry, as returned by [members()].
#' @return A character vector: `hvtiR`, the members, then the extras.
#' @noRd
declared_packages <- function(registry = members()) {
  c("hvtiR", registry$package, environment_extras())
}

#' Install specs for declared packages
#'
#' @param packages Character vector of package names.
#' @param registry The registry, as returned by [members()].
#' @return `packages` with `hvtiR` and members as `"owner/repo"`; other names
#'   are returned unchanged.
#' @noRd
install_specs <- function(packages, registry = members()) {
  repos <- c(SELF_REPO, registry$repo)
  names(repos) <- c("hvtiR", registry$package)
  unname(ifelse(packages %in% names(repos), repos[packages], packages))
}

# The hvtiRutilities release that carries study_declare() and study_need().
# 1.5.6 (hvtiRutilities#231, versioned in #232).
# Package constant, spelled like MIN_R_VERSION.
# nolint next: object_name_linter.
UTILITIES_FLOOR <- "1.5.6"

#' An exported hvtiRutilities function, installing the package first if needed
#'
#' Reached by name rather than through Imports, so hvtiR still installs on a
#' bare machine with only cli and utils.
#' @param name Function name.
#' @return The function.
#' @noRd
utilities_fn <- function(name) {
  version <- installed_version("hvtiRutilities")
  if (is.na(version) || package_version(version) < UTILITIES_FLOOR) {
    install_members(expand_targets("hvtiRutilities"), command = "setup()")
  }
  getExportedValue("hvtiRutilities", name)
}

#' Run R code in a fresh R process in the study
#'
#' The study's library is the target only in a process that loads the
#' project; this session's namespaces came from another library. renv's own
#' installer, not its pak back end: pak skips LinkingTo packages and the
#' snapshot's validation then aborts (spike check 5). Never force the snapshot.
#' The caller's code turns the pak back end off itself (see `pak_off()`), since
#' `system2(env =)` does not work on Windows.
#' @param expr R code, one string.
#' @param root The study root.
#' @return A list: `status` (integer) and `output` (one string).
#' @noRd
run_in_study <- function(expr, root) {
  owd <- setwd(root)
  on.exit(setwd(owd), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(expr)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(out, "status")
  list(
    status = if (is.null(status)) 0L else status,
    output = paste(out, collapse = "\n")
  )
}

rstudio_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()
}

#' Stop RStudio restoring and saving .RData
#' @return `TRUE` if RStudio preferences were written, invisibly.
#' @noRd
set_workspace_prefs <- function() {
  if (!rstudio_available()) return(invisible(FALSE))
  rstudioapi::writeRStudioPreference("load_workspace", FALSE)
  rstudioapi::writeRStudioPreference("save_workspace", "never")
  cli::cli_alert_success(
    "RStudio will no longer restore or save {.file .RData}."
  )
  invisible(TRUE)
}

#' Restart into the study project
#' @param root The study root.
#' @noRd
open_project <- function(root) {
  if (rstudio_available()) {
    rstudioapi::openProject(root)
  } else {
    cli::cli_alert_info(
      "Restart R in {.path {root}} to use the study's library."
    )
  }
  invisible(NULL)
}

#' Code that turns renv's pak back end off in the child
#' @noRd
pak_off <- function() "options(renv.config.pak.enabled = FALSE); "

#' The child's code to read the package names a lockfile records
#' @param root The study root.
#' @return One string of R code.
#' @noRd
locked_expr <- function(root) {
  p <- deparse1(file.path(normalizePath(root, winslash = "/"), "renv.lock"))
  paste0(
    pak_off(),
    "cat('\\nHVTIR_LOCKED=', paste(names(renv::lockfile_read(", p,
    ")$Packages), collapse = ','), '\\n', sep = '')"
  )
}

#' The first library of this session
#' @noRd
session_library <- function() .libPaths()[1L]

#' The last lines of a child's output
#' @param output One string.
#' @param n Lines to keep.
#' @noRd
tail_lines <- function(output, n = 40L) {
  lines <- strsplit(output, "\n", fixed = TRUE)[[1L]]
  paste(utils::tail(lines, n), collapse = "\n")
}

#' Is `path` inside `dir`?
#' @noRd
path_within <- function(path, dir) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  dir <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  identical(path, dir) || startsWith(path, paste0(sub("/$", "", dir), "/"))
}

#' The child process's install step
#' @param root The study root.
#' @param packages Declared package names.
#' @return One string of R code.
#' @noRd
install_expr <- function(root, packages) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  names_ <- deparse1(packages, width.cutoff = 500L)
  specs <- deparse1(install_specs(packages), width.cutoff = 500L)
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    "renv::settings$snapshot.type('explicit', project = ", p, "); ",
    "renv::restore(project = ", p, ", prompt = FALSE); ",
    "locked <- names(renv::lockfile_read(file.path(", p, ", 'renv.lock'))",
    "$Packages); ",
    "add <- ", specs, "[!", names_, " %in% locked]; ",
    "if (length(add)) renv::install(add, project = ", p, ", prompt = FALSE); ",
    "renv::snapshot(project = ", p, ", prompt = FALSE); ",
    "cat('\\nHVTIR_LIB=', .libPaths()[1L], '\\n', sep = '')"
  )
}

#' Set up a study's environment
#'
#' The one command a study needs before analysis. In order: checks R, installs
#' renv if it is missing, and turns off RStudio's `.RData` restore and save;
#' runs `hvtiRutilities::study_setup()` with renv on, which cleans up template
#' copies before renv when adopting; declares `hvtiR`, every member and the
#' packages they need in the study's `DESCRIPTION`; installs them into the
#' study's library in a fresh R process; snapshots; checks that every
#' package's dependencies resolve there; and restarts into the project.
#'
#' renv runs in explicit mode: the lockfile records what the study's
#' `DESCRIPTION` declares, not whatever the code happens to mention. A study
#' that already has a `renv.lock` keeps its locked versions, and on first
#' conversion every package that lockfile recorded is declared, so none drop
#' out. They are restored, and only packages the lockfile lacks are installed.
#' Moving a study's versions is [update()]'s job, and the study owner's
#' decision.
#'
#' `setup()` replaces packages in the study's library, so run it from a
#' session started outside the study project, passing `root`.
#'
#' Safe to rerun: each step checks before it acts.
#'
#' @param study The Study Tracker title.
#' @param study_tracker_id The Study Tracker ID, an integer.
#' @param root The study root. By default the study enclosing the working
#'   directory, or the working directory.
#' @param adopt Set up an existing study, adding only what is missing.
#'   Adopting cleans up template copies unless `cleanup = FALSE` is passed.
#' @param ... Passed to `hvtiRutilities::study_setup()`, such as `cleanup`,
#'   `template_dir` or `owner`. `renv` is not accepted: `setup()` always uses
#'   renv, so use `hvtiRutilities::study_setup()` directly for a study without
#'   it.
#' @return The study status from `hvtiRutilities::study_setup()`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' setup(study = "Study Tracker title", study_tracker_id = 1234L)
#' }
setup <- function(study, study_tracker_id, root = NULL, adopt = FALSE, ...) {
  if (getRversion() < MIN_R_VERSION) {
    cli::cli_abort(
      "R {getRversion()} is below the {MIN_R_VERSION} the family requires."
    )
  }
  if ("renv" %in% names(list(...))) {
    cli::cli_abort(c(
      "{.fn setup} always uses renv; {.arg renv} cannot be passed.",
      i = "Use {.fn hvtiRutilities::study_setup} for a study without renv."
    ))
  }
  if (is.null(root)) {
    study_root <- utilities_fn("study_root")
    root <- tryCatch(study_root(), error = function(e) {
      if (!grepl("_study.yml", conditionMessage(e), fixed = TRUE)) stop(e)
      getwd()
    })
  }
  if (path_within(session_library(), root)) {
    cli::cli_abort(c(
      paste(
        "{.fn setup} replaces packages in the study's library, which this",
        "session has loaded."
      ),
      i = paste(
        "Run it from a session started outside the study project, passing",
        "{.code root = \"<study>\"}."
      )
    ))
  }
  # Defined in status.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  locked_r <- lockfile_r_version(root)
  if (!is.na(locked_r) && !identical(locked_r, as.character(getRversion()))) {
    cli::cli_alert_warning(paste(
      "This study's {.file renv.lock} was made under R {locked_r};",
      "this session runs R {getRversion()}, and the snapshot will record",
      "R {getRversion()}."
    ))
  }
  # Defined in status.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  if (!renv_available()) {
    pak_install("renv")
    # nolint next: object_usage_linter.
    if (!renv_available()) {
      cli::cli_abort(c(
        "{.pkg renv} is required and could not be installed.",
        i = 'Install it with {.code install.packages("renv")}, then try again.'
      ))
    }
  }
  set_workspace_prefs()

  lock_path <- file.path(root, "renv.lock")
  locked <- character(0)
  if (file.exists(lock_path)) {
    read <- run_in_study(locked_expr(root), root)
    line <- grep("^HVTIR_LOCKED=", strsplit(read$output, "\n")[[1L]],
                 value = TRUE)
    if (read$status != 0L || length(line) != 1L) {
      cli::cli_abort(c(
        "Could not read the packages {.file renv.lock} records.",
        x = "{tail_lines(read$output)}"
      ))
    }
    locked <- strsplit(sub("^HVTIR_LOCKED=", "", line), ",", fixed = TRUE)[[1L]]
  }

  status <- utilities_fn("study_setup")(
    root = root, study = study, study_tracker_id = study_tracker_id,
    adopt = adopt, renv = TRUE, ...
  )
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)

  packages <- union(declared_packages(), setdiff(locked, "renv"))
  utilities_fn("study_declare")(packages, root = root)

  cli::cli_alert_info(
    "Installing the study's packages; this can take several minutes."
  )
  result <- run_in_study(install_expr(root, packages), root)
  if (result$status != 0L) {
    cli::cli_abort(c(
      "Installing the study's packages failed.",
      x = "{tail_lines(result$output)}"
    ))
  }
  lib <- sub(
    "^HVTIR_LIB=", "",
    grep("^HVTIR_LIB=", strsplit(result$output, "\n")[[1L]], value = TRUE)
  )
  if (length(lib) != 1L || !dir.exists(lib)) {
    cli::cli_abort(c(
      "The install did not report the study's library path.",
      x = "{tail_lines(result$output)}"
    ))
  }
  # Defined in status.R; lintr cannot resolve it across source files.
  # nolint next: object_usage_linter.
  gone <- unresolved_imports(packages, lib_loc = c(lib, .Library))
  if (nrow(gone)) {
    bullets <- paste(gone$package, "needs", gone$missing)
    names(bullets) <- rep("x", nrow(gone))
    cli::cli_abort(c(
      "Packages in the study's library are missing dependencies:",
      bullets
    ))
  }

  cli::cli_alert_success("The study's environment is set up.")
  open_project(root)
  invisible(status)
}
