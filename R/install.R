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

#' Point dated snapshots at the latest view of the same repository
#'
#' Posit Package Manager serves its current index at `latest` in place of the
#' date or transaction id, so the swap keeps the server, the distribution and
#' the binary path the site chose. Other repositories are returned unchanged.
#'
#' @param repos A named character vector, as `getOption("repos")` returns.
#' @return `repos`, with every element `snapshot_repos()` flags rewritten.
#' @noRd
latest_repos <- function(repos) {
  # By URL, not by name: a repository vector need not be named.
  dated <- repos %in% snapshot_repos(repos)
  repos[dated] <- sub(
    "/([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{5,})/?$", "/latest", repos[dated]
  )
  repos
}

#' The one line that sets `repos`
#'
#' Spells out every repository rather than only the changed one, so pasting
#' it does not drop a site's other repositories. [base::deparse1()] quotes a
#' name that is not syntactic and omits one that is absent; [base::c()] drops
#' attributes other than names, such as the `RStudio` flag RStudio sets.
#'
#' @param repos A character vector, named or not.
#' @return A length-1 character string of R code.
#' @noRd
repos_override <- function(repos) {
  paste0(
    "options(repos = ",
    deparse1(c(repos), collapse = "", width.cutoff = 500L),
    ")"
  )
}

#' Explain a failed install, when the cause is an unmet dependency floor
#'
#' pak reports a floor the repositories cannot meet as "Could not solve
#' package dependencies", which names the package but not the remedy. When
#' the solve failed and a member's floor is unmet, this aborts with the floor
#' and, when a repository is a dated snapshot, the `repos` line that works.
#' Any other error is rethrown untouched, as is a failed solve this does not
#' explain.
#'
#' Only the members sent to pak are examined: a floor some other member
#' declares cannot be why this solve failed.
#'
#' @param err The condition `pak_install()` signalled.
#' @param packages Character vector of the member package names sent to pak.
#' @return Does not return.
#' @noRd
explain_install_failure <- function(err, packages) {
  if (!grepl("Could not solve", conditionMessage(err), fixed = TRUE)) {
    stop(err)
  }

  repos <- getOption("repos")
  unmet <- member_unmet_floors(repos, packages)
  if (inherits(unmet, "condition") || is.null(unmet) || nrow(unmet) == 0L) {
    stop(err)
  }

  lines <- unmet_floor_lines(unmet)
  names(lines) <- rep("x", length(lines))
  bullets <- c(
    "The package repositories cannot meet a member's dependency floor.",
    lines
  )

  if (length(snapshot_repos(repos)) > 0L) {
    bullets <- c(
      bullets,
      i = "A repository is a dated snapshot. For this session, run:",
      " " = "{.code {repos_override(latest_repos(repos))}}",
      i = "then {.code hvtiR::install()} again.",
      i = "Ask the server administrator to move the snapshot forward."
    )
  } else {
    bullets <- c(
      bullets,
      i = "Add a repository that carries these versions, then try again."
    )
  }

  cli::cli_abort(bullets, class = "hvtiR_unmet_floor", parent = err)
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
#' When pak cannot solve because a dependency floor is newer than the
#' repositories offer, `explain_install_failure()` names the floor and the
#' `repos` override in place of pak's raw error.
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
  tryCatch(
    pak_install(specs),
    error = function(err) explain_install_failure(err, packages)
  )

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
#' @param remote Was the remote consulted?
#' @return A list with `installed`, `latest`, and a `state` as returned by
#'   `classify_status()`.
#' @noRd
self_check <- function(installed = installed_version("hvtiR"),
                       latest = if (remote) {
                         remote_version(SELF_REPO)
                       } else {
                         NA_character_
                       },
                       remote = TRUE) {
  list(
    installed = as.character(installed),
    latest = as.character(latest),
    state = classify_status(installed, latest, remote = remote)
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
#' `hvtiR` itself is checked by [hvtiR::status()] and reported here, but never
#' installed. `update()` reuses that check; calling it means the installer's
#' namespace is already loaded, which the loaded-namespace guard refuses. When
#' the installer is behind, the report names `pak::pak("ehrlinger/hvtiR")` as
#' the remedy.
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

  self <- attr(st, "self", exact = TRUE)
  if (is.null(self)) self <- self_check()
  report_self(self)
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

  blocked <- check_loaded(targets)
  if (length(blocked) > 0L && !force) {
    cli::cli_warn(c(
      "Cannot update {.pkg {blocked}}: already loaded in this session.",
      i = paste0(
        "No members were installed. Restart R, then run ",
        "{.run hvtiR::update()} before anything attaches them."
      )
    ))
    return(invisible(character(0)))
  }

  install_members(targets, force = force)
}
