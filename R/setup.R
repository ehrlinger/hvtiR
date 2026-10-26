#' Packages a study needs beyond the members
#'
#' Two groups, kept here beside [members()] so one place owns the list. First,
#' Suggested packages that members' study-facing functions use: `arrow` reads
#' and writes registered data, and `quarto` renders a job, so
#' `hvtiRtemplates::render_job()` and `submit_job()` stop without it. No member
#' imports `quarto`, so a study that installed it by hand still left it out of
#' its lockfile. `ggiraph` gives the `dc-eda` template its hover figures; the
#' template falls back to static ones without it, which is why nothing else
#' declares it. Second, the standard analysis set the team
#' Quick Start used to install by hand, approved for every study on 2026-10-21.
#' renv runs in explicit mode, so a package reaches the lockfile only when the
#' study declares it or something declared needs it.
#'
#' Several of the standard set already arrive as member dependencies
#' (`gtsummary` and `flextable` through hvtiRtables, `randomForestSRC` and
#' `varPro` through ggRandomForests, `haven` and `survival` through several).
#' They are declared anyway: study code calls them directly, and a member
#' dropping one must not drop it from every study's lockfile. All are CRAN
#' packages, so [install_specs()] passes them through to the configured
#' repositories.
#'
#' @return A character vector of package names.
#' @noRd
environment_extras <- function() {
  c(
    "arrow", "quarto", "ggiraph",
    "tidyverse", "haven", "gtsummary", "flextable", "survival", "survminer",
    "randomForestSRC", "varPro", "pacman"
  )
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
  # A file, not `-e`: R truncates a long -e argument, and the code embeds the
  # locked versions of every package, which runs to tens of kilobytes.
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  con <- file(script, open = "w", encoding = "UTF-8")
  writeLines(expr, con)
  close(con)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)),
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
    ")$Packages), collapse = ','), '\\n', sep = ''); ",
    "repos <- tryCatch(unlist(renv::lockfile_read(", p,
    ")$R$Repositories), error = function(e) NULL); ",
    "if (!length(repos)) repos <- getOption('repos'); ",
    "repos <- repos[!is.na(repos) & nzchar(repos) & repos != '@CRAN@']; ",
    "cat('HVTIR_REPOS=', if (length(repos)) paste0(names(repos), '=', repos, ",
    "collapse = ';'), '\\n', sep = '')"
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

#' Does this session have a personal GitHub token?
#'
#' Installs do not need one: pak ships a shared token. renv has none, so a
#' restore of a GitHub-locked package may. The children inherit this session's
#' environment, so a `GITHUB_PAT` serves both pak and renv.
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

#' The child's code to remove the packages this run added
#'
#' pak's additions are not in the locked state. After a guard trip they stay
#' behind unless removed, and the library would no longer match the lockfile.
#' Only directories with a `DESCRIPTION` that were not in `pkgs_var` go: they
#' were created by this run. A link is removed itself, never its target. A
#' `NULL` list (child 1 did not report one) removes nothing.
#' @param lib_var Name of the child's variable holding the library path.
#' @param pkgs_var Name of the variable holding the package directories the
#'   library had after the restore.
#' @return One string of R code.
#' @noRd
cleanup_expr <- function(lib_var, pkgs_var) {
  paste0(
    "if (!is.null(", pkgs_var, ")) { ",
    "ents <- list.files(", lib_var, "); ",
    "ents <- ents[file.exists(file.path(", lib_var,
    ", ents, 'DESCRIPTION'))]; ",
    "for (a in setdiff(ents, ", pkgs_var, ")) { x <- file.path(", lib_var,
    ", a); if (nzchar(Sys.readlink(x))) file.remove(x) else ",
    "unlink(x, recursive = TRUE) } }; "
  )
}

#' The child's check that no locked package moved
#'
#' A locked dependency can be upgraded to satisfy a newly declared package, and
#' the snapshot would then record it. Compares each locked package's `Version`
#' and, where the lockfile records one, `RemoteSha` with the project library.
#' On a difference it removes what this run added ([cleanup_expr()]), restores
#' the moved packages, reports them and exits 3 without snapshotting. A restore
#' that fails is reported as `HVTIR_RESTOREFAIL=`; the exit is still 3.
#' With `upgrade` the moves are reported as `HVTIR_MOVED=` and nothing rolls
#' back. Expects `lib`, `before` (locked versions), `sha` (locked
#' `RemoteSha`s, `""` when none), `libpkgs` and `upgrade` in the child.
#' @param p The study root, deparsed.
#' @return One string of R code.
#' @noRd
guard_expr <- function(p) {
  paste0(
    # Recommended packages (mgcv, nlme, ...) live in R's system library, so
    # look across every library on the path, the project's first.
    "paths <- unique(c(lib, .libPaths())); ",
    "from_desc <- function(n, f) tryCatch({ ",
    "d <- find.package(n, lib.loc = paths, quiet = TRUE)[1L]; ",
    "if (is.na(d)) return(NA_character_); ",
    "read.dcf(file.path(d, 'DESCRIPTION'), fields = f)[1L, 1L] }, ",
    "error = function(e) NA_character_); ",
    "now <- vapply(names(before), from_desc, '', f = 'Version'); ",
    "nowsha <- vapply(names(before), function(n) { ",
    "s <- from_desc(n, 'RemoteSha'); if (is.na(s)) '' else s }, ''); ",
    "lsha <- sha[names(before)]; ",
    "bysha <- !is.na(lsha) & nzchar(lsha) & nowsha != lsha; ",
    # "1.2-5" and "1.2.5" are one version: compare as versions, not strings.
    "moved <- vapply(names(before), function(n) is.na(now[[n]]) || ",
    "!isTRUE(tryCatch(package_version(now[[n]]) == package_version(",
    "before[[n]]), error = function(e) now[[n]] == before[[n]])), NA); ",
    "changed <- names(before)[moved | bysha]; ",
    "if (length(changed)) { ",
    "moves <- paste0(changed, ':', before[changed], '->', ",
    "now[changed], ifelse(bysha[changed], paste0(' (RemoteSha ', ",
    "substr(lsha[changed], 1L, 7L), '->', substr(nowsha[changed], 1L, 7L), ",
    "')'), ''), collapse = ','); ",
    "if (upgrade) { ",
    "cat('\\nHVTIR_MOVED=', moves, '\\n', sep = '') } else { ",
    cleanup_expr("lib", "libpkgs"),
    "tryCatch(renv::restore(project = ", p, ", packages = changed, ",
    "prompt = FALSE), error = function(e) { ",
    "cat('\\nHVTIR_RESTOREFAIL=', paste(changed, collapse = ','), '\\n', ",
    "sep = ''); ",
    "cat('HVTIR_RESTOREERR=', gsub('[\\r\\n]+', ' ', conditionMessage(e)), ",
    "'\\n', sep = '') }); ",
    "cat('\\nHVTIR_CHANGED=', moves, '\\n', sep = ''); ",
    "quit(status = 3L, save = 'no') } }; "
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
  "desc <- file.path(path, 'DESCRIPTION');",
  "dead <- link & (!file.exists(path) | file.access(path, 4L) != 0L |",
  "(dir.exists(path) & file.access(path, 1L) != 0L) |",
  "(file.exists(desc) & file.access(desc, 4L) != 0L));",
  "staging <- entries == '_cache' & !link & dir.exists(path) &",
  "!file.exists(file.path(path, 'DESCRIPTION'));",
  "c(entries[staging], entries[dead]) }"
)
library_debris <- eval(parse(text = DEBRIS_SRC))

#' Real packages in a library whose `DESCRIPTION` the user cannot read
#'
#' These belong to a teammate and are not ours to delete, so setup stops and
#' names them. Base R only: [unreadable_expr()] ships it to the child.
#' @param lib A library path.
#' @return Names of the package directories (not links) with an existing but
#'   unreadable `DESCRIPTION`.
#' @noRd
# Package constant, spelled like MIN_R_VERSION.
# nolint next: object_name_linter.
UNREADABLE_SRC <- paste(
  "function(lib) {",
  "entries <- list.files(lib, all.files = TRUE, no.. = TRUE);",
  "path <- file.path(lib, entries);",
  "desc <- file.path(path, 'DESCRIPTION');",
  "entries[!nzchar(Sys.readlink(path)) & dir.exists(path) &",
  "file.exists(desc) & file.access(desc, 4L) != 0L] }"
)
library_unreadable <- eval(parse(text = UNREADABLE_SRC))

#' The child's code to stop on [library_unreadable()] packages
#' @param lib_var Name of the child's variable holding the library path.
#' @return One string of R code.
#' @noRd
unreadable_expr <- function(lib_var) {
  paste0(
    "library_unreadable <- ", UNREADABLE_SRC, "; ",
    "bad <- library_unreadable(", lib_var, "); ",
    "if (length(bad)) { cat('\\nHVTIR_UNREADABLE=', ",
    "paste(bad, collapse = ','), ",
    "'\\n', sep = ''); quit(status = 4L, save = 'no') }; "
  )
}

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

#' Rewrite study repositories to the session's binary form of the same ones
#'
#' Posit Package Manager serves one snapshot as source at `<base>/<snapshot>`
#' and as binaries at `<base>/__linux__/<distro>/<snapshot>`. A study's
#' lockfile often records the source form, and installing from it compiles
#' every package, which some cannot do with a server's default compiler. A
#' study repository is replaced only by a session repository that is exactly
#' its `__linux__/<distro>/` form: same scheme, host, port, path and
#' snapshot. The distro is never guessed and the snapshot never changed.
#'
#' Self-contained base R, because the children evaluate its deparsed source.
#' @param study The study's repositories, a named character vector.
#' @param session The session's repositories, e.g. `getOption("repos")`.
#' @return `study`, with each repository swapped for its binary form when the
#'   session has one.
#' @noRd
binary_repos <- function(study, session) {
  session <- as.character(session)
  for (i in seq_along(study)) {
    parts <- regmatches(
      study[[i]],
      regexec("^(https?://[^/]+(?:/[^/]+)*)/([^/]+)/?$", study[[i]],
              perl = TRUE)
    )[[1L]]
    if (length(parts) != 3L) next
    pre <- paste0(parts[[2L]], "/__linux__/")
    post <- paste0("/", parts[[3L]])
    cand <- sub("/$", "", session)
    mid <- substring(cand, nchar(pre) + 1L, nchar(cand) - nchar(post))
    found <- startsWith(cand, pre) & endsWith(cand, post) &
      nchar(cand) > nchar(pre) + nchar(post) &
      nzchar(mid) & !grepl("/", mid, fixed = TRUE)
    if (any(found)) study[[i]] <- session[found][[1L]]
  }
  study
}

#' Child code that sets the repositories for the run
#'
#' `renv::load()` resets `repos` from the lockfile, so this follows it.
#' @param repos A named character vector, or `NULL` for nothing.
#' @return One string of R code, defining `hvtir_repos`.
#' @noRd
repos_expr <- function(repos) {
  if (!length(repos)) return("")
  paste0(
    "hvtir_repos <- ", deparse1(c(repos), width.cutoff = 500L), "; ",
    "options(repos = hvtir_repos); "
  )
}

#' Parse the `HVTIR_REPOS` line a child reports
#' @param x The line's value, `name=url;name=url`, or empty.
#' @return A named character vector, or `NULL`.
#' @noRd
parse_repos <- function(x) {
  if (length(x) != 1L || !nzchar(x)) return(NULL)
  pairs <- strsplit(strsplit(x, ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
  stats::setNames(
    vapply(pairs, function(p) paste(p[-1L], collapse = "="), ""),
    vapply(pairs, `[`, "", 1L)
  )
}

#' Child run 1: restore the lockfile, report the library and locked versions
#' @param root The study root.
#' @param repos The repositories to restore from, or `NULL` to leave renv's.
#' @return One string of R code.
#' @noRd
restore_expr <- function(root, repos = NULL) {
  p <- deparse1(normalizePath(root, winslash = "/"))
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    repos_expr(repos),
    "lib <- renv::paths$library(project = ", p, "); ",
    unreadable_expr("lib"),
    # Clear first: a leftover `_cache` makes renv's own library scan fail.
    unlink_expr("lib"),
    "renv::settings$use.cache(FALSE, project = ", p, "); ",
    "renv::isolate(project = ", p, "); ",
    "renv::settings$snapshot.type('explicit', project = ", p, "); ",
    "renv::restore(project = ", p, ", prompt = FALSE",
    if (length(repos)) ", repos = hvtir_repos", "); ",
    "locked <- renv::lockfile_read(file.path(", p, ", 'renv.lock'))$Packages; ",
    "cat('\\nHVTIR_LIB=', lib, '\\n', sep = ''); ",
    # name:version:RemoteSha, the sha empty when the record has none.
    "cat('HVTIR_LOCKVER=', if (length(locked)) paste0(names(locked), ':', ",
    "vapply(locked, function(x) as.character(x$Version), ''), ':', ",
    "vapply(locked, function(x) if (is.null(x$RemoteSha)) '' else ",
    "as.character(x$RemoteSha), ''), collapse = ','), '\\n', sep = ''); ",
    # The library as the lockfile left it: what a guard trip must go back to.
    "ents <- list.files(lib); ",
    "cat('HVTIR_LIBPKGS=', paste(ents[file.exists(file.path(lib, ents, ",
    "'DESCRIPTION'))], collapse = ','), '\\n', sep = '')"
  )
}

#' The child's code to install the build-time dependencies pak skips
#'
#' pak installs hard dependencies but not `LinkingTo` packages, and the
#' snapshot's validation then aborts. Those are CRAN packages, which renv
#' installs from the configured repositories with no GitHub API.
#' @param lib_var Name of the child's variable holding the library path.
#' @param project The study root.
#' @param installer The function that installs, called as `installer(need,
#'   project =, prompt =)`; a test passes the name of its own.
#' @param repos The repositories to install from, or `NULL` for renv's; the
#'   child must have set `hvtir_repos` (see [repos_expr()]).
#' @return One string of R code.
#' @noRd
linking_expr <- function(lib_var, project, installer = "renv::install",
                         repos = NULL) {
  p <- deparse1(project)
  paste0(
    "d <- file.path(", lib_var, ", list.files(", lib_var,
    "), 'DESCRIPTION'); d <- d[file.exists(d)]; ",
    "lt <- as.character(unlist(lapply(d, function(f) tryCatch(",
    "read.dcf(f, fields = 'LinkingTo')[, 'LinkingTo'], ",
    "error = function(e) NA_character_)))); ",
    "lt <- trimws(sub('[(].*$', '', unlist(strsplit(lt[!is.na(lt)], ',')))); ",
    "lt <- unique(lt[nzchar(lt) & lt != 'R']); ",
    "need <- lt[!vapply(lt, function(n) length(find.package(n, lib.loc = c(",
    lib_var, ", .Library), quiet = TRUE)) > 0L, NA)]; ",
    "if (length(need)) ", installer, "(need, project = ", p,
    ", prompt = FALSE", if (length(repos)) ", repos = hvtir_repos", "); "
  )
}

#' Unmet version requirements among a library's packages
#'
#' Reads `Depends`, `Imports` and `LinkingTo` of every package in `lib`, finds
#' each required package across `paths` and keeps the requirements the
#' installed version does not meet (`>=`, `>`, `==`). A required package that
#' is absent is unmet. R and the base packages are skipped. Versions compare as
#' versions, so `1.2-5` is `1.2.5`. Base R only: [floors_expr()] ships it to
#' the child.
#' @param lib A library path.
#' @param paths Libraries to look for the required packages in.
#' @return A data frame of `by`, `dep`, `op`, `ver`, `has`; no rows when all
#'   are met.
#' @noRd
unmet_requirements <- function(lib, paths = unique(c(lib, .libPaths()))) {
  base_pkgs <- c(
    "R", "base", "compiler", "datasets", "graphics", "grDevices", "grid",
    "methods", "parallel", "splines", "stats", "stats4", "tcltk", "tools",
    "utils"
  )
  desc <- file.path(lib, list.files(lib), "DESCRIPTION")
  rows <- lapply(desc[file.exists(desc)], function(f) {
    x <- tryCatch(
      read.dcf(f, fields = c("Package", "Depends", "Imports", "LinkingTo")),
      error = function(e) NULL
    )
    if (is.null(x)) return(NULL)
    spec <- unlist(strsplit(paste(x[1L, 2:4][!is.na(x[1L, 2:4])],
                                  collapse = ","), ","))
    spec <- trimws(gsub("\\s+", " ", spec))
    spec <- spec[nzchar(spec)]
    if (!length(spec)) return(NULL)
    has_ver <- grepl("(", spec, fixed = TRUE)
    data.frame(
      by = unname(x[1L, 1L]),
      dep = trimws(sub("[(].*$", "", spec)),
      op = ifelse(has_ver, sub("^[^(]*[(] ?([<>=!]+).*$", "\\1", spec), ""),
      ver = ifelse(has_ver,
                   sub("^[^(]*[(][^0-9]*([0-9][0-9.-]*).*$", "\\1", spec), ""),
      stringsAsFactors = FALSE
    )
  })
  req <- do.call(rbind, rows)
  none <- data.frame(by = character(), dep = character(), op = character(),
                     ver = character(), has = character(),
                     stringsAsFactors = FALSE)
  if (is.null(req)) return(none)
  known <- req$op %in% c("", ">=", ">", "==")
  req <- req[!req$dep %in% base_pkgs & known, ]
  if (!nrow(req)) return(none)
  req$has <- vapply(req$dep, function(n) {
    d <- find.package(n, lib.loc = paths, quiet = TRUE)[1L]
    if (is.na(d)) return(NA_character_)
    tryCatch(read.dcf(file.path(d, "DESCRIPTION"), fields = "Version")[1L, 1L],
             error = function(e) NA_character_)
  }, "")
  met <- vapply(seq_len(nrow(req)), function(i) {
    if (is.na(req$has[i])) return(FALSE)
    if (req$op[i] == "") return(TRUE)
    isTRUE(tryCatch(
      do.call(req$op[i], list(package_version(req$has[i]),
                              package_version(req$ver[i]))),
      error = function(e) TRUE
    ))
  }, NA)
  req <- req[!met, ]
  rownames(req) <- NULL
  req
}

#' The child's step that resolves unmet version requirements
#'
#' renv's snapshot validates the library and aborts on any package whose
#' installed version is below what another package requires; some of those
#' pre-exist in a study library. With `upgrade` the unmet packages are
#' installed through renv from the binary repositories, the library is checked
#' once more, and `HVTIR_RAISED=` names what was installed. Whatever is still
#' unmet, or all of it when not `upgrade`, is printed as `HVTIR_UNMET=` (entries
#' separated by `;`, as an entry holds a comma) and the child exits 5 before
#' the snapshot. The lock guard that follows sees the installs, so a locked
#' package they moved is reported there. Expects `lib` and `upgrade` in the
#' child.
#' @param project The study root.
#' @param installer The function that installs, called as `installer(need,
#'   project =, prompt =)`; a test passes the name of its own.
#' @param repos The repositories to install from, or `NULL` for renv's; the
#'   child must have set `hvtir_repos` (see [repos_expr()]).
#' @return One string of R code.
#' @noRd
floors_expr <- function(project, installer = "renv::install", repos = NULL) {
  p <- deparse1(project)
  paste0(
    "unmet_requirements <- ",
    paste(deparse(unmet_requirements), collapse = "\n"), "\n",
    "unmet <- unmet_requirements(lib); ",
    "if (nrow(unmet) && upgrade) { ",
    installer, "(unique(unmet$dep), project = ", p, ", prompt = FALSE",
    if (length(repos)) ", repos = hvtir_repos", "); ",
    "cat('\\nHVTIR_RAISED=', paste(unique(unmet$dep), collapse = ','), ",
    "'\\n', sep = ''); ",
    "unmet <- unmet_requirements(lib) }; ",
    "if (nrow(unmet)) { cat('\\nHVTIR_UNMET=', paste0(unmet$by, ' needs ', ",
    "unmet$dep, ifelse(nzchar(unmet$op), paste0(' (', unmet$op, ' ', ",
    "unmet$ver, ')'), ''), ', has ', ifelse(is.na(unmet$has), 'none', ",
    "unmet$has), collapse = ';'), '\\n', sep = ''); ",
    "quit(status = 5L, save = 'no') }; "
  )
}

#' Child run 2: fill LinkingTo gaps, meet version floors, guard the lock,
#' snapshot
#'
#' The fill and the floors step go first because they install through renv,
#' which can move a locked package; the guard then sees that too.
#' @param root The study root.
#' @param before Locked versions after restore, named by package.
#' @param sha Locked `RemoteSha`s, named by package, `""` for none.
#' @param libpkgs The library's package directories after the restore, or
#'   `NULL` when unknown (nothing is then removed on a guard trip).
#' @param repos The repositories to install from, or `NULL` to leave renv's.
#' @param record Whether to write `repos` into the lockfile after the
#'   snapshot. renv's snapshot keeps the repositories an existing lockfile
#'   already records, so the rewrite has to follow it.
#' @param upgrade Whether the guard reports moved packages instead of rolling
#'   them back.
#' @return One string of R code.
#' @noRd
finish_expr <- function(root, before, sha = NULL, libpkgs = NULL,
                        repos = NULL, record = FALSE, upgrade = TRUE) {
  root <- normalizePath(root, winslash = "/")
  p <- deparse1(root)
  if (is.null(sha)) {
    sha <- stats::setNames(rep("", length(before)), names(before))
  }
  paste0(
    pak_off(),
    "renv::load(", p, "); ",
    repos_expr(repos),
    "lib <- renv::paths$library(project = ", p, "); ",
    "before <- ", deparse1(before, width.cutoff = 500L), "; ",
    "sha <- ", deparse1(sha, width.cutoff = 500L), "; ",
    "libpkgs <- ", deparse1(libpkgs, width.cutoff = 500L), "; ",
    "upgrade <- ", if (isFALSE(upgrade)) "FALSE" else "TRUE", "; ",
    linking_expr("lib", root, repos = repos),
    floors_expr(root, repos = repos),
    guard_expr(p),
    "renv::snapshot(project = ", p, ", prompt = FALSE); ",
    if (record && length(repos)) {
      paste0(
        "lf <- renv::lockfile_read(file.path(", p, ", 'renv.lock')); ",
        "lf$R$Repositories <- as.list(hvtir_repos); ",
        "renv::lockfile_write(lf, file.path(", p, ", 'renv.lock')); "
      )
    },
    "cat('\\nHVTIR_LIB=', lib, '\\n', sep = '')"
  )
}

#' Install specs with pak into a given library
#' @param specs Install specs.
#' @param lib The library, a study's project library.
#' @param repos The study's repositories, a named character vector, or `NULL`
#'   for this session's.
#' @noRd
pak_install_lib <- function(specs, lib, repos = NULL) {
  if (!requireNamespace("pak", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg pak} package is required to install hvtiR members.",
      i = 'Install it with {.code install.packages("pak")}, then try again.'
    ))
  }
  if (length(repos)) {
    old <- options(repos = repos)
    on.exit(options(old), add = TRUE)
  }
  invisible(pak::pkg_install(
    specs, lib = lib, upgrade = FALSE, ask = FALSE, dependencies = NA
  ))
}

#' Moved packages as cli bullets, the family apart from its dependencies
#' @param moves Entries like `pkg:old->new` with an optional RemoteSha note.
#' @param mark The bullet name for an entry.
#' @param raised Packages the floors step installed to meet a version
#'   requirement. A move of one of these that is not a family package goes in
#'   its own group. The step knows what it asked renv for, not why a package
#'   moved, so a package renv pulled in as a dependency of those installs is
#'   not attributed and stays under the dependencies the family needs.
#' @return A named character vector, escaped for cli; empty groups omitted.
#' @noRd
grouped_moves <- function(moves, mark = "*", raised = character()) {
  pkg <- sub(":.*$", "", moves)
  line <- sub(":", " ", gsub("->", " -> ", moves, fixed = TRUE), fixed = TRUE)
  line <- gsub("\\}", "}}", gsub("\\{", "{{", line))
  fam <- pkg %in% c("hvtiR", members()$package)
  out <- character(0)
  other <- !fam & pkg %in% raised
  for (g in list(list("Family packages", fam),
                 list("Dependencies the family needs", !fam & !other),
                 list("Other unmet requirements resolved", other))) {
    if (any(g[[2L]])) {
      out <- c(out, stats::setNames(g[[1L]], "i"),
               stats::setNames(line[g[[2L]]], rep(mark, sum(g[[2L]]))))
    }
  }
  out
}

#' Report the locked packages an `upgrade = TRUE` run moved
#' @param output The child's output.
#' @noRd
report_moves <- function(output) {
  moved <- child_value(output, "HVTIR_MOVED")
  if (!length(moved)) {
    return(invisible(NULL))
  }
  moves <- strsplit(moved[1L], ",", fixed = TRUE)[[1L]]
  cli::cli_alert_info("Moved {length(moves)} locked package{?s}:")
  raised <- child_value(output, "HVTIR_RAISED")
  raised <- if (length(raised)) {
    strsplit(raised[1L], ",", fixed = TRUE)[[1L]]
  } else {
    character()
  }
  cli::cli_bullets(grouped_moves(moves, raised = raised))
  invisible(NULL)
}

#' Abort for a child run that did not finish
#' @param result A [run_in_study()] result.
#' @param raw The child's raw output.
#' @param upgrade Whether the run was allowed to install what was unmet.
#' @noRd
abort_stage <- function(result, raw, upgrade = TRUE) {
  lines <- strsplit(result$output, "\n")[[1L]]
  moved <- grep("^HVTIR_CHANGED=", lines, value = TRUE)
  if (length(moved)) {
    moves <- strsplit(sub("^HVTIR_CHANGED=", "", moved[1L]), ",",
                      fixed = TRUE)[[1L]]
    moves <- grouped_moves(moves, "x")
    failed <- child_value(result$output, "HVTIR_RESTOREFAIL")
    outcome <- if (length(failed)) {
      err <- child_value(result$output, "HVTIR_RESTOREERR")[1L]
      err <- gsub("\\}", "}}", gsub("\\{", "{{", err))
      c(
        i = paste(
          "{.file renv.lock} was left unchanged and the packages this run",
          "added were removed, but these locked packages could not be",
          "restored: {failed[1L]}."
        ),
        if (!is.na(err)) c(x = err),
        i = paste(
          "Restoring a package the lockfile pins on GitHub needs a personal",
          "token:"
        ),
        github_credentials_hint(),
        i = "Then run {.fn setup} again."
      )
    } else {
      c(i = paste(
        "{.file renv.lock} was left unchanged, the packages this run added",
        "were removed, and the locked versions were restored."
      ))
    }
    cli::cli_abort(c(
      "Installing the declared packages would have moved locked versions.",
      moves,
      i = paste(
        "A newly declared package needs newer versions of packages the",
        "lockfile pins."
      ),
      outcome,
      i = paste(
        "To move them, rerun with {.code upgrade = TRUE} (the default);",
        "{.code upgrade = FALSE} keeps a study in revision on its locked",
        "versions."
      )
    ))
  }
  unmet <- child_value(result$output, "HVTIR_UNMET")
  if (length(unmet)) {
    reqs <- strsplit(unmet[1L], ";", fixed = TRUE)[[1L]]
    reqs <- gsub("\\}", "}}", gsub("\\{", "{{", reqs))
    cli::cli_abort(c(
      "Packages in the study's library do not meet their version requirements:",
      stats::setNames(reqs, rep("x", length(reqs))),
      i = "{.file renv.lock} is unchanged.",
      if (upgrade) {
        c(i = paste(
          "{.fn setup} tried to install the required versions and some are",
          "still unmet. Install them by hand, then run {.fn setup} again."
        ))
      } else {
        c(i = paste(
          "{.code upgrade = TRUE} (the default) resolves them by installing",
          "the required versions; {.code upgrade = FALSE} leaves the study's",
          "library as it is."
        ))
      }
    ))
  }
  bad <- child_value(result$output, "HVTIR_UNREADABLE")
  if (length(bad)) {
    pkgs <- strsplit(bad[1L], ",", fixed = TRUE)[[1L]]
    cli::cli_abort(c(
      "These packages in the study's library cannot be read by you:",
      stats::setNames(pkgs, rep("x", length(pkgs))),
      i = paste(
        "Their owner (or an administrator) must fix the permissions, for",
        "example {.code chmod -R g+rX <library>/<pkg>}, or remove them.",
        "{.fn setup} will not delete another user's files."
      )
    ))
  }
  if (result$status != 0L) {
    auth <- grepl("authentication credentials", result$output, fixed = TRUE)
    cli::cli_abort(c(
      "Installing the study's packages failed.",
      if (auth) c("A GitHub token is needed.", github_credentials_hint()),
      output_bullets(result$output),
      i = "Full output: {.file {save_setup_log(raw)}}"
    ))
  }
  invisible(NULL)
}

#' The single value of a `KEY=` line in a child's output
#' @noRd
child_value <- function(output, key) {
  lines <- grep(paste0("^", key, "="), strsplit(output, "\n")[[1L]],
                value = TRUE)
  sub(paste0("^", key, "="), "", lines)
}

#' The study root, found without installing or loading anything
#'
#' Used by the guard in [setup()], which must run before anything can install.
#' Base R only: loading `hvtiRutilities` here would leave its namespace loaded
#' and block the upgrade that follows. The active renv project when there is
#' one, else the nearest directory at or above the working directory that holds
#' `_study.yml`, else the working directory.
#' @return A path.
#' @noRd
cheap_study_root <- function() {
  project <- Sys.getenv("RENV_PROJECT", "")
  if (nzchar(project)) return(project)
  dir <- normalizePath(getwd(), winslash = "/")
  repeat {
    if (file.exists(file.path(dir, "_study.yml"))) return(dir)
    parent <- dirname(dir)
    if (identical(parent, dir)) return(getwd())
    dir <- parent
  }
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
  project <- Sys.getenv("RENV_PROJECT", "")
  # A restart in RStudio reopens the last project, so the session can sit in
  # a different study's renv; nothing loaded then belongs to the target.
  other <- active && nzchar(project) && !path_within(project, target)
  reason <- if (other) {
    paste(
      "This session is inside another project, {.file {project}}, so",
      "{.fn setup} would install into that project's library."
    )
  } else {
    paste(
      "{.fn setup} replaces packages this session has loaded, and would",
      "install into the study's library through this session."
    )
  }
  cli::cli_abort(c(
    reason,
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
#' copies before renv when adopting; declares `hvtiR`, every member, the
#' packages they need and the team's standard analysis packages in the
#' study's `DESCRIPTION`; installs them into the
#' study's library with pak and renv; snapshots; checks that every
#' package's dependencies resolve there; and restarts into the project.
#'
#' renv runs in explicit mode: the lockfile records what the study's
#' `DESCRIPTION` declares, not whatever the code happens to mention. A study
#' that already has a `renv.lock` keeps its locked versions, and on first
#' conversion every package that lockfile recorded is declared, so none drop
#' out. They are restored, and only packages the lockfile lacks are installed.
#' By default (`upgrade = TRUE`) it moves locked versions the declared family
#' needs and says which; `upgrade = FALSE` keeps a study in revision on its
#' locked versions.
#'
#' The standard analysis packages are `tidyverse`, `haven`, `gtsummary`,
#' `flextable`, `survival`, `survminer`, `randomForestSRC`, `varPro` and
#' `pacman`, all from the configured repositories. A study needs no separate
#' step to have them; anything beyond them is added with
#' `hvtiRutilities::study_need()`.
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
#' No personal GitHub token is needed. The family is installed with pak, which
#' carries a shared token, into the study's library, and renv keeps the
#' environment: it restores the lockfile first, then snapshots, and installs
#' from the configured repositories the build-time (`LinkingTo`) dependencies
#' pak skips. Restoring a package the lockfile pins on GitHub goes through
#' renv, which has no shared token; a `GITHUB_PAT` (or a token in the git
#' credential store) covers that, and `setup()` warns when there is none.
#'
#' Safe to rerun: each step checks before it acts.
#'
#' @param study The Study Tracker title.
#' @param study_tracker_id The Study Tracker ID, an integer.
#' @param root The study root. By default the study enclosing the working
#'   directory, or the working directory.
#' @param adopt Set up an existing study, adding only what is missing.
#'   Adopting cleans up template copies unless `cleanup = FALSE` is passed.
#' @param upgrade Whether the install may move versions the lockfile pins.
#'   The default, `TRUE`, moves them when the declared family needs newer
#'   ones: the guard lists each move (package, old and new version,
#'   `RemoteSha` changes) and the snapshot records the new versions. Pass
#'   `FALSE` for a study in revision, whose versions must not move: a locked
#'   package the install would move then stops the run and `renv.lock` is
#'   left unchanged.
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
setup <- function(study, study_tracker_id, root = NULL, adopt = FALSE,
                  upgrade = TRUE, ...) {
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
    cli::cli_warn(c(
      paste(
        "No personal GitHub token found. Installs use {.pkg pak}'s shared",
        "token; restoring a GitHub-locked package may need your own."
      ),
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
  study_repos <- NULL
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
    study_repos <- parse_repos(child_value(read$output, "HVTIR_REPOS"))
  }
  # A study lives on one server, so its lockfile should name the binary URL its
  # teammates' restores can use. A source URL makes every restore compile, and
  # some packages (arrow needs a C++20 compiler) cannot compile with the
  # server's default one. The session's repository is the same Package Manager
  # served as binaries.
  repos <- binary_repos(study_repos, getOption("repos"))
  record <- !identical(unname(repos), unname(study_repos))
  if (record) {
    cli::cli_alert_info(paste(
      "Using {.url {repos[repos != study_repos][[1L]]}} (the binary form of",
      "the study's {.url {study_repos[repos != study_repos][[1L]]}}) for",
      "installs, and recording it in renv.lock."
    ))
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
  first <- run_in_study(restore_expr(root, repos), root)
  first_raw <- first$output
  first$output <- iconv(first_raw, "UTF-8", "UTF-8", sub = "?")
  abort_stage(first, first_raw)
  project_lib <- child_value(first$output, "HVTIR_LIB")
  lockver <- child_value(first$output, "HVTIR_LOCKVER")
  if (length(project_lib) != 1L || !dir.exists(project_lib) ||
        length(lockver) != 1L) {
    cli::cli_abort(c(
      "The restore did not report the study's library and locked versions.",
      output_bullets(first$output),
      i = "Full output: {.file {save_setup_log(first_raw)}}"
    ))
  }
  unlinked <- child_value(first$output, "HVTIR_UNLINKED")
  entries <- strsplit(lockver, ",", fixed = TRUE)[[1L]]
  entries <- entries[nzchar(entries)]
  rest <- sub("^[^:]*:", "", entries)
  before <- sub(":.*$", "", rest)
  names(before) <- sub(":.*$", "", entries)
  sha <- sub("^[^:]*:?", "", rest)
  names(sha) <- names(before)
  libpkgs <- child_value(first$output, "HVTIR_LIBPKGS")
  if (length(libpkgs) == 1L) {
    libpkgs <- strsplit(libpkgs, ",", fixed = TRUE)[[1L]]
  } else {
    libpkgs <- NULL
  }
  add <- install_specs(setdiff(packages, names(before)))
  if (length(add)) {
    tryCatch(
      pak_install_lib(add, project_lib, repos),
      error = function(e) {
        msg <- conditionMessage(e)
        auth <- grepl("authentication credentials", msg, fixed = TRUE)
        cli::cli_abort(c(
          "Installing the study's packages failed.",
          if (auth) c("A GitHub token is needed.", github_credentials_hint()),
          output_bullets(msg)
        ))
      }
    )
  }

  result <- run_in_study(
    finish_expr(root, before, sha, libpkgs, repos, record, upgrade), root
  )
  raw_output <- result$output
  result$output <- iconv(raw_output, "UTF-8", "UTF-8", sub = "?")
  abort_stage(result, raw_output, upgrade)
  report_moves(result$output)
  if (length(unlinked)) {
    gone <- strsplit(unlinked[1L], ",", fixed = TRUE)[[1L]]
    cli::cli_alert_info(paste(
      "Removed {length(gone)} unreadable cache link{?s} from the study's",
      "library and reinstalled: {.pkg {gone}}."
    ))
  }
  lib <- child_value(result$output, "HVTIR_LIB")
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
