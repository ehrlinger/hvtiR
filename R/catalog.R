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
#' @param path Path to the catalog CSV. Defaults to the copy installed with
#'   the package.
#' @return A data frame with one row per published artifact and eight
#'   character columns: `package`, `repo`, `family`, `blurb`, `cran`,
#'   `status`, `role` and `homepage`. Absent values are the empty string,
#'   never `NA`.
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
