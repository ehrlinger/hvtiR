#' Read the published-artifact catalog
#'
#' Presentation metadata for everything the group publishes: the [members()]
#' of the family, plus the SAS/C code and the Quarto book, which are not R
#' packages and so cannot come from the registry.
#'
#' `status`, `cran` and `role` are stored as fields rather than folded into
#' `blurb`, so that each consumer can render them in its own house style. The
#' blurb itself is ASCII; `" -- "` marks where a renderer should substitute its
#' own dash.
#'
#' The three version columns are refreshed on a schedule by
#' `tools/refresh_catalog_versions.py`, never by hand: `cran_version` from
#' crandb, `dev_version` from each repo's `DESCRIPTION` on `main`. They are
#' two different facts with two different oracles and must not be conflated
#' -- a package can sit on CRAN while `main` runs a development line ahead of
#' it. `dev_ahead` records whether such a gap is intended, and is the one
#' version field maintained by hand, because no oracle returns intent.
#'
#' @param path Path to the catalog CSV. Defaults to the copy installed with
#'   the package.
#' @return A data frame with one row per published artifact and eleven
#'   character columns: `package`, `repo`, `family`, `blurb`, `cran`,
#'   `status`, `role`, `homepage`, `cran_version`, `dev_version` and
#'   `dev_ahead`. Absent values are the empty string, never `NA`.
#' @noRd
read_catalog <- function(path = system.file("extdata", "catalog.csv",
                                            package = "hvtiR")) {
  utils::read.csv(
    path,
    colClasses = "character",
    na.strings = character(0),
    check.names = FALSE
  )
}
