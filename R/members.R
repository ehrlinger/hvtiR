#' Members of the hvtiR
#'
#' The registry of R packages that make up the HVTI package family, together
#' with the GitHub repository each one installs from.
#'
#' Every member's package name currently matches its repository name, but the
#' mapping is stored rather than derived. The two diverged until the 2026-08
#' renames -- `hvtiRpropensity` lived in `ehrlinger/hvtiPropensityScores` and
#' `TemporalHazard` in `ehrlinger/temporal_hazard` -- and a derived repo would
#' fail silently the next time a name moves.
#'
#' @return A data frame with one row per member and two character columns:
#'   \describe{
#'     \item{package}{The installed package name.}
#'     \item{repo}{The GitHub repository, as `"owner/repo"`.}
#'   }
#' @export
#' @examples
#' members()
members <- function() {
  data.frame(
    package = c(
      "hvtiRutilities",
      "hvtiRdatabuild",
      "hvtiRtables",
      "hvtiRtemplates",
      "hvtiPlotR",
      "hvtiRlifetables",
      "hvtiRbootstrap",
      "hvtiRpropensity",
      "hvtiBoostmtree",
      "TemporalHazard",
      "ggRandomForests"
    ),
    repo = c(
      "ehrlinger/hvtiRutilities",
      "ehrlinger/hvtiRdatabuild",
      "ehrlinger/hvtiRtables",
      "ehrlinger/hvtiRtemplates",
      "ehrlinger/hvtiPlotR",
      "ehrlinger/hvtiRlifetables",
      "ehrlinger/hvtiRbootstrap",
      "ehrlinger/hvtiRpropensity",
      "ehrlinger/hvtiBoostmtree",
      "ehrlinger/TemporalHazard",
      "ehrlinger/ggRandomForests"
    ),
    stringsAsFactors = FALSE
  )
}

#' Dependencies between hvtiR members
#'
#' Members that import another member. Used to close an update's target set:
#' installing a member without its in-family dependency can send `pak` to CRAN
#' for that dependency, where the required version may not exist.
#'
#' @return A named list. Each name is a member package; each value is a
#'   character vector of member packages it depends on.
#' @noRd
member_deps <- function() {
  list(
    hvtiRdatabuild = "hvtiRutilities",
    hvtiRlifetables = "TemporalHazard",
    hvtiRtemplates = "hvtiRutilities"
  )
}
