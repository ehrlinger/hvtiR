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

#' The last lines of a child's output, safe to hand to cli
#'
#' Child output carries carriage-return progress, ANSI escapes and
#' sometimes invalid UTF-8, none of which cli's wrapping tolerates. Braces
#' are doubled so glue prints them rather than evaluating them.
#' @param output One string.
#' @param n Lines to keep.
#' @return Character vector, one element per line.
#' @noRd
tail_lines <- function(output, n = 40L) {
  output <- iconv(paste(output, collapse = "\n"), "UTF-8", "UTF-8", sub = "?")
  lines <- cli::ansi_strip(unlist(strsplit(output, "[\r\n]+")))
  lines <- lines[nzchar(trimws(lines))]
  lines <- gsub("\\}", "}}", gsub("\\{", "{{", lines))
  utils::tail(lines, n)
}

#' Bullets for a child's output, one `x` bullet per line
#' @noRd
output_bullets <- function(output, n = 40L) {
  lines <- tail_lines(output, n)
  names(lines) <- rep("x", length(lines))
  lines
}

#' Save a child's full raw output where the abort can name it
#' @noRd
save_setup_log <- function(output) {
  path <- file.path(
    tempdir(), paste0("hvtiR-setup-", format(Sys.time(), "%Y%m%d-%H%M%S"),
                      ".log")
  )
  writeBin(charToRaw(enc2native(paste0(output, collapse = "\n"))), path)
  path
}

#' Is `path` inside `dir`?
#' @noRd
path_within <- function(path, dir) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  dir <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  identical(path, dir) || startsWith(path, paste0(sub("/$", "", dir), "/"))
}

#' Subdirectory remotes the members pin
#'
#' Parses a DESCRIPTION `Remotes` field and keeps the GitHub entries whose repo
#' has a subdirectory, `[name=]owner/repo/subdir[@ref]`. See [subdir_remotes()]
#' for why they are wanted.
#' @param remotes The `Remotes` field, one string (entries separated by commas
#'   or newlines), or `NA`/`NULL`.
#' @return A character vector of specs, named by the package each installs
#'   (the `name=` part, else the subdirectory's last component).
#' @noRd
parse_subdir_remotes <- function(remotes) {
  if (length(remotes) != 1L || is.na(remotes)) return(character(0))
  entries <- trimws(strsplit(remotes, "[,\n]")[[1L]])
  entries <- entries[nzchar(entries)]
  # `owner/repo/subdir[@ref]`, optionally `name=` and `github::`. Any other
  # host (`gitlab::`, `url::`) carries a colon and falls out here.
  pattern <- paste0(
    "^(?:([A-Za-z0-9_.]+)=)?(?:github::)?",
    "[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/([A-Za-z0-9_./-]+)(?:@\\S+)?$"
  )
  hit <- grepl(pattern, entries, perl = TRUE)
  entries <- entries[hit]
  name <- sub(pattern, "\\1", entries, perl = TRUE)
  subdir <- sub(pattern, "\\2", entries, perl = TRUE)
  name[!nzchar(name)] <- basename(subdir[!nzchar(name)])
  names(entries) <- name
  entries[!duplicated(entries)]
}

#' Subdirectory remotes that the members' DESCRIPTIONs pin
#'
#' Workaround for a renv 1.2.4 bug in `renv_graph_install()`: a package with a
#' `RemoteSubdir` (such as boostmtree, which ggBoostedTrees pins to a
#' subdirectory of `boostmtree_src`) must be unpacked before it builds. When it
#' becomes ready while every install slot is busy it is unpacked into staging,
#' then prepared again on the next pass and fails "target file ... already
#' exists". That needs a cold renv cache, which is every new study. Installing
#' these packages in a first, separate `renv::install()` call means the main
#' call finds them satisfied and never takes the unpack path. The pins are read
#' from GitHub, not written here, because the tags move. Remove this, and the
#' first install call in [install_expr()], once renv fixes the bug.
#'
#' A member whose DESCRIPTION cannot be read is named in a warning, not
#' skipped silently: the main install may still succeed on a warm cache.
#' @param registry The registry, as returned by [members()].
#' @return A character vector of specs named by package, without duplicates.
#' @noRd
subdir_remotes <- function(registry = members()) {
  found <- character(0)
  for (i in seq_len(nrow(registry))) {
    dcf <- fetch_description(registry$repo[i])
    if (is.null(dcf)) {
      cli::cli_warn(c(
        "Could not read {.pkg {registry$package[i]}}'s DESCRIPTION.",
        i = paste(
          "Its subdirectory remotes cannot be installed ahead of the rest;",
          "the install may fail on a cold {.pkg renv} cache."
        )
      ))
      next
    }
    remotes <- if ("Remotes" %in% colnames(dcf)) dcf[1L, "Remotes"] else NA
    found <- c(found, parse_subdir_remotes(remotes))
  }
  found[!duplicated(found)]
}

#' A GitHub token from the git credential store
#' @return The token, or `NULL` when there is none.
#' @noRd
gitcreds_token <- function() {
  if (!requireNamespace("gitcreds", quietly = TRUE)) return(NULL)
  tryCatch(
    gitcreds::gitcreds_get("https://github.com")$password,
    error = function(e) NULL
  )
}

#' Can renv reach GitHub with credentials?
#'
#' renv has no token of its own (pak's bundled one does not reach it), and
#' GitHub's anonymous API limit stops an install of this size. The child
#' inherits this session's environment, so a `GITHUB_PAT` is enough.
#' @return `TRUE` or `FALSE`.
#' @noRd
github_credentials_available <- function() {
  nzchar(Sys.getenv("GITHUB_PAT")) || !is.null(gitcreds_token())
}

#' How to give renv a GitHub token
#' @noRd
github_credentials_hint <- function() {
  c(
    i = paste(
      "Create a token with {.code usethis::create_github_token()},",
      "scope {.val repo}."
    ),
    i = paste(
      "Put {.code GITHUB_PAT=<token>} in {.file ~/.Renviron}",
      "({.code usethis::edit_r_environ()})."
    ),
    i = "Restart R, then check {.code nzchar(Sys.getenv(\"GITHUB_PAT\"))}."
  )
}

#' The child's check that no locked package moved
#'
#' A locked dependency can be upgraded to satisfy a newly declared package, and
#' the snapshot would then record it. Compares each locked version with the
#' project library; on a difference restores those packages, reports them and
#' exits 3 without snapshotting.
#' @param p The study root, deparsed.
#' @return One string of R code.
#' @noRd
guard_expr <- function(p) {
  paste0(
    "now <- vapply(names(before), function(n) tryCatch(",
    "as.character(utils::packageVersion(n, lib.loc = .libPaths()[1L])), ",
    "error = function(e) NA_character_), ''); ",
    "changed <- names(before)[is.na(now) | now != before]; ",
    "if (length(changed)) { ",
    "renv::restore(project = ", p, ", packages = changed, prompt = FALSE); ",
    "cat('\\nHVTIR_CHANGED=', paste0(changed, ':', before[changed], '->', ",
    "now[changed], collapse = ','), '\\n', sep = ''); ",
    "quit(status = 3L, save = 'no') }; "
  )
}

#' Entries of a library that block renv and pak
#'
#' A study's `renv/library` is shared by the team, but renv's default cache is
#' per user, so the library fills with symlinks into home caches that a
#' teammate cannot read. pak sees such a link as "not installed" and cannot
#' replace it. Base R only: [unlink_expr()] ships this function to the child.
#' A failed pak install also leaves its staging directory, `_cache`, a real
#' directory without a `DESCRIPTION`, which renv then trips over on every scan.
#' @param lib A library path.
#' @return Names of the entries: `_cache` when it is that leftover, then each
#'   symlink whose target is missing or unreadable.
#' @noRd
# Package constant, spelled like MIN_R_VERSION.
# nolint next: object_name_linter.
DEBRIS_SRC <- paste(
  "function(lib) {",
  "entries <- list.files(lib, all.files = TRUE, no.. = TRUE);",
  "path <- file.path(lib, entries);",
  "link <- nzchar(Sys.readlink(path));",
  "dead <- link & (!file.exists(path) | file.access(path, 4L) != 0L |",
  "(dir.exists(path) & file.access(path, 1L) != 0L));",
  "staging <- entries == '_cache' & !link & dir.exists(path) &",
  "!file.exists(file.path(path, 'DESCRIPTION'));",
  "c(entries[staging], entries[dead]) }"
)
library_debris <- eval(parse(text = DEBRIS_SRC))

#' The child's code to clear [library_debris()] from the project library
#'
#' Removes each link itself, never its target and never recursively; the one
#' real directory it removes is pak's `_cache`. Prints `HVTIR_UNLINKED=` with
#' the names when it removed any; the following restore reinstalls them.
#' @param lib_var Name of the child's variable holding the library path.
#' @return One string of R code.
#' @noRd
unlink_expr <- function(lib_var) {
  paste0(
    "library_debris <- ", DEBRIS_SRC, "; ",
    "gone <- library_debris(", lib_var, "); ",
    "for (g in gone) { x <- file.path(", lib_var, ", g); ",
    "if (nzchar(Sys.readlink(x))) file.remove(x) else ",
    "unlink(x, recursive = TRUE) }; ",
    "if (length(gone)) cat('\\nHVTIR_UNLINKED=', ",
    "paste(gone, collapse = ','), '\\n', sep = ''); "
  )
}

#' The child process's install step
#' @param root The study root.
#' @param packages Declared package names.
#' @param subdir Subdirectory remotes, as from [subdir_remotes()]; installed in
#'   a separate first call (see there for why), when not in the lockfile.
#' @return One string of R code.
#' @noRd
install_expr <- function(root, packages, subdir = character(0)) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  names_ <- deparse1(packages, width.cutoff = 500L)
  specs <- deparse1(install_specs(packages), width.cutoff = 500L)
  first <- ""
  if (length(subdir)) {
    first <- paste0(
      "pre <- ", deparse1(unname(subdir), width.cutoff = 500L), "; ",
      "pre <- pre[!", deparse1(names(subdir), width.cutoff = 500L),
      " %in% locked]; ",
      "if (length(pre)) renv::install(pre, project = ", p,
      ", prompt = FALSE); "
    )
  }
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    "lib <- renv::paths$library(project = ", p, "); ",
    # Clear first: a leftover `_cache` makes renv's own library scan fail.
    unlink_expr("lib"),
    "renv::settings$use.cache(FALSE, project = ", p, "); ",
    "renv::isolate(project = ", p, "); ",
    "renv::settings$snapshot.type('explicit', project = ", p, "); ",
    "renv::restore(project = ", p, ", prompt = FALSE); ",
    "before <- vapply(renv::lockfile_read(file.path(", p, ", 'renv.lock'))",
    "$Packages, function(x) as.character(x$Version), ''); ",
    "locked <- names(before); ",
    first,
    "add <- ", specs, "[!", names_, " %in% locked]; ",
    "if (length(add)) renv::install(add, project = ", p, ", prompt = FALSE); ",
    guard_expr(p),
    "renv::snapshot(project = ", p, ", prompt = FALSE); ",
    "cat('\\nHVTIR_LIB=', .libPaths()[1L], '\\n', sep = '')"
  )
}

#' The study root, found without installing anything
#'
#' Used by the guard in [setup()], which must run before anything can install.
#' The active renv project when there is one, else the study enclosing the
#' working directory if `hvtiRutilities` is already installed (any version),
#' else the working directory.
#' @return A path.
#' @noRd
cheap_study_root <- function() {
  project <- Sys.getenv("RENV_PROJECT", "")
  if (nzchar(project)) return(project)
  if (is.na(installed_version("hvtiRutilities"))) return(getwd())
  study_root_or_wd(getExportedValue("hvtiRutilities", "study_root"))
}

#' Call `study_root`, falling back to the working directory outside a study
#' @param study_root The function.
#' @noRd
study_root_or_wd <- function(study_root) {
  tryCatch(study_root(), error = function(e) {
    # hvtiRutilities' exact wording; any other error is real.
    if (!grepl("no _study.yml found", conditionMessage(e), fixed = TRUE)) {
      stop(e)
    }
    getwd()
  })
}

#' Refuse to run from inside the study
#'
#' `setup()` replaces packages this session has loaded and would install into
#' the study library through this session.
#' @param root The study root, or `NULL`.
#' @param study,study_tracker_id,adopt As passed to [setup()], quoted back in
#'   the command the message offers.
#' @noRd
guard_session <- function(root, study, study_tracker_id,
                          adopt = FALSE) {
  active <- renv_state() == "active"
  guess <- if (is.null(root)) cheap_study_root() else root
  if (!active && !path_within(session_library(), guess)) return(invisible())
  # Read by cli's glue below, which lintr cannot see.
  # nolint next: object_usage_linter.
  target <- if (is.null(root) && nzchar(Sys.getenv("RENV_PROJECT", ""))) {
    Sys.getenv("RENV_PROJECT")
  } else {
    guess
  }
  # Read by cli's glue below, which lintr cannot see.
  # nolint next: object_usage_linter.
  cmd <- paste0(
    "hvtiR::setup(root = ", deparse1(target), ", study = ", deparse1(study),
    ", study_tracker_id = ", deparse1(study_tracker_id),
    if (isTRUE(adopt)) ", adopt = TRUE", ")"
  )
  cli::cli_abort(c(
    paste(
      "{.fn setup} replaces packages this session has loaded, and would",
      "install into the study's library through this session."
    ),
    i = "Run it from a session started outside any project: {.code {cmd}}",
    i = paste(
      "In RStudio, File > Close Project; check that",
      "{.code Sys.getenv(\"RENV_PROJECT\")} is empty."
    )
  ))
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
#' session started outside the study project, passing `root`. From inside
#' the project it stops before installing anything, and names the command to
#' run.
#'
#' In the install, the study stops using renv's per-user cache
#' (`renv::settings$use.cache(FALSE)`, kept in `renv/settings.json`, so it
#' applies to everyone), links already in the library are copied in
#' (`renv::isolate()`), and any link whose target the user cannot read is
#' removed, as is pak's leftover `_cache` directory, and the package
#' reinstalled. A shared library cannot depend on one user's home.
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
#' setup(
#'   study = "Study Tracker title", study_tracker_id = 1234L,
#'   root = "/studies/example"
#' )
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
  guard_session(root, study, study_tracker_id, adopt)
  if (is.null(root)) {
    root <- study_root_or_wd(utilities_fn("study_root"))
  }
  if (!github_credentials_available()) {
    cli::cli_abort(c(
      "{.pkg renv} needs a GitHub token to install the family.",
      github_credentials_hint()
    ))
  }
  if (!nzchar(Sys.getenv("GITHUB_PAT"))) {
    token <- gitcreds_token()
    if (!is.null(token)) {
      Sys.setenv(GITHUB_PAT = token)
      on.exit(Sys.unsetenv("GITHUB_PAT"), add = TRUE)
    }
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
        output_bullets(read$output)
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
  result <- run_in_study(
    install_expr(root, packages, subdir = subdir_remotes()), root
  )
  raw_output <- result$output
  result$output <- iconv(raw_output, "UTF-8", "UTF-8", sub = "?")
  unlinked <- grep("^HVTIR_UNLINKED=", strsplit(result$output, "\n")[[1L]],
                   value = TRUE)
  moved <- grep("^HVTIR_CHANGED=", strsplit(result$output, "\n")[[1L]],
                value = TRUE)
  if (length(moved)) {
    moves <- strsplit(sub("^HVTIR_CHANGED=", "", moved[1L]), ",",
                      fixed = TRUE)[[1L]]
    moves <- gsub("\\}", "}}", gsub("\\{", "{{", moves))
    names(moves) <- rep("x", length(moves))
    cli::cli_abort(c(
      "Installing the declared packages would have moved locked versions.",
      moves,
      i = paste(
        "A newly declared package needs newer versions of packages the",
        "lockfile pins. {.file renv.lock} was left unchanged and the locked",
        "versions were restored."
      ),
      i = "{.fn update} is the deliberate way to move a study's versions."
    ))
  }
  if (result$status != 0L) {
    auth <- grepl("authentication credentials", result$output, fixed = TRUE)
    cli::cli_abort(c(
      "Installing the study's packages failed.",
      if (auth) c("renv has no GitHub token.", github_credentials_hint()),
      output_bullets(result$output),
      i = "Full output: {.file {save_setup_log(raw_output)}}"
    ))
  }
  if (length(unlinked)) {
    gone <- strsplit(sub("^HVTIR_UNLINKED=", "", unlinked[1L]), ",",
                     fixed = TRUE)[[1L]]
    cli::cli_alert_info(paste(
      "Removed {length(gone)} unreadable cache link{?s} from the study's",
      "library and reinstalled: {.pkg {gone}}."
    ))
  }
  lib <- sub(
    "^HVTIR_LIB=", "",
    grep("^HVTIR_LIB=", strsplit(result$output, "\n")[[1L]], value = TRUE)
  )
  if (length(lib) != 1L || !dir.exists(lib)) {
    cli::cli_abort(c(
      "The install did not report the study's library path.",
      output_bullets(result$output),
      i = "Full output: {.file {save_setup_log(raw_output)}}"
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
