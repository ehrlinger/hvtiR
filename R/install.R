#' Which install targets are already loaded
#'
#' Pure: `loaded` is a parameter rather than a call to
#' [base::loadedNamespaces()] inside the body, so the guard can be tested
#' without loading anything.
#'
#' @param targets Character vector of package names about to be installed.
#' @param loaded Character vector of loaded namespace names.
#' @return The subset of `targets` present in `loaded`, possibly empty.
#' @noRd
check_loaded <- function(targets, loaded = loadedNamespaces()) {
  intersect(targets, loaded)
}

#' Map member package names to their GitHub specs
#'
#' @param registry The registry, as returned by [hvtiR::members()].
#' @param packages Character vector of member package names.
#' @return A character vector of `"owner/repo"` strings, in the order of
#'   `packages`.
#' @noRd
build_specs <- function(registry, packages) {
  index <- match(packages, registry$package)

  if (anyNA(index)) {
    # Used in the glue string below; lintr cannot parse cli's {}
    # interpolation and so reports it as assigned-but-unused.
    # nolint next: object_usage_linter.
    unknown <- packages[is.na(index)]
    cli::cli_abort("{.pkg {unknown}} {?is/are} not an hvtiR member.")
  }

  registry$repo[index]
}

#' Install specs with pak
#'
#' The seam that performs the actual installation, isolated so that tests can
#' replace it and never install anything.
#'
#' @param specs Character vector of `"owner/repo"` strings.
#' @return The value returned by [pak::pak()], invisibly.
#' @noRd
pak_install <- function(specs) {
  if (!requireNamespace("pak", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg pak} package is required to install hvtiR members.",
      i = 'Install it with {.code install.packages("pak")}, then try again.'
    ))
  }

  invisible(pak::pak(specs, ask = FALSE))
}

#' Close a target set over in-family dependencies
#'
#' @param packages Character vector of member package names.
#' @param deps Dependency edges, as returned by `member_deps()`.
#' @param registry The registry, used to order the result.
#' @return `packages` plus every member reachable from it through `deps`,
#'   ordered as the registry orders them.
#' @noRd
expand_targets <- function(packages,
                           deps = member_deps(),
                           registry = members()) {
  out <- packages

  repeat {
    extra <- unlist(deps[intersect(out, names(deps))], use.names = FALSE)
    fresh <- setdiff(extra, out)
    if (length(fresh) == 0L) break
    out <- c(out, fresh)
  }

  registry$package[registry$package %in% out]
}

#' Install a set of members
#'
#' Every spec goes to [pak::pak()] in one call. This is a correctness
#' requirement, not an optimisation: `hvtiRlifetables` imports
#' `TemporalHazard (>= 1.2.0)` without a `Remotes:` line, so resolving it on
#' its own sends pak to CRAN and the requirement fails. Passing every spec at
#' once co-resolves `ehrlinger/TemporalHazard` and satisfies the import.
#'
#' @param packages Character vector of member package names.
#' @param force Bypass the loaded-namespace guard.
#' @return The character vector of specs passed to pak, invisibly.
#' @noRd
install_members <- function(packages, force = FALSE) {
  if (length(packages) == 0L) {
    cli::cli_alert_success("All hvtiR members are up to date.")
    return(invisible(character(0)))
  }

  blocked <- check_loaded(packages)

  if (length(blocked) > 0L && !force) {
    cli::cli_abort(c(
      "Cannot install {.pkg {blocked}}: already loaded in this session.",
      i = paste0(
        "{cli::qty(length(blocked))}Restart R and run this before ",
        "anything attaches {?it/them}."
      ),
      i = "Pass {.code force = TRUE} to install anyway (unsafe on Windows)."
    ))
  }

  specs <- build_specs(members(), packages)
  pak_install(specs)

  cli::cli_alert_success("Installed {length(specs)} member{?s}.")
  invisible(specs)
}

# hvtiR is deliberately not a member of its own registry -- an installer that
# resolved itself would be circular -- so its repository is named here rather
# than looked up in members().
# Package constant, spelled like MIN_R_VERSION so that it reads as a constant
# and not as a local at its use site.
# nolint next: object_name_linter.
SELF_REPO <- "ehrlinger/hvtiR"

#' Check hvtiR itself against its own repository
#'
#' Because `hvtiR` is absent from [hvtiR::members()], nothing else in the
#' package looks at it. Without this, `update()` can leave a user current on
#' every member and silently stale on the tool that installed them.
#'
#' Pure given its arguments, following `classify_status()`, so every state is
#' testable without a network call.
#'
#' @param installed Installed `hvtiR` version, or `NA_character_`.
#' @param latest Version on the repository's `main`, or `NA_character_`.
#' @return A list with `installed`, `latest`, and a `state` as returned by
#'   `classify_status()`.
#' @noRd
self_check <- function(installed = installed_version("hvtiR"),
                       latest = remote_version(SELF_REPO)) {
  list(
    installed = as.character(installed),
    latest = as.character(latest),
    state = classify_status(installed, latest, remote = TRUE)
  )
}

#' Report hvtiR's own version
#'
#' `update()` cannot update `hvtiR` in place: calling it means the namespace is
#' already loaded, so the guard in `install_members()` would refuse. Reporting
#' is therefore the whole remedy, and the message names the bootstrap command
#' rather than offering to run it.
#'
#' @param self A list as returned by `self_check()`.
#' @return `NULL`, invisibly. Called for the message.
#' @noRd
report_self <- function(self) {
  if (self$state == "stale") {
    cli::cli_alert_warning(
      "hvtiR {self$installed} is behind {self$latest} on GitHub."
    )
    cli::cli_alert_info(
      "Update the installer with {.code pak::pak(\"ehrlinger/hvtiR\")}."
    )
  } else if (self$state == "ahead") {
    cli::cli_alert_info(
      "hvtiR {self$installed} is ahead of {self$latest} on GitHub."
    )
  } else if (self$state %in% c("unknown", "missing")) {
    cli::cli_alert_info(
      "hvtiR {self$installed} - could not be checked against GitHub."
    )
  } else {
    cli::cli_alert_info("hvtiR {self$installed} is current.")
  }

  invisible(NULL)
}

#' Install every hvtiR member
#'
#' Installs all members from GitHub `main`, whether or not they are already
#' present. This is the fresh-machine command; use [hvtiR::update()] to
#' install only what is missing or out of date.
#'
#' Members are installed from GitHub rather than CRAN because GitHub is where
#' family releases land first. CRAN is a downstream republication for members
#' that are published there.
#'
#' @param force Bypass the loaded-namespace guard. A package whose namespace
#'   is loaded cannot be safely overwritten; on Windows the write fails and
#'   leaves a broken library. Unsafe: restart R instead.
#' @return The character vector of `"owner/repo"` specs passed to pak,
#'   invisibly.
#' @export
#' @examples
#' \dontrun{
#' install()
#' }
install <- function(force = FALSE) {
  install_members(members()$package, force = force)
}

#' Update out-of-date hvtiR members
#'
#' Installs only the members whose status is `"missing"` or `"stale"`. When
#' everything is current, reports that and installs nothing. Members whose
#' version or commit could not be checked against GitHub are reported as
#' unchecked rather than silently treated as current.
#'
#' The target set is expanded over in-family dependencies (see
#' `member_deps()`) before installing, so a stale member's in-family
#' dependency is sent to pak alongside it even when that dependency is
#' already current. Without this, installing e.g. just `hvtiRlifetables`
#' sends pak to CRAN to resolve its `TemporalHazard` import, where the
#' required version may not exist.
#'
#' `hvtiR` itself is reported but never installed. It is not a member of its
#' own registry, so nothing else would mention it, and it cannot be updated
#' from inside a running session anyway: calling `update()` means its namespace
#' is loaded, which the loaded-namespace guard refuses. When the installer is
#' behind, the report names `pak::pak("ehrlinger/hvtiR")` as the remedy.
#'
#' @param force Bypass the loaded-namespace guard. See [hvtiR::install()].
#' @return The character vector of `"owner/repo"` specs passed to pak,
#'   invisibly. Empty if nothing needed updating.
#' @export
#' @examples
#' \dontrun{
#' update()
#' }
update <- function(force = FALSE) {
  st <- status(remote = TRUE)

  report_self(self_check())
  targets <- st$package[st$status %in% c("missing", "stale")]

  unchecked <- sum(st$status == "unknown")

  if (length(targets) == 0L && unchecked > 0L) {
    cli::cli_alert_warning(
      paste0(
        "Nothing to update, but {unchecked} member{?s} could not be ",
        "checked against GitHub."
      )
    )
    return(invisible(character(0)))
  }

  if (unchecked > 0L) {
    cli::cli_alert_warning(
      "{unchecked} member{?s} could not be checked against GitHub."
    )
  }

  targets <- expand_targets(targets)

  install_members(targets, force = force)
}
